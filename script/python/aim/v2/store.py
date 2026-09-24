"""The rows: how the worker claims work, records outcomes and reads its tables.

State lives on `aim.invoices`, only. Every state change here writes the row
and its event in one transaction, so the history and the row cannot
disagree. Timestamps are written with SYSUTCDATETIME(), which is what Rails
reads these columns as.

Work is claimed with one statement: the oldest row that has a command and no
live lease is updated to carry this worker's lease and returned. Two workers
cannot take the same row, and a worker that dies mid-job leaves a lease that
expires, after which the row is claimed again.

`Db` is the only module that speaks SQL. The tests drive everything else
against `FakeDb`, which implements the same methods in memory.
"""
import pyodbc

ACTOR = "aim_worker"
TRANSITION = "transition"

# The columns a worker may write, and the most each holds (the limits in
# db/migrate). Column names are only ever taken from here, never from a
# document, so nothing a document says can change the SQL.
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
    "subtotal": None,
    "sales_tax": None,
    "assigned_to": 255,
    "assignment_source": 50,
    "review_reason": 40,
    "review_note": None,
    "source_filename": 260,
    "source_path": 1000,
    "content_hash": 64,
    "page_count": None,
    "extracted": None,
    "manifest": None,
    "split_check": None,
    "high_confidence": None,
    "attempt": None,
    "parent_id": None,
    "exported_at": None,
}


def limited(fields):
    """Only known columns, each cut to its length. Unknown names are dropped."""
    out = {}
    for column, value in (fields or {}).items():
        if column not in FIELD_LIMITS:
            continue
        limit = FIELD_LIMITS[column]
        if isinstance(value, str) and limit:
            value = value[:limit]
        out[column] = value
    return out


