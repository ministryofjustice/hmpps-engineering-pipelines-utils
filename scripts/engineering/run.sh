#!/bin/sh

set -e

#Usage
# Scripts takes 3 arguments: environment_name and action
# environment_name: target environment example dev prod
# ACTION_TYPE: task to complete example plan apply test clean
# AWS_TOKEN: token to use when running locally eg hmpps-token

TARGET_ACCOUNT=$1
ACTION_TYPE=$2
COMPONENT=${3}

if [ -z "${HMPPS_BUILD_WORK_DIR}" ]
then
    echo "--> Using default workdir"
    ENV_CONFIG_BASE_DIR="${HOME}/data/env_configs"
else
    echo "USING CUSTOM WORKDIR for configs: $HMPPS_BUILD_WORK_DIR"
    ENV_CONFIG_BASE_DIR="${HMPPS_BUILD_WORK_DIR}/env_configs"
fi

# check for config paths
if [ -f "${ENV_CONFIG_BASE_DIR}/${TARGET_ACCOUNT}/${TARGET_ACCOUNT}.properties" ]; then
  ENV_CONFIG_DIR="${ENV_CONFIG_BASE_DIR}/${TARGET_ACCOUNT}"
fi

if [ -f "${ENV_CONFIG_BASE_DIR}/${TARGET_ACCOUNT}.properties" ]; then
    ENV_CONFIG_DIR="${ENV_CONFIG_BASE_DIR}"
fi

echo "configs dir is ${ENV_CONFIG_DIR}"

if [ -z "${TARGET_ACCOUNT}" ]
then
    echo "environment_name argument not supplied, please provide an argument!"
    exit 1
fi

echo "Output -> environment_name set to: ${TARGET_ACCOUNT}"

#check env vars for RUNNING_IN_CONTAINER switch
if [[ ${RUNNING_IN_CONTAINER:-False} == True ]]
then
    mkdir -p /home/tools/data/lambda
    workDirContainer=${3}
    echo "Output -> environment stage"
    source ${ENV_CONFIG_DIR}/${TARGET_ACCOUNT}.properties
    echo "Output ---> set environment stage complete"
    # set runCmd
    ACTION_TYPE="docker-${ACTION_TYPE}"
    export workDir=${workDirContainer}
    cd ${workDir}
    export PLAN_RET_FILE=${HOME}/data/${workDirContainer}_plan_ret
    echo "Output -> Container workDir: ${workDir}"
fi

#Apply overrides if names are too long
if [ -f "${ENV_CONFIG_DIR}/sub-projects/alfresco.properties" ]; then
    echo "Applying ENV overrides"
    source ${ENV_CONFIG_DIR}/sub-projects/alfresco.properties;
fi

if [ ${COMPONENT} == "ami_permissions" ]
then 
  export TERRAGRUNT_IAM_ROLE="arn:aws:iam::895523100917:role/terraform"
  export TG_REMOTE_STATE_BUCKET="tf-eu-west-2-hmpps-eng-dev-remote-state"
  export TG_ENVIRONMENT_IDENTIFIER="tf-eu-west-2-hmpps-eng-dev"
  echo "Using engineering role: ${TERRAGRUNT_IAM_ROLE}"
fi

case ${ACTION_TYPE} in
  docker-ansible)
    echo "Running ansible playbook action"
    ansible-playbook playbook.yml
    ;;
  docker-plan)
    echo "Running docker plan action"
    rm -rf .terraform *.plan
    terragrunt init
    terragrunt plan -detailed-exitcode --out ${COMPONENT}.plan || tf_exitcode="$?" ;\
      if [ "$tf_exitcode" == '1' ]; then exit 1; else exit 0; fi
    ;;
  docker-apply)
    echo "Running docker apply action"
    terragrunt apply ${COMPONENT}.plan || export tf_exit_code="$?"; \
      if [ "$tf_exitcode" -ne 0 ]; then exit $tf_exitcode; else exit 0; fi
    ;;
  docker-destroy)
    echo "Running docker destroy action"
    rm -rf .terraform *.plan
    terragrunt init
    terragrunt destroy -force
    ;;
  docker-test)
    echo "Running docker test action"
    for cmp in ${components_list}
    do
      output_file="${inspec_profile_files_path}/output-${cmp}.json"
      rm -rf ${output_file}
      cd ${workingDir}/${cmp}
      terragrunt output -json > ${output_file}
    done
    temp_role=$(aws sts assume-role --role-arn ${TERRAGRUNT_IAM_ROLE} --role-session-name testing --duration-seconds 900)
    echo "unset AWS_PROFILE
    export AWS_ACCESS_KEY_ID=$(echo ${temp_role} | jq .Credentials.AccessKeyId | xargs)
    export AWS_SECRET_ACCESS_KEY=$(echo ${temp_role} | jq .Credentials.SecretAccessKey | xargs)
    export AWS_SESSION_TOKEN=$(echo ${temp_role} | jq .Credentials.SessionToken | xargs)" > ${inspec_creds_file}
    source ${inspec_creds_file}
    cd ${workingDir}
    inspec exec ${inspec_profile} -t aws://${TG_REGION}
    rm -rf ${inspec_creds_file} ${inspec_profile_files_path}/output*.json
    ;;
  docker-output)
    echo "Running docker output action"
    rm -rf .terraform *.plan
    terragrunt init
    terragrunt output
    ;;
  docker-json)
    echo "Running docker output action"
    rm -rf .terraform *.plan
    terragrunt init
    terragrunt output -json > data.json
    ;;
  *)
    echo "${ACTION_TYPE} is not a valid argument. init - apply - test - output - destroy"
  ;;
esac

set -o pipefail
set -x