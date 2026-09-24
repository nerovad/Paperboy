"""Fixtures for the AIM v2 worker tests.

The same harness rules as test/python/aim: every AIM_* variable is stripped
so the real .env cannot leak in, every database connection is refused, and
every path comes from tmp_path. `FakeDb` stands in for `store.Db` with the
same methods, in memory, so the worker, intake, splitting and export are
driven for real against it.
"""
import importlib
import os
import sys
from datetime import datetime, timedelta

import fitz
import pytest

REPO_ROOT = os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
)
V2_DIR = os.path.join(REPO_ROOT, "script", "python", "aim", "v2")
V2_MODULES = ("settings", "invoice_models", "cleaning", "vendors", "extraction",
              "store", "intake", "splitting", "exporting", "worker")


@pytest.fixture(autouse=True)
def no_real_environment(monkeypatch):
    for name in [n for n in os.environ if n.startswith("AIM_")]:
        monkeypatch.delenv(name, raising=False)


@pytest.fixture(autouse=True)
def no_database(monkeypatch):
    import pyodbc

    def refuse(*args, **kwargs):
        raise pyodbc.OperationalError("tests never open a database connection")

    monkeypatch.setattr(pyodbc, "connect", refuse)


@pytest.fixture
def v2_env(tmp_path, monkeypatch):
    """Every variable the v2 worker reads, pointing into tmp_path."""
    root = tmp_path / "AIM"
    folders = {
        "AIM_BASE_DIR": root / "Invoices",
        "AIM_STORE_DIR": root / "_BACK_END" / "_STORE",
        "AIM_PROCESSED_DIR": root / "Invoices" / "_AI_Processed",
        "AIM_ARCHIVE_DIR": root / "Invoices" / "_Archive",
        "AIM_DELETED_DIR": root / "Invoices" / "_DELETED",
        "AIM_REJECTED_DIR": root / "_BACK_END" / "_REJECTED",
        "AIM_LOG_DIR": root / "_BACK_END" / "_Logs",
    }
    for name, path in folders.items():
        monkeypatch.setenv(name, str(path))
        path.mkdir(parents=True, exist_ok=True)
    monkeypatch.setenv("AIM_SHARED_FOLDER_NAME", "SHARED")
    monkeypatch.setenv("AIM_TESSERACT_CMD", str(root / "tesseract"))
    monkeypatch.setenv("AIM_TEXT_MODEL", "test-text-model")
    monkeypatch.setenv("AIM_VISION_MODEL", "test-vision-model")
    monkeypatch.setenv("AIM_LASERFICHE_INBOX_PATH", r"\AIM\00 INBOX")
    monkeypatch.setenv("AIM_FIELD_ALIASES_FILE", "field_aliases.json")
    monkeypatch.setenv("AIM_ODBC_DRIVER", "ODBC Driver 17 for SQL Server")
    monkeypatch.setenv("AIM_ODBC_ENCRYPT", "no")
    monkeypatch.setenv("AIM_SQL_STATE_SERVER", "test-sql-server")
    monkeypatch.setenv("AIM_SQL_STATE_DATABASE", "Paperboy_Test")
    monkeypatch.setenv("AIM_SQL_STATE_USER", "test-user")
    monkeypatch.setenv("AIM_SQL_STATE_PASSWORD", "test-password")
    monkeypatch.setenv("AIM_SQL_STATE_TABLE", "aim.invoices")
    monkeypatch.setenv("AIM_SQL_STATE_EVENTS_TABLE", "aim.invoice_events")
    monkeypatch.setenv("AIM_SQL_BILLING_SERVER", "test-billing-server")
    monkeypatch.setenv("AIM_SQL_BILLING_DATABASE", "GSA_Scan_Test")
    monkeypatch.setenv("AIM_SQL_BILLING_USER", "test-billing-user")
    monkeypatch.setenv("AIM_SQL_BILLING_PASSWORD", "test-billing-password")
    monkeypatch.setenv("AIM_SQL_BILLING_TABLE", "Aim_Invoices")
    monkeypatch.setenv("AIM_SQL_BILLING_MAPPING_FILE", "Aim_Invoices_MAPPING.json")

    env_file = tmp_path / "aim.env"
    env_file.write_text("")
    monkeypatch.setenv("AIM_ENV_FILE", str(env_file))

    monkeypatch.syspath_prepend(V2_DIR)
    for module in [m for m in list(sys.modules) if m in V2_MODULES]:
        del sys.modules[module]
    return root


