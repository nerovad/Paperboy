"""What the v2 worker needs to know, read once at start.

There is no fallback for any variable (`env()` lives in worker_common, shared
with v1). A fallback is a hardcoded location living in the code, and a wrong
guess puts invoices somewhere nobody is watching. Everything is defined in LockBox; a
missing variable stops the worker before it does anything.

Nothing here is read at import. `Settings.from_env()` is called by the
worker's main, which is what keeps every module importable in a test against
a temporary environment.
"""
import os
from dataclasses import dataclass

import worker_common
from worker_common import env

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


def env_file_candidates():
    return worker_common.env_file_candidates(SCRIPT_DIR)


def load_environment():
    return worker_common.load_environment(SCRIPT_DIR)


def program_path(name):
    """A bare filename resolves against the worker's own folder."""
    return name if os.path.isabs(name) else os.path.join(SCRIPT_DIR, name)


# The tables beside the invoices table, in the same schema. The contract names
# them; the schema comes from AIM_SQL_STATE_TABLE so the three cannot drift.
ALIASES_TABLE_NAME = "vendor_aliases"
RULES_TABLE_NAME = "vendor_rules"


@dataclass(frozen=True)
class Settings:
    # Folders. The drop tree, the store, and where finished work goes.
    base_dir: str
    store_dir: str
    processed_dir: str
    archive_dir: str
    deleted_dir: str
    rejected_dir: str
    log_dir: str
    shared_folder_name: str
    # Models and OCR.
    tesseract_cmd: str
    text_model: str
    vision_model: str
    laserfiche_inbox_path: str
    field_aliases_file: str
    # Rows: the Paperboy database.
    odbc_driver: str
    odbc_encrypt: str
    state_server: str
    state_database: str
    state_user: str
    state_password: str
    invoices_table: str
    events_table: str
    # The billing row.
    billing_server: str
    billing_database: str
    billing_user: str
    billing_password: str
    billing_table: str
    billing_mapping_file: str

    @classmethod
    def from_env(cls):
        return cls(
            base_dir=env("AIM_BASE_DIR"),
            store_dir=env("AIM_STORE_DIR"),
            processed_dir=env("AIM_PROCESSED_DIR"),
            archive_dir=env("AIM_ARCHIVE_DIR"),
            deleted_dir=env("AIM_DELETED_DIR"),
            rejected_dir=env("AIM_REJECTED_DIR"),
            log_dir=env("AIM_LOG_DIR"),
            shared_folder_name=env("AIM_SHARED_FOLDER_NAME"),
            tesseract_cmd=env("AIM_TESSERACT_CMD"),
            text_model=env("AIM_TEXT_MODEL"),
            vision_model=env("AIM_VISION_MODEL"),
            laserfiche_inbox_path=env("AIM_LASERFICHE_INBOX_PATH"),
            field_aliases_file=program_path(env("AIM_FIELD_ALIASES_FILE")),
            odbc_driver=env("AIM_ODBC_DRIVER"),
            odbc_encrypt=env("AIM_ODBC_ENCRYPT"),
            state_server=env("AIM_SQL_STATE_SERVER"),
            state_database=env("AIM_SQL_STATE_DATABASE"),
            state_user=env("AIM_SQL_STATE_USER"),
            state_password=env("AIM_SQL_STATE_PASSWORD"),
            invoices_table=env("AIM_SQL_STATE_TABLE"),
            events_table=env("AIM_SQL_STATE_EVENTS_TABLE"),
            billing_server=env("AIM_SQL_BILLING_SERVER"),
            billing_database=env("AIM_SQL_BILLING_DATABASE"),
            billing_user=env("AIM_SQL_BILLING_USER"),
            billing_password=env("AIM_SQL_BILLING_PASSWORD"),
            billing_table=env("AIM_SQL_BILLING_TABLE"),
            billing_mapping_file=program_path(env("AIM_SQL_BILLING_MAPPING_FILE")),
        )

    @property
    def schema(self):
        """'aim' from 'aim.invoices'; '' when the table is unqualified."""
        return self.invoices_table.rsplit(".", 1)[0] if "." in self.invoices_table else ""

    def sibling_table(self, name):
        return f"{self.schema}.{name}" if self.schema else name

    @property
    def aliases_table(self):
        return self.sibling_table(ALIASES_TABLE_NAME)

    @property
    def rules_table(self):
        return self.sibling_table(RULES_TABLE_NAME)

    def store_folder(self, batch_id):
        return os.path.join(self.store_dir, batch_id)

    def pdf_path(self, batch_id):
        return os.path.join(self.store_folder(batch_id), f"{batch_id}.pdf")

    def xml_path(self, batch_id):
        return os.path.join(self.store_folder(batch_id), f"{batch_id}.xml")

    def connection_string(self, which):
        """'state' for the Paperboy database, 'billing' for the billing row."""
        server, database, user, password = {
            "state": (self.state_server, self.state_database, self.state_user, self.state_password),
            "billing": (self.billing_server, self.billing_database, self.billing_user, self.billing_password),
        }[which]
        database = database.replace("[", "").replace("]", "")
        return (
            f"DRIVER={{{self.odbc_driver}}};SERVER={server};DATABASE={database};"
            f"UID={user};PWD={password};Encrypt={self.odbc_encrypt};"
        )
