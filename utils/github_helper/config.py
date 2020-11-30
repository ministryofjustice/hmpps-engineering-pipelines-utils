# utils/github_helper/config.py

import json
import sys
import os


def load_config():
    current_dir = (os.getcwd())
    config_file = os.environ.get("REPO_CONFIG_FILE", "config.json")
    config_file = f"{current_dir}/{config_file}"

    try:
        with open(config_file) as json_file:
            data = json.load(json_file)
            return data
    except FileNotFoundError:
        print(f"Config file not found {config_file}, aborting...")
        sys.exit(2)
        return None


class GitHub_Config():
    def __init__(self):
        repo_config = load_config()
        self.github_org = repo_config["github"]["org"]
        self.github_api_url = "https://api.github.com"
        self.github_user = os.environ.get("HMPPS_GITHUB_USER")
        self.github_token = os.environ.get("HMPPS_GITHUB_TOKEN")
        self.github_repo = repo_config["github"]["repository"]
        self.branch_name = repo_config["branch"]
        self.req_headers = {
            'Authorization': f'token {self.github_token}'
        }
        self.release_pipeline = os.environ.get("RELEASE_PIPELINE")
        self.repo_url = f"{self.github_api_url}/repos/{self.github_org}/{self.github_repo}"
