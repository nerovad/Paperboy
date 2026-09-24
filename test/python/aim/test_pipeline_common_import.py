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
    # The alias sync needs SQL, which does not belong in a local run. What is
    # under test is the directories.
    monkeypatch.setattr(pipeline_common, "get_vendor_aliases", lambda: None)

    pipeline_common.bootstrap()

    assert fake_environment.exists(), "bootstrap() should create the queue tree"
    for directory in pipeline_common.MANAGED_DIRECTORIES:
        assert os.path.isdir(directory), f"bootstrap() did not create {directory}"


def test_every_queue_the_pipeline_knows_about_is_created(fake_environment, monkeypatch):
    """Found 2026-09-23: _USER_APPROVAL did not exist on the share at all.

    Rails moves a corrected invoice into it, and nothing had ever created it,
    so the move failed on a share the workers otherwise keep in order. The
    spool-state folder was the same: read by the watcher, managed by nobody.
    A queue the pipeline knows about is a queue it creates.
    """
    import pipeline_common

    monkeypatch.setattr(pipeline_common, "get_vendor_aliases", lambda: None)
    pipeline_common.bootstrap()

    assert os.path.isdir(pipeline_common.USER_APPROVAL_DIR)
    assert os.path.isdir(pipeline_common.SPOOL_STATE_DIR)
    assert pipeline_common.USER_APPROVAL_DIR in pipeline_common.MANAGED_DIRECTORIES
    assert pipeline_common.SPOOL_STATE_DIR in pipeline_common.MANAGED_DIRECTORIES


def test_bootstrap_plants_no_shortcuts(fake_environment, monkeypatch):
    """The review shortcuts are retired, plan step 5.7c(6).

    Every job a MOVE_FOLDERS_HERE_TO_... shortcut did is now a button on the
    Paperboy review page, and a .lnk in a queue folder was being counted as
    an item in it. The workers no longer plant them.
    """
    import pipeline_common

    monkeypatch.setattr(pipeline_common, "get_vendor_aliases", lambda: None)
    pipeline_common.bootstrap()

    assert not hasattr(pipeline_common, "setup_shortcuts")
    planted = [name for _, _, files in os.walk(fake_environment) for name in files if name.endswith(".lnk")]
    assert planted == []
