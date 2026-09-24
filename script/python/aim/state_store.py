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
import re
import traceback

from pipeline_common import env, get_sql_connection

# Section name for get_sql_connection: AIM_SQL_STATE_SERVER, _DATABASE, _USER
# and _PASSWORD. Read at import, like every other worker setting, so a fleet
# missing its configuration refuses to start instead of discovering it later.
SQL_SECTION = "SQL_STATE"

INVOICES_TABLE = env("AIM_SQL_STATE_TABLE")
EVENTS_TABLE = env("AIM_SQL_STATE_EVENTS_TABLE")

TRANSITION = "transition"

# The facts about an invoice the row carries, and the most each column holds
# (the limits in db/migrate/..._create_aim_invoices.rb). Column names are only
# ever taken from here, never from a caller, so nothing a document says can
# change the SQL. Plan step 5.7.
FIELD_LIMITS = {
    "budget_unit": 10,
    "submitter": 255,
    "document_type": 50,
    "extracted_vendor_name": 255,
    "vendor_name": 255,
    "invoice_number": 100,
    "order_number": 100,
    "customer_number": 100,
    "invoice_total": None,
    "invoice_date": None,
    "assigned_to": 255,
    "assignment_source": 50,
}

# The ones read straight off an InvoiceData, which uses the same names.
INVOICE_DATA_FIELDS = (
    "document_type", "extracted_vendor_name", "vendor_name", "invoice_number",
    "order_number", "customer_number", "invoice_total", "invoice_date",
)

MONEY = re.compile(r"^-?\d{1,13}(\.\d{1,2})?$")
ISO_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def invoice_facts(data=None, **known):
    """The row's columns, from an InvoiceData and anything else the caller knows.

    Only a value that fits its column is kept. A total that is not money or a
    date that is not a date is dropped rather than sent, because SQL Server
    refusing one column would refuse the whole write -- and with it the state
    the row exists to record. `sanitize_data` has already put both in their
    canonical form by the time a worker routes.
    """
    values = {}
    if data is not None:
        for name in INVOICE_DATA_FIELDS:
            values[name] = getattr(data, name, None)
    values.update(known)

    facts = {}
    for column, value in values.items():
        if column not in FIELD_LIMITS or value is None:
            continue
        value = str(value).strip()
        if not value:
            continue
        if column == "invoice_total" and not MONEY.match(value):
            continue
        if column == "invoice_date" and not ISO_DATE.match(value):
            continue
        limit = FIELD_LIMITS[column]
        facts[column] = value[:limit] if limit else value
    return facts


def record_state(batch_id, state, actor, note=None, connection=None, fields=None):
    """Say that `batch_id` is now in `state`, and who put it there.

    `fields` are facts about the invoice, from `invoice_facts`. A fact the
    caller does not know is simply absent, and never overwrites one an earlier
    worker recorded: the AI worker must not erase the owner the watcher wrote.

    Returns True when the database was written, False when it could not be --
    never raises, because the caller has an invoice to move either way.
    """
    try:
        own_connection = connection is None
        conn = connection or get_sql_connection(SQL_SECTION)
        try:
            written = _write(conn, batch_id, state, actor, note, fields or {})
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


def _write(conn, batch_id, state, actor, note, fields):
    """The upsert and its event, inside the caller's transaction."""
    fields = {column: value for column, value in fields.items() if column in FIELD_LIMITS}
    cursor = conn.cursor()
    cursor.execute(
        f"SELECT id, state FROM {INVOICES_TABLE} WHERE batch_id = ?", batch_id
    )
    row = cursor.fetchone()

    if row is None:
        invoice_id = _insert_invoice(cursor, batch_id, state, fields)
        _insert_event(cursor, invoice_id, None, state, actor, note)
        return True

    invoice_id, previous_state = row[0], row[1]
    # Already in this state: a worker restarting mid-queue re-reads folders it
    # already recorded, and saying it twice would put a second event in the
    # history for a move that happened once. Facts it now knows still land.
    moved = previous_state != state
    if not moved and not fields:
        return True

    assignments = dict(fields)
    if moved:
        assignments["state"] = state
    columns = ", ".join(f"{column} = ?" for column in assignments)
    cursor.execute(
        f"UPDATE {INVOICES_TABLE} SET {columns}, updated_at = SYSUTCDATETIME() WHERE id = ?",
        *assignments.values(),
        invoice_id,
    )
    if moved:
        _insert_event(cursor, invoice_id, previous_state, state, actor, note)
    return True


def _insert_invoice(cursor, batch_id, state, fields):
    columns = ["batch_id", "state", *fields]
    placeholders = ", ".join("?" for _ in columns)
    cursor.execute(
        f"INSERT INTO {INVOICES_TABLE} ({', '.join(columns)}, created_at, updated_at) "
        f"OUTPUT INSERTED.id VALUES ({placeholders}, SYSUTCDATETIME(), SYSUTCDATETIME())",
        batch_id,
        state,
        *fields.values(),
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
