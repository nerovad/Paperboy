"""Where an invoice is, written down instead of implied by a folder.

Until now the only record of an invoice's progress was which directory its
folder sat in. Nothing said who moved it, when, or what it was before -- and a
folder that moved twice left no trace of the first move at all. Plan step 5.6.

Each worker calls `record_state` as it moves a batch. That writes two things
in one transaction: the invoice row says where the invoice is now, and an
append-only event says where it came from and who moved it.

Two deliberate choices:

* **The database is written UTC.** Rails reads these columns as UTC, so
  SYSUTCDATETIME() is what keeps a timestamp meaning the same thing in both.
* **A failure here does not stop the pipeline.** In this step the folders are
  still the truth: refusing to move an invoice because the database is
  unreachable would strand real work over bookkeeping. The failure is printed
  loudly and `Aim::QueueSync` rebuilds the rows from the share afterwards.
  Step 5.7 is where the row becomes the truth, and that trade changes with it.
"""
import traceback

from pipeline_common import env, get_sql_connection

# Section name for get_sql_connection: AIM_SQL_STATE_SERVER, _DATABASE, _USER
# and _PASSWORD. Read at import, like every other worker setting, so a fleet
# missing its configuration refuses to start instead of discovering it later.
SQL_SECTION = "SQL_STATE"

INVOICES_TABLE = env("AIM_SQL_STATE_TABLE")
EVENTS_TABLE = env("AIM_SQL_STATE_EVENTS_TABLE")

TRANSITION = "transition"


def record_state(batch_id, state, actor, note=None, connection=None):
    """Say that `batch_id` is now in `state`, and who put it there.

    Returns True when the database was written, False when it could not be --
    never raises, because the caller has an invoice to move either way.
    """
    try:
        own_connection = connection is None
        conn = connection or get_sql_connection(SQL_SECTION)
        try:
            written = _write(conn, batch_id, state, actor, note)
            conn.commit()
            return written
        except Exception:
            conn.rollback()
            raise
        finally:
            if own_connection:
                conn.close()
    except Exception as e:
        print(f"    [!] Could not record {batch_id} as {state}: {e}")
        traceback.print_exc()
        return False


def _write(conn, batch_id, state, actor, note):
    """The upsert and its event, inside the caller's transaction."""
    cursor = conn.cursor()
    cursor.execute(
        f"SELECT id, state FROM {INVOICES_TABLE} WHERE batch_id = ?", batch_id
    )
    row = cursor.fetchone()

    if row is None:
        invoice_id = _insert_invoice(cursor, batch_id, state)
        _insert_event(cursor, invoice_id, None, state, actor, note)
        return True

    invoice_id, previous_state = row[0], row[1]
    # Already recorded. Saying it twice would put a second event in the
    # history for a move that happened once, which is exactly what a worker
    # restarting mid-queue would do.
    if previous_state == state:
        return True

    cursor.execute(
        f"UPDATE {INVOICES_TABLE} SET state = ?, updated_at = SYSUTCDATETIME() WHERE id = ?",
        state,
        invoice_id,
    )
    _insert_event(cursor, invoice_id, previous_state, state, actor, note)
    return True


def _insert_invoice(cursor, batch_id, state):
    cursor.execute(
        f"INSERT INTO {INVOICES_TABLE} (batch_id, state, created_at, updated_at) "
        "OUTPUT INSERTED.id VALUES (?, ?, SYSUTCDATETIME(), SYSUTCDATETIME())",
        batch_id,
        state,
    )
    return cursor.fetchone()[0]


def _insert_event(cursor, invoice_id, from_state, to_state, actor, note):
    cursor.execute(
        f"INSERT INTO {EVENTS_TABLE} "
        "(invoice_id, action, from_state, to_state, actor, note, created_at) "
        "VALUES (?, ?, ?, ?, ?, ?, SYSUTCDATETIME())",
        invoice_id,
        TRANSITION,
        from_state,
        to_state,
        actor,
        note,
    )
