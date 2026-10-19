"""Copier context hook: default author_name from git, else the OS user."""

import functools
import getpass
import subprocess

from copier_template_extensions import ContextHook


@functools.cache
def _author_name() -> str:
    try:
        name = subprocess.run(
            ["git", "config", "--get", "user.name"],
            capture_output=True,
            text=True,
            check=False,
        ).stdout.strip()
    except OSError:
        name = ""
    if name:
        return name
    try:
        return getpass.getuser()
    except OSError:
        return ""


class DefaultAuthorName(ContextHook):
    def hook(self, context: dict) -> None:
        context["default_author_name"] = _author_name()
