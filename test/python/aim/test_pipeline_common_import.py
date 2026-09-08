"""Importing pipeline_common must do nothing to the machine.

It used to pip-install packages, create every queue directory, plant Windows
shortcuts and run a bi-directional SQL alias sync -- all as a side effect of
`import pipeline_common`. That is why no worker was testable. Plan step 0.4.
"""
import os
import socket
import sys


def test_import_creates_no_directories(fake_environment):
    import pipeline_common  # noqa: F401

    assert not fake_environment.exists(), (
        f"importing pipeline_common created {fake_environment}; "
        "directory creation belongs in bootstrap()"
    )


def test_import_opens_no_sockets(fake_environment, monkeypatch):
    def refuse(*args, **kwargs):
        raise AssertionError(
            "importing pipeline_common opened a socket; the SQL alias sync "
            "and package installs belong in bootstrap()"
        )

    monkeypatch.setattr(socket.socket, "connect", refuse)
    monkeypatch.setattr(socket, "create_connection", refuse)

    import pipeline_common  # noqa: F401


def test_import_installs_no_packages(fake_environment, monkeypatch):
    import subprocess

    def refuse(*args, **kwargs):
        raise AssertionError("importing pipeline_common shelled out to pip")

    monkeypatch.setattr(subprocess, "check_call", refuse)
    monkeypatch.setattr(subprocess, "run", refuse)

    import pipeline_common  # noqa: F401


def test_bootstrap_is_what_creates_the_directories(fake_environment, monkeypatch):
    import pipeline_common

    assert not fake_environment.exists()
    # The shortcut planting is Windows-only and the alias sync needs SQL;
    # neither belongs in a local run. What is under test is the directories.
    monkeypatch.setattr(pipeline_common, "setup_shortcuts", lambda: None)
    monkeypatch.setattr(pipeline_common, "get_vendor_aliases", lambda: None)

    pipeline_common.bootstrap()

    assert fake_environment.exists(), "bootstrap() should create the queue tree"
    for directory in pipeline_common.MANAGED_DIRECTORIES:
        assert os.path.isdir(directory), f"bootstrap() did not create {directory}"
