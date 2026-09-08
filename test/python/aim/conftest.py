"""Shared fixtures for the AIM worker tests.

Three rules this harness enforces, from the plan's Guardrails:

* **Tests never read the real environment.** An autouse fixture strips every
  AIM_* variable before each test, so a developer's real `.env` -- or a
  workstation that has never pulled LockBox -- cannot change a result.
* **No Windows, no Ollama, no SQL.** Nothing here loads a model, opens a
  database connection or plants a `.lnk`. Those stay manual checks on
  GSA-SCAN02.
* **No hardcoded paths.** Every directory comes from `tmp_path`.
"""
import importlib
import json
import os
import sys

import pytest

REPO_ROOT = os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
)
WORKER_DIR = os.path.join(REPO_ROOT, "script", "python", "aim")

# Directory variables pipeline_common reads at import.
QUEUE_VARIABLES = [
    "AIM_BASE_DIR", "AIM_PROCESSED_DIR", "AIM_PENDING_VISION_DIR",
    "AIM_ACTION_NEEDED_DIR", "AIM_LOG_DIR", "AIM_SQL_FAILED_DIR",
    "AIM_SQL_QUEUE_DIR", "AIM_BATCH_SPLIT_DIR", "AIM_READY_TO_SPLIT_DIR",
    "AIM_VENDOR_REVIEW_DIR", "AIM_READY_TO_LEARN_DIR",
    "AIM_LOW_CONFIDENCE_REVIEW_DIR", "AIM_REPROCESS_QUEUE_DIR",
    "AIM_TEMP_DIR", "AIM_ARCHIVE_DIR", "AIM_READY_TO_DELETE_DIR",
    "AIM_DELETED_DIR", "AIM_AI_QUEUE_DIR", "AIM_ERROR_QUEUE_DIR",
    "AIM_SPOOL_STATE_DIR",
]


@pytest.fixture(autouse=True)
def no_real_environment(monkeypatch):
    """Strip every AIM_* variable so the real .env can never leak into a test."""
    for name in [n for n in os.environ if n.startswith("AIM_")]:
        monkeypatch.delenv(name, raising=False)


@pytest.fixture
def fake_environment(tmp_path, monkeypatch):
    """A complete AIM configuration pointing at a temp directory.

    Sets every variable the workers read, but creates **nothing** on disk --
    proving that import creates no directories depends on that. Use
    `queue_tree` when you want the folders to exist.
    """
    root = tmp_path / "AIM"
    program = root / "_PROGRAM"

    for name in QUEUE_VARIABLES:
        monkeypatch.setenv(name, str(root / name[4:].lower()))

    monkeypatch.setenv("AIM_PROGRAM_DIR", str(program))
    monkeypatch.setenv("AIM_SPLIT_FOLDER_NAME", "Split_Invoices")
    monkeypatch.setenv("AIM_LOG_FILE_NAME", "pipeline_log.csv")
    monkeypatch.setenv("AIM_ALIAS_DB_FILE", str(program / "vendor_aliases.json"))
    monkeypatch.setenv("AIM_VENDOR_RULES_FILE", str(program / "vendor_rules.json"))
    monkeypatch.setenv("AIM_FIELD_ALIASES_FILE", str(program / "field_aliases.json"))
    monkeypatch.setenv("AIM_TESSERACT_CMD", str(root / "tesseract"))
    monkeypatch.setenv("AIM_ODBC_DRIVER", "ODBC Driver 17 for SQL Server")
    monkeypatch.setenv("AIM_ODBC_ENCRYPT", "no")
    monkeypatch.setenv("AIM_TEXT_MODEL", "test-text-model")
    monkeypatch.setenv("AIM_VISION_MODEL", "test-vision-model")
    monkeypatch.setenv("AIM_LASERFICHE_INBOX_PATH", r"\AIM\00 INBOX")

    # An empty .env, so load_aim_environment finds a file instead of exiting.
    env_file = tmp_path / "aim.env"
    env_file.write_text("")
    monkeypatch.setenv("AIM_ENV_FILE", str(env_file))

    monkeypatch.syspath_prepend(WORKER_DIR)
    for module in [m for m in list(sys.modules) if m.startswith("pipeline_common")]:
        del sys.modules[module]

    return root


@pytest.fixture
def pipeline(fake_environment):
    """pipeline_common imported against the fake environment."""
    import pipeline_common

    return pipeline_common


@pytest.fixture
def import_worker(fake_environment):
    """Import a worker module freshly against this test's environment.

    Worker modules read their queue directories from pipeline_common at import
    time and are then cached in sys.modules. Without dropping the cached copy,
    the second test in a file keeps the first test's temp tree and quietly
    finds nothing.
    """
    def _import(module_name):
        for module in [m for m in list(sys.modules) if m.startswith(module_name)]:
            del sys.modules[module]
        return importlib.import_module(module_name)

    return _import


@pytest.fixture
def queue_tree(fake_environment, pipeline):
    """The fake environment with every queue directory actually created.

    Returns a helper for dropping an invoice folder into a queue, which is
    what the routing tests in later steps need.
    """
    for directory in pipeline.MANAGED_DIRECTORIES:
        os.makedirs(directory, exist_ok=True)
    os.makedirs(os.environ["AIM_PROGRAM_DIR"], exist_ok=True)

    class Tree:
        root = fake_environment

        @staticmethod
        def queue(variable):
            return os.environ[variable]

        @staticmethod
        def add_invoice(variable, folder_name, payload=None, pdf=True):
            """Create an invoice folder in a queue, as the watcher would."""
            folder = os.path.join(os.environ[variable], folder_name)
            os.makedirs(folder, exist_ok=True)
            if payload is not None:
                with open(os.path.join(folder, f"{folder_name}.json"), "w",
                          encoding="utf-8") as handle:
                    json.dump(payload, handle)
            if pdf:
                with open(os.path.join(folder, f"{folder_name}.pdf"), "wb") as handle:
                    handle.write(b"%PDF-1.4 test\n")
            return folder

    return Tree()
