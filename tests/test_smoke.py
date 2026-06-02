"""Smoke tests for the repository template."""

import app


def test_template_smoke() -> None:
    assert app.__doc__ is not None