class Db:
    def __init__(self, settings):
        self.settings = settings
        self.invoices = settings.invoices_table
        self.events = settings.events_table
        self.aliases = settings.aliases_table
        self.rules = settings.rules_table

    def connect(self):
        return pyodbc.connect(self.settings.connection_string("state"))

    # -- reading ----------------------------------------------------------

    def get(self, invoice_id):
        with self.connect() as conn:
            cursor = conn.cursor()
            cursor.execute(f"SELECT * FROM {self.invoices} WHERE id = ?", invoice_id)
            return _row(cursor, cursor.fetchone())

    def find_by_hash(self, content_hash):
        with self.connect() as conn:
            cursor = conn.cursor()
            cursor.execute(
                f"SELECT * FROM {self.invoices} WHERE content_hash = ? ORDER BY id DESC", content_hash)
            return [_row(cursor, r) for r in cursor.fetchall()]

    def load_aliases(self):
        with self.connect() as conn:
            cursor = conn.cursor()
            cursor.execute(f"SELECT extracted_name, normalized_name FROM {self.aliases}")
            return {row[0]: row[1] for row in cursor.fetchall()}

    def load_rules(self):
        with self.connect() as conn:
            cursor = conn.cursor()
            cursor.execute(f"SELECT vendor_name, rules FROM {self.rules}")
            return {row[0]: row[1] for row in cursor.fetchall()}

    # -- writing ----------------------------------------------------------

    def upsert_alias(self, extracted_name, normalized_name, learned_by=ACTOR, note=None):
        with self.connect() as conn:
            cursor = conn.cursor()
            cursor.execute(
                f"UPDATE {self.aliases} SET normalized_name = ?, learned_by = ?, note = ?, "
                "updated_at = SYSUTCDATETIME() WHERE extracted_name = ?",
                normalized_name, learned_by, note, extracted_name)
            if cursor.rowcount == 0:
                cursor.execute(
                    f"INSERT INTO {self.aliases} (extracted_name, normalized_name, learned_by, note, "
                    "created_at, updated_at) VALUES (?, ?, ?, ?, SYSUTCDATETIME(), SYSUTCDATETIME())",
                    extracted_name, normalized_name, learned_by, note)
            conn.commit()

    def insert_invoice(self, batch_id, state, command, fields, note=None, actor=ACTOR):
        """A new row and its first event, in one transaction. Returns the id."""
        fields = limited(fields)
        columns = ["batch_id", "state", "command", *fields]
        placeholders = ", ".join("?" for _ in columns)
        with self.connect() as conn:
            cursor = conn.cursor()
            try:
                cursor.execute(
                    f"INSERT INTO {self.invoices} ({', '.join(columns)}, created_at, updated_at) "
                    f"OUTPUT INSERTED.id VALUES ({placeholders}, SYSUTCDATETIME(), SYSUTCDATETIME())",
                    batch_id, state, command, *fields.values())
                invoice_id = cursor.fetchone()[0]
                _insert_event(cursor, self.events, invoice_id, None, state, actor, note)
                conn.commit()
            except Exception:
                conn.rollback()
                raise
        return invoice_id

    def claim_next(self, worker, lease_seconds):
        """The oldest row with a command and no live lease, now leased to `worker`."""
        with self.connect() as conn:
            cursor = conn.cursor()
            cursor.execute(
                f"WITH next_job AS ("
                f"  SELECT TOP(1) * FROM {self.invoices} WITH (UPDLOCK, READPAST)"
                f"  WHERE command IS NOT NULL AND (lease_until IS NULL OR lease_until < SYSUTCDATETIME())"
                f"  ORDER BY created_at, id"
                f") UPDATE next_job SET lease_owner = ?, "
                f"lease_until = DATEADD(second, ?, SYSUTCDATETIME()), updated_at = SYSUTCDATETIME() "
                f"OUTPUT INSERTED.*",
                worker, int(lease_seconds))
            row = _row(cursor, cursor.fetchone())
            conn.commit()
            return row

    def renew_lease(self, invoice_id, lease_seconds):
        with self.connect() as conn:
            cursor = conn.cursor()
            cursor.execute(
                f"UPDATE {self.invoices} SET lease_until = DATEADD(second, ?, SYSUTCDATETIME()) WHERE id = ?",
                int(lease_seconds), invoice_id)
            conn.commit()

    def billing_pending(self, limit=50):
        """Rows whose billing row does not yet show their current state."""
        with self.connect() as conn:
            cursor = conn.cursor()
            cursor.execute(f"SELECT TOP {int(limit)} * FROM {self.invoices} "
                           "WHERE billed_state IS NULL OR billed_state <> state ORDER BY id")
            return [_row(cursor, record) for record in cursor.fetchall()]

    def mark_billed(self, invoice_id, state):
        """Record that billing shows `state`, unless the row has moved on since."""
        with self.connect() as conn:
            cursor = conn.cursor()
            cursor.execute(f"UPDATE {self.invoices} SET billed_state = ? WHERE id = ? AND state = ?",
                           state, invoice_id, state)
            conn.commit()

    def approved_by(self, invoice_id):
        """Who approved the invoice: the actor of its last move to approved."""
        with self.connect() as conn:
            cursor = conn.cursor()
            cursor.execute(f"SELECT TOP 1 actor FROM {self.events} WHERE invoice_id = ? AND to_state = 'approved' "
                           "ORDER BY created_at DESC, id DESC", invoice_id)
            record = cursor.fetchone()
            return record[0] if record else None

    def transition(self, invoice_id, from_state, to_state, note=None, fields=None,
                   command="keep", stamp=(), actor=ACTOR):
        """Move a row to `to_state`, write its facts and its event together.

        `command` is 'keep' to leave it as it is (the worker is still on the
        job), None to clear it -- which also releases the lease -- or a new
        command to set. `stamp` names datetime columns set to now, in the
        database's clock.
        """
        fields = limited(fields)
        assignments = dict(fields)
        assignments["state"] = to_state
        if command != "keep":
            assignments["command"] = command
            if command is None:
                assignments["lease_owner"] = None
                assignments["lease_until"] = None
        columns = ", ".join(f"{column} = ?" for column in assignments)
        for column in stamp:
            if column in FIELD_LIMITS:
                columns += f", {column} = SYSUTCDATETIME()"
        with self.connect() as conn:
            cursor = conn.cursor()
            try:
                cursor.execute(
                    f"UPDATE {self.invoices} SET {columns}, updated_at = SYSUTCDATETIME() WHERE id = ?",
                    *assignments.values(), invoice_id)
                if from_state != to_state:
                    _insert_event(cursor, self.events, invoice_id, from_state, to_state, actor, note)
                conn.commit()
            except Exception:
                conn.rollback()
                raise


def _row(cursor, record):
    if record is None:
        return None
    return {column[0]: value for column, value in zip(cursor.description, record)}


def _insert_event(cursor, events_table, invoice_id, from_state, to_state, actor, note):
    cursor.execute(
        f"INSERT INTO {events_table} (invoice_id, action, from_state, to_state, actor, note, created_at) "
        "VALUES (?, ?, ?, ?, ?, ?, SYSUTCDATETIME())",
        invoice_id, TRANSITION, from_state, to_state, actor, note)
