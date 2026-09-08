"""Shared fixtures for the AIM worker tests.

These tests never read the real environment and never touch the AIM share.
Every path comes from a temp directory, so a developer who has not pulled
LockBox -- or has no access to GSA-SCAN02 -- still gets a green run.
"""
import os
import sys

import pytest

WORKER_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))),
    "script", "python", "aim",
)

# Every AIM_* variable pipeline_common reads at import.
REQUIRED = [
    "AIM_BASE_DIR", "AIM_PROCESSED_DIR", "AIM_PENDING_VISION_DIR",
    "AIM_ACTION_NEEDED_DIR", "AIM_LOG_DIR", "AIM_SQL_FAILED_DIR",
    "AIM_SQL_QUEUE_DIR", "AIM_BATCH_SPLIT_DIR", "AIM_READY_TO_SPLIT_DIR",
    "AIM_VENDOR_REVIEW_DIR", "AIM_READY_TO_LEARN_DIR",
    "AIM_LOW_CONFIDENCE_REVIEW_DIR", "AIM_REPROCESS_QUEUE_DIR",
    "AIM_TEMP_DIR", "AIM_ARCHIVE_DIR", "AIM_READY_TO_DELETE_DIR",
    "AIM_DELETED_DIR", "AIM_AI_QUEUE_DIR", "AIM_ERROR_QUEUE_DIR",
    "AIM_SPLIT_FOLDER_NAME", "AIM_LOG_FILE_NAME", "AIM_ALIAS_DB_FILE",
    "AIM_VENDOR_RULES_FILE", "AIM_FIELD_ALIASES_FILE", "AIM_TESSERACT_CMD",
    "AIM_PROGRAM_DIR",
]


@pytest.fixture
def fake_queue_tree(tmp_path, monkeypatch):
    """A complete AIM environment in a temp directory.

    Returns the root. Nothing is created inside it -- proving that import
    creates no directories is the point of test_import_is_pure.
    """
    root = tmp_path / "AIM"
    for name in REQUIRED:
        if name.endswith("_DIR") or name == "AIM_BASE_DIR":
            monkeypatch.setenv(name, str(root / name.lower()))

    monkeypatch.setenv("AIM_PROGRAM_DIR", str(root / "_PROGRAM"))
    monkeypatch.setenv("AIM_SPLIT_FOLDER_NAME", "Split_Invoices")
    monkeypatch.setenv("AIM_LOG_FILE_NAME", "pipeline_log.csv")
    monkeypatch.setenv("AIM_ALIAS_DB_FILE", str(root / "_PROGRAM" / "vendor_aliases.json"))
    monkeypatch.setenv("AIM_VENDOR_RULES_FILE", str(root / "_PROGRAM" / "vendor_rules.json"))
    monkeypatch.setenv("AIM_FIELD_ALIASES_FILE", str(root / "_PROGRAM" / "field_aliases.json"))
    monkeypatch.setenv("AIM_TESSERACT_CMD", str(root / "tesseract"))

    # An empty .env, so load_aim_environment finds a file and does not exit.
    env_file = tmp_path / "aim.env"
    env_file.write_text("")
    monkeypatch.setenv("AIM_ENV_FILE", str(env_file))

    monkeypatch.syspath_prepend(WORKER_DIR)
    for module in [m for m in list(sys.modules) if m.startswith("pipeline_common")]:
        del sys.modules[module]

    return root
