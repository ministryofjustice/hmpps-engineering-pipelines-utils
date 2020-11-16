default: build
.PHONY: build

get_configs:
	rm -rf env_configs hmpps-engineering-platform-terraform
	git clone git@github.com:ministryofjustice/hmpps-engineering-platform-terraform.git
	mv hmpps-engineering-platform-terraform/env_configs env_configs
	rm -rf hmpps-engineering-platform-terraform

terraform_plan: 
	sh run.sh $(ENVIRONMENT_NAME) plan $(component)

terraform_apply: terraform_plan
	sh run.sh $(ENVIRONMENT_NAME) apply $(component)

ansible:
	sh run.sh $(ENVIRONMENT_NAME) ansible $(component)

lambda_packages:
	rm -rf $(component)
	mkdir $(component)
	aws s3 sync --only-show-errors s3://$(ARTEFACTS_BUCKET)/lambda/eng-lambda-functions-builder/latest/ $(CODEBUILD_SRC_DIR)/$(component)/
