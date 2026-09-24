"""How work is claimed and recorded: the lease on FakeDb, and the SQL that
store.Db sends, captured on a fake connection."""
from datetime import datetime, timedelta

import pytest


# ---------------------------------------------------------------------------
# The lease, as FakeDb implements it (the contract Db's SQL is written to)
# ---------------------------------------------------------------------------

def test_the_oldest_row_with_a_command_is_claimed_first(fake_db):
    fake_db.insert_invoice("A", "received", "extract", {})
    fake_db.insert_invoice("B", "received", "extract", {})
    fake_db.insert_invoice("C", "needs_review", None, {})

    assert fake_db.claim_next("w1", 60)["batch_id"] == "A"
    assert fake_db.claim_next("w2", 60)["batch_id"] == "B"
    assert fake_db.claim_next("w3", 60) is None, "a row without a command is not work"


def test_a_leased_row_is_not_claimed_by_another_worker(fake_db):
    invoice_id = fake_db.insert_invoice("A", "received", "extract", {})

    fake_db.claim_next("w1", 60)

    assert fake_db.claim_next("w2", 60) is None
    assert fake_db.get(invoice_id)["lease_owner"] == "w1"


def test_an_expired_lease_is_claimed_again(fake_db):
    invoice_id = fake_db.insert_invoice("A", "received", "extract", {})
    fake_db.claim_next("w1", 60)
    fake_db.rows[invoice_id]["lease_until"] = datetime.now() - timedelta(seconds=1)

    assert fake_db.claim_next("w2", 60)["lease_owner"] == "w2"


def test_clearing_the_command_releases_the_lease_and_writes_the_event(fake_db):
    invoice_id = fake_db.insert_invoice("A", "received", "extract", {})
    fake_db.claim_next("w1", 60)

    fake_db.transition(invoice_id, "received", "needs_review", note="why", fields={"review_reason": "x"}, command=None)

    row = fake_db.get(invoice_id)
    assert (row["command"], row["lease_owner"], row["lease_until"]) == (None, None, None)
    assert fake_db.events[-1] == {"invoice_id": invoice_id, "action": "transition", "from_state": "received",
                                  "to_state": "needs_review", "actor": "aim_worker", "note": "why"}


# ---------------------------------------------------------------------------
# Only known columns ever reach the SQL
# ---------------------------------------------------------------------------

def test_unknown_columns_are_dropped_and_long_values_cut(v2):
    limited = v2("store").limited

    out = limited({"vendor_name": "x" * 300, "budget_unit": "4601", "state": "hacked", "id": 9, "DROP TABLE": 1})

    assert set(out) == {"vendor_name", "budget_unit"}
    assert len(out["vendor_name"]) == 255


# ---------------------------------------------------------------------------
# The SQL store.Db sends, on a connection that only records
# ---------------------------------------------------------------------------

class RecordingCursor:
    def __init__(self, log):
        self.log = log
        self.description = [("id",), ("batch_id",), ("state",), ("command",)]
        self.rowcount = 0

    def execute(self, sql, *params):
        self.log.append((" ".join(sql.split()), params))

    def fetchone(self):
        return (7, "A", "received", "extract")

    def fetchall(self):
        return [("ACME INC", "ACME")]


class RecordingConnection:
    def __init__(self, log):
        self.log = log
        self.committed = 0

    def cursor(self):
        return RecordingCursor(self.log)

    def commit(self):
        self.committed += 1

    def rollback(self):
        pass

    def close(self):
        pass

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass


@pytest.fixture
def db(v2, settings, monkeypatch):
    store = v2("store")
    log = []
    monkeypatch.setattr(store.pyodbc, "connect", lambda *a, **k: RecordingConnection(log))
    database = store.Db(settings)
    database.log = log
    return database


def test_the_tables_come_from_the_configured_schema(db):
    assert db.invoices == "aim.invoices"
    assert db.events == "aim.invoice_events"
    assert db.aliases == "aim.vendor_aliases"
    assert db.rules == "aim.vendor_rules"


def test_claiming_is_one_locked_statement_oldest_first(db):
    db.claim_next("gsa-scan02:aim_worker", 900)

    [(sql, params)] = db.log
    assert "WITH (UPDLOCK, READPAST)" in sql
    assert "command IS NOT NULL AND (lease_until IS NULL OR lease_until < SYSUTCDATETIME())" in sql
    assert "ORDER BY created_at, id" in sql
    assert "OUTPUT INSERTED.*" in sql
    assert params == ("gsa-scan02:aim_worker", 900)


def test_a_transition_writes_the_row_and_its_event_together(db):
    db.transition(7, "received", "extracting", note="attempt 1", fields={"attempt": 1, "bogus": "x"}, command="keep")

    update, event = db.log
    assert update[0].startswith("UPDATE aim.invoices SET attempt = ?, state = ?, updated_at = SYSUTCDATETIME() WHERE id = ?")
    assert update[1] == (1, "extracting", 7)
    assert event[0].startswith("INSERT INTO aim.invoice_events")
    assert event[1] == (7, "transition", "received", "extracting", "aim_worker", "attempt 1")


def test_clearing_the_command_clears_the_lease_and_stamps(db):
    db.transition(7, "exporting", "exported", stamp=("exported_at",), command=None)

    update, _ = db.log
    assert "command = ?, lease_owner = ?, lease_until = ?" in update[0]
    assert "exported_at = SYSUTCDATETIME()" in update[0]
    assert update[1] == ("exported", None, None, None, 7)


def test_a_new_row_gets_its_first_event(db):
    invoice_id = db.insert_invoice("A", "received", "extract", {"budget_unit": "4601"}, note="received from x")

    insert, event = db.log
    assert invoice_id == 7
    assert insert[0].startswith("INSERT INTO aim.invoices (batch_id, state, command, budget_unit, created_at, updated_at) OUTPUT INSERTED.id")
    assert event[1] == (7, "transition", None, "received", "aim_worker", "received from x")


def test_aliases_and_rules_are_read_from_their_tables(db):
    assert db.load_aliases() == {"ACME INC": "ACME"}
    assert db.log[0][0] == "SELECT extracted_name, normalized_name FROM aim.vendor_aliases"
    db.load_rules()
    assert db.log[1][0] == "SELECT vendor_name, rules FROM aim.vendor_rules"
