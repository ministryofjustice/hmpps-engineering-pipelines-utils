default: build_tfpackage
.PHONY: build_tfpackage

terraform_plan:
	sh run.sh $(ENVIRONMENT_NAME) plan $(component) || (exit $$?)

terraform_apply:
	sh run.sh $(ENVIRONMENT_NAME) apply $(component) || (exit $$?)

cleanup:
	aws s3 rm --only-show-errors --recursive s3://$(BUILDS_CACHE_BUCKET)/$(CODEBUILD_INITIATOR)/$(component)

apply:
	sh run.sh $(ENVIRONMENT_NAME) plan $(component) || (exit $$?)
	sh run.sh $(ENVIRONMENT_NAME) apply $(component) || (exit $$?)

ansible:
	sh run.sh $(ENVIRONMENT_NAME) ansible $(component)

lambda_packages:
	rm -rf functions
	mkdir functions
	aws s3 sync --only-show-errors s3://$(ARTEFACTS_BUCKET)/lambda/eng-lambda-functions-builder/latest/ $(CODEBUILD_SRC_DIR)/functions/ || (exit $$?)

get_configs:
	rm -rf env_configs
	git config --global advice.detachedHead false
	git clone -b $(ENV_CONFIGS_VERSION) $(ENV_CONFIGS_REPO) env_configs || (exit $$?)

get_eng_configs:
	rm -rf env_configs hmpps-engineering-platform-terraform
	git clone git@github.com:ministryofjustice/hmpps-engineering-platform-terraform.git
	mv hmpps-engineering-platform-terraform/env_configs env_configs
	rm -rf hmpps-engineering-platform-terraform

get_package:
	aws s3 cp --only-show-errors s3://$(ARTEFACTS_BUCKET)/$(RELEASE_PKGS_PATH)/$(DEV_PIPELINE_NAME)/$(PACKAGE_VERSION)/$(PACKAGE_NAME) $(PACKAGE_NAME)

build_tfpackage: get_configs lambda_packages
	mkdir /tmp/builds
	rm -rf /tmp/$(PACKAGE_NAME)
	aws s3 sync --only-show-errors $(CODEBUILD_SRC_DIR)/ s3://$(BUILDS_CACHE_BUCKET)/$(CODEBUILD_INITIATOR)/code/ || exit $?
	aws s3 sync --only-show-errors env_configs/ s3://$(BUILDS_CACHE_BUCKET)/$(CODEBUILD_INITIATOR)/code/env_configs/ || exit $?
	aws s3 sync --only-show-errors functions/ s3://$(BUILDS_CACHE_BUCKET)/$(CODEBUILD_INITIATOR)/code/functions/ || exit $?
	aws s3 sync --only-show-errors s3://$(BUILDS_CACHE_BUCKET)/$(CODEBUILD_INITIATOR)/code/ /tmp/builds/ || exit $?
	echo "export PACKAGE_VERSION=$(PACKAGE_VERSION)" > /tmp/builds/output.txt
	echo "export ENV_CONFIGS_VERSION=$(ENV_CONFIGS_VERSION)" >> /tmp/builds/output.txt
	cat /tmp/builds/output.txt
	tar cf /tmp/$(PACKAGE_NAME) /tmp/builds || exit $?
	aws s3 cp --only-show-errors /tmp/$(PACKAGE_NAME) s3://$(BUILDS_CACHE_BUCKET)/$(CODEBUILD_INITIATOR)/$(PACKAGE_NAME) || exit $?
	aws s3 cp --only-show-errors /tmp/$(PACKAGE_NAME) s3://$(ARTEFACTS_BUCKET)/$(RELEASE_PKGS_PATH)/$(CODEBUILD_INITIATOR)/$(LATEST_PATH)/$(PACKAGE_NAME)
	aws s3 cp --only-show-errors /tmp/$(PACKAGE_NAME) s3://$(ARTEFACTS_BUCKET)/$(RELEASE_PKGS_PATH)/$(CODEBUILD_INITIATOR)/$(PACKAGE_VERSION)/$(PACKAGE_NAME)
	aws s3 rm --only-show-errors --recursive s3://$(BUILDS_CACHE_BUCKET)/$(CODEBUILD_INITIATOR)/code
	cp /tmp/$(PACKAGE_NAME) $(CODEBUILD_SRC_DIR)/$(PACKAGE_NAME) 

