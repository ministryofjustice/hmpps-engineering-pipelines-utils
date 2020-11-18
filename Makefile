default: build
.PHONY: build

terraform_plan:
	sh run.sh $(ENVIRONMENT_NAME) plan $(component)

terraform_apply:
	sh run.sh $(ENVIRONMENT_NAME) apply $(component)

ansible:
	sh run.sh $(ENVIRONMENT_NAME) ansible $(component)

lambda_packages:
	rm -rf $(component)
	mkdir $(component)
	aws s3 sync --only-show-errors s3://$(ARTEFACTS_BUCKET)/lambda/eng-lambda-functions-builder/latest/ $(CODEBUILD_SRC_DIR)/$(component)/

get_configs:
	rm -rf env_configs
	git config --global advice.detachedHead false
	git clone -b $(ENV_CONFIGS_VERSION) $(ENV_CONFIGS_REPO) env_configs

get_eng_configs:
	rm -rf env_configs hmpps-engineering-platform-terraform
	git clone git@github.com:ministryofjustice/hmpps-engineering-platform-terraform.git
	mv hmpps-engineering-platform-terraform/env_configs env_configs
	rm -rf hmpps-engineering-platform-terraform

get_package:
	aws s3 cp --only-show-errors s3://$(ARTEFACTS_BUCKET)/$(RELEASE_PKGS_PATH)/$(PACKAGE_VERSION)/$(PACKAGE_NAME) $(PACKAGE_NAME)
	tar xf $(PACKAGE_NAME) --strip-components=1
	cat output.txt
