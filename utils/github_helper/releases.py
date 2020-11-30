# utils/github_helper/tag_handler.py

import json
from github_helper.config import GitHub_Config
from github_helper.handlers import request_handler, generate_version


class Release_Handler(GitHub_Config):
    """
    GitHub tag handler
    """

    def __init__(self):
        GitHub_Config.__init__(self)

    def get_commit_ids(self):
        request_data = {
            "method": "GET",
            "headers": self.req_headers,
            "url": f"{self.repo_url}/commits"
        }
        response = request_handler(request_data)
        commit_ids = [id["sha"] for id in response.json()]
        return commit_ids

    def get_tag(self, tag_name: str):
        """
        Retrieves information about a tag

        Parameters:
            tag_name (str): branch name

        Returns:
            dict: Tag information
        """
        try:
            request_data = {
                "method": "GET",
                "headers": self.req_headers,
                "url": f"{self.repo_url}/git/ref/tags/{tag_name}"
            }
            response = request_handler(request_data)

            if response.status_code == 200:
                return response.json()

            return None

        except Exception as err:
            print("Error occurred getting tag: {}".format(err))
            return None
        else:
            return None

    def get_all_references(self):
        """
        Get all tag references

        Parameters:
            tag_name (str): tag name

        Returns:
            dict: Tag delete result
        """
        try:
            request_data = {
                "method": "GET",
                "headers": self.req_headers,
                "url": f"{self.repo_url}/git/matching-refs/"
            }
            response = request_handler(request_data)
            return response.json()

        except Exception as err:
            print("Error occurred getting tag: {}".format(err))
            return None
        else:
            return None

    def get_latest_tag(self):
        try:
            tags = self.get_all_references()
            tags.sort
            tag = tags[-1]
            tag = tag["ref"]
            tag = tag.replace("refs/tags/", "")
            return tag
        except Exception as err:
            print("Error occurred getting tag: {}".format(err))
            return None

        return None

    def create_tag_reference(self, payload: dict):
        """
        Create tag reference

        Parameters:
            payload (dict):
                tag: tag name
                message: tag message
                object: commit id sha
                type: type of object, nomrally commit

        Returns:
            dict: Tag delete result
        """
        try:
            data = {
                "ref": f'refs/tags/{payload["tag"]}',
                "sha": payload["object"]
            }
            print(data)
            request_data = {
                "method": "POST",
                "headers": self.req_headers,
                "url": f"{self.repo_url}/git/refs",
                "data": data
            }
            response = request_handler(request_data)

            return response

        except Exception as err:
            print("Error occurred creating tag object: {}".format(err))
            return None
        else:
            return None

    def create_tag_object(self, payload: dict):
        """
            Create tag object

            Parameters:
                payload (dict):
                    tag: tag name
                    message: tag message
                    object: commit id sha
                    type: type of object, nomrally commit

            Returns:
                dict: Tag delete result
            """
        try:
            request_data = {
                "method": "POST",
                "headers": self.req_headers,
                "url": f"{self.repo_url}/git/tags",
                "data": payload
            }
            response = request_handler(request_data)

            return response

        except Exception as err:
            print("Error occurred creating tag object: {}".format(err))
            return None
        else:
            return None

    def create_tag(self, branch_name: str, commit_id: str):
        """
        Create a release

        Parameters:
            branch_name (str): Specifies the git branch tag is created from.
            commit_id (str): git commit id


        Returns:
            dict: tag details
        """
        create_new_tag = False
        try:
            _tag = self.get_latest_tag()
            new_tag = generate_version(_tag)
            resp_obj = {
                "message": f"Error occurred creating release version {new_tag} no changes made",
                "exit_code": 1
            }
            current_tag = self.get_tag(_tag)

            if current_tag is not None:
                if current_tag['object']["sha"] != commit_id:
                    _ids = self.get_commit_ids()
                    if commit_id in _ids:
                        create_new_tag = True

            if create_new_tag == False:
                resp_obj['message'] = f"Tag {_tag} using commit id {commit_id}, skipping creating new tag"
                resp_obj['exit_code'] = 0
                resp_obj['data'] = current_tag
                return resp_obj

            req_body = {
                "tag": new_tag,
                "message": f"release v{new_tag}",
                "object": commit_id,
                "type": "commit"
            }
            response = self.create_tag_object(req_body)
            if response.status_code == 201:
                print("Creating reference")
                response = self.create_tag_reference(req_body)

                if response.json() is not None and response.status_code == 201:
                    resp_obj['message'] = f"Release {new_tag} created using branch {branch_name}"
                    resp_obj['exit_code'] = 0
                    resp_obj['data'] = response.json()
                    return resp_obj

            return response.json()
        except Exception as err:
            resp_obj = {
                "exit_code": 1
            }
            print("Error occurred creating tag: {}".format(err))
            resp_obj['message'] = "An error occurred creating tag"
            resp_obj['error'] = err
            return resp_obj

        return None

    def task_handler(self, commit_id: str):
        resp_obj = {
            "message": "no task completed",
            "exit_code": 1
        }
        result = self.create_tag(self.branch_name, commit_id)
        if result is not None:
            resp_obj = result
            return resp_obj

        resp_obj['error'] = result
        return resp_obj
