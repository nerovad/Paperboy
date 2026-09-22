"""The workers write down where an invoice is. Plan step 5.6.

Where an invoice sat used to be implied by which folder held it, so a move
left no trace of what came before and no name against it. `record_state`
writes the row and an append-only event in one transaction.

Nothing here opens a database: the connection is a double that records the
statements it was given, which is also how these tests can say what the SQL
actually is.
"""
import pytest


class FakeCursor:
    def __init__(self, connection):
        self.connection = connection
        self._result = None

    def execute(self, sql, *params):
        self.connection.statements.append((" ".join(sql.split()), params))
        if sql.lstrip().startswith("SELECT"):
            self._result = self.connection.existing_row
        elif "OUTPUT INSERTED.id" in sql:
            self._result = (self.connection.new_id,)
        else:
            self._result = None
        return self

    def fetchone(self):
        return self._result


class FakeConnection:
    def __init__(self, existing_row=None, new_id=7, fail_on=None):
        self.existing_row = existing_row
        self.new_id = new_id
        self.fail_on = fail_on
        self.statements = []
        self.committed = 0
        self.rolled_back = 0
        self.closed = 0

    def cursor(self):
        if self.fail_on == "cursor":
            raise RuntimeError("the database is not there")
        return FakeCursor(self)

    def commit(self):
        self.committed += 1

    def rollback(self):
        self.rolled_back += 1

    def close(self):
        self.closed += 1


@pytest.fixture
def store(fake_environment):
    import state_store

    return state_store


def statements_of(connection, keyword):
    return [sql for sql, _ in connection.statements if sql.startswith(keyword)]


def params_of(connection, keyword):
    return [params for sql, params in connection.statements if sql.startswith(keyword)]


# ---------------------------------------------------------------------------
# An invoice the database has never seen
# ---------------------------------------------------------------------------

def test_a_new_invoice_is_written_with_its_first_event(store):
    conn = FakeConnection(existing_row=None, new_id=42)

    assert store.record_state("4601.A", "ai_queue", "00_ingestion_watcher", "spooled", connection=conn)

    inserts = statements_of(conn, "INSERT")
    assert len(inserts) == 2, conn.statements
    assert store.INVOICES_TABLE in inserts[0]
    assert store.EVENTS_TABLE in inserts[1]

    invoice_params, event_params = params_of(conn, "INSERT")
    assert invoice_params == ("4601.A", "ai_queue")
    assert event_params == (42, "transition", None, "ai_queue", "00_ingestion_watcher", "spooled")


def test_the_first_event_has_no_state_before_it(store):
    conn = FakeConnection(existing_row=None)
    store.record_state("4601.A", "ai_queue", "00_ingestion_watcher", connection=conn)

    _, event_params = params_of(conn, "INSERT")
    assert event_params[2] is None, "an invoice that has just appeared came from nowhere"


# ---------------------------------------------------------------------------
# An invoice that has moved
# ---------------------------------------------------------------------------

def test_a_move_updates_the_row_and_records_where_it_came_from(store):
    conn = FakeConnection(existing_row=(7, "ai_queue"))

    assert store.record_state("4601.A", "sql_queue", "01_ai_extraction_worker", connection=conn)

    assert statements_of(conn, "UPDATE"), conn.statements
    assert params_of(conn, "UPDATE") == [("sql_queue", 7)]
    assert params_of(conn, "INSERT") == [(7, "transition", "ai_queue", "sql_queue", "01_ai_extraction_worker", None)]


def test_saying_it_again_writes_nothing(store):
    """A worker restarting mid-queue re-reads folders it already recorded."""
    conn = FakeConnection(existing_row=(7, "sql_queue"))

    assert store.record_state("4601.A", "sql_queue", "01_ai_extraction_worker", connection=conn)

    assert statements_of(conn, "UPDATE") == []
    assert statements_of(conn, "INSERT") == []
    assert conn.committed == 1


# ---------------------------------------------------------------------------
# The pipeline keeps moving when the database does not
# ---------------------------------------------------------------------------

def test_a_database_that_is_not_there_does_not_stop_the_worker(store):
    conn = FakeConnection(fail_on="cursor")

    assert store.record_state("4601.A", "ai_queue", "00_ingestion_watcher", connection=conn) is False
    assert conn.rolled_back == 1
    assert conn.committed == 0


def test_a_failure_rolls_back_rather_than_leaving_half_a_history(store, monkeypatch):
    conn = FakeConnection(existing_row=None)
    original = conn.cursor

    def fail_after_the_invoice_row():
        cursor = original()
        real_execute = cursor.execute

        def execute(sql, *params):
            if store.EVENTS_TABLE in sql:
                raise RuntimeError("event write failed")
            return real_execute(sql, *params)

        cursor.execute = execute
        return cursor

    conn.cursor = fail_after_the_invoice_row

    assert store.record_state("4601.A", "ai_queue", "watcher", connection=conn) is False
    assert conn.rolled_back == 1
    assert conn.committed == 0


# ---------------------------------------------------------------------------
# Configuration, not literals
# ---------------------------------------------------------------------------

def test_the_tables_come_from_the_environment(store, monkeypatch):
    assert store.INVOICES_TABLE == "aim.invoices"
    assert store.EVENTS_TABLE == "aim.invoice_events"


def test_the_connection_is_opened_and_closed_when_none_is_given(store, monkeypatch):
    conn = FakeConnection(existing_row=None)
    asked = []

    monkeypatch.setattr(store, "get_sql_connection", lambda section: asked.append(section) or conn)

    assert store.record_state("4601.A", "ai_queue", "watcher")
    assert asked == ["SQL_STATE"]
    assert conn.closed == 1


def test_a_connection_that_was_handed_in_is_left_open(store):
    conn = FakeConnection(existing_row=None)
    store.record_state("4601.A", "ai_queue", "watcher", connection=conn)

    assert conn.closed == 0


def test_times_are_written_in_utc(store):
    """Rails reads these columns as UTC; SYSUTCDATETIME is what agrees."""
    conn = FakeConnection(existing_row=(7, "ai_queue"))
    store.record_state("4601.A", "sql_queue", "worker", connection=conn)

    written = " ".join(sql for sql, _ in conn.statements)
    assert "SYSUTCDATETIME()" in written
    assert "GETDATE()" not in written
