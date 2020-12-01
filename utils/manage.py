# utils/manage.py

import click
import sys

from github_helper.releases import Release_Handler


@click.group()
def cli():
    pass


@cli.command()
@click.option('-sha', '--commit', required=True, type=str)
def create_tag(commit):
    """
        Manages Github repo tags
    """
    try:
        manager = Release_Handler()
        resp = manager.task_handler(commit)
        message = resp['message']
        if resp['exit_code'] != 0:
            message = resp['error']
            click.echo(message=message)
            return sys.exit(resp['exit_code'])
        click.echo(message=message)
        return sys.exit(0)
    except Exception as err:
        message = err
        click.echo(message=message)
    return sys.exit(12)


@cli.command()
def get_version():
    """
        Get git tag
    """
    manager = Release_Handler()
    try:
        message = manager.get_latest_tag()
        click.echo(message=message)
        return sys.exit(0)
    except Exception as err:
        message = err
        click.echo(message=message)
        return sys.exit(12)


@cli.command()
def generate_build_version():
    """
        Get a build version number
    """
    manager = Release_Handler()
    try:
        message = manager.get_build_version()
        click.echo(message=message)
        return sys.exit(0)
    except Exception as err:
        message = err
        click.echo(message=message)
    return sys.exit(12)


if __name__ == '__main__':
    cli()