@pytest.fixture
def v2(v2_env):
    """Import a v2 module freshly against this test's environment."""
    def _import(name):
        return importlib.import_module(name)
    return _import


@pytest.fixture
def settings(v2):
    return v2("settings").Settings.from_env()


def make_pdf(path, pages=1, text="page"):
    doc = fitz.open()
    for number in range(1, pages + 1):
        page = doc.new_page()
        page.insert_text((72, 72), f"{text} {number}")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    doc.save(path)
    doc.close()
    return path


@pytest.fixture
def pdf_maker():
    return make_pdf


class FakeDb:
    """store.Db, in memory. Same methods, same meaning."""

    def __init__(self, limited, columns=()):
        self._limited = limited
        self._columns = tuple(columns)
        self.rows = {}
        self.events = []
        self.aliases = {}
        self.rules = {}
        self.alias_writes = []
        self._next_id = 1
        self._clock = 0

    def _now(self):
        return datetime.now()

    # reading
    def get(self, invoice_id):
        row = self.rows.get(invoice_id)
        return dict(row) if row else None

    def by_batch(self, batch_id):
        for row in self.rows.values():
            if row["batch_id"] == batch_id:
                return dict(row)
        return None

    def find_by_hash(self, content_hash):
        return [dict(r) for r in self.rows.values() if r.get("content_hash") == content_hash]

    def load_aliases(self):
        return dict(self.aliases)

    def load_rules(self):
        return dict(self.rules)

    # writing
    def upsert_alias(self, extracted_name, normalized_name, learned_by="aim_worker", note=None):
        self.aliases[extracted_name] = normalized_name
        self.alias_writes.append((extracted_name, normalized_name, learned_by, note))

    def insert_invoice(self, batch_id, state, command, fields, note=None, actor="aim_worker"):
        self._clock += 1
        row = {
            "id": self._next_id, "batch_id": batch_id, "state": state, "command": command,
            "lease_owner": None, "lease_until": None, "created_at": self._clock,
            "attempt": 0, "split_check": True, "review_reason": None, "review_note": None,
            "manifest": None, "extracted": None, "exported_at": None, "parent_id": None,
        }
        # A real row has every column; an unset one reads as NULL.
        for column in self._columns:
            row.setdefault(column, None)
        row.update(self._limited(fields))
        self.rows[row["id"]] = row
        self._next_id += 1
        self.events.append({"invoice_id": row["id"], "action": "transition", "from_state": None,
                            "to_state": state, "actor": actor, "note": note})
        return row["id"]

    def claim_next(self, worker, lease_seconds):
        now = self._now()
        candidates = [r for r in self.rows.values()
                      if r.get("command") and (r["lease_until"] is None or r["lease_until"] < now)]
        if not candidates:
            return None
        row = min(candidates, key=lambda r: (r["created_at"], r["id"]))
        row["lease_owner"] = worker
        row["lease_until"] = now + timedelta(seconds=lease_seconds)
        return dict(row)

    def renew_lease(self, invoice_id, lease_seconds):
        self.rows[invoice_id]["lease_until"] = self._now() + timedelta(seconds=lease_seconds)

    def transition(self, invoice_id, from_state, to_state, note=None, fields=None,
                   command="keep", stamp=(), actor="aim_worker"):
        row = self.rows[invoice_id]
        row.update(self._limited(fields))
        row["state"] = to_state
        if command != "keep":
            row["command"] = command
            if command is None:
                row["lease_owner"] = None
                row["lease_until"] = None
        for column in stamp:
            row[column] = self._now()
        if from_state != to_state:
            self.events.append({"invoice_id": invoice_id, "action": "transition", "from_state": from_state,
                                "to_state": to_state, "actor": actor, "note": note})


@pytest.fixture
def fake_db(v2):
    store = v2("store")
    return FakeDb(store.limited, columns=store.FIELD_LIMITS)
