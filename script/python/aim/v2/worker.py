"""The AIM v2 worker: one process, driven by the rows.

Each cycle takes in whatever has been dropped in the watch tree, then claims
rows that carry a command and does what the command says:

    extract   read the PDF; the row becomes needs_review, needs_split,
              ready_for_approval, or failed
    split     cut the PDF by the row's manifest into child rows
    export    billing row, Laserfiche XML, archive copy; the row is exported

Every outcome clears the command and the lease, so a row is never left
claimed. A failure is recorded on the row (`failed`, with the reason) rather
than in a folder somewhere.
"""
import json
import socket
import sys
import time
import traceback

from settings import Settings, load_environment
from store import ACTOR, Db
from intake import Intake
from extraction import EXTRACTION_ERROR, extract
from splitting import SPLIT_ERROR, split_batch
from exporting import EXPORT_ERROR, export_invoice, insert_billing_row
from vendors import field_alias_text

LEASE_SECONDS = 900
IDLE_SLEEP_SECONDS = 5

OUTCOME_STATES = {"split": "needs_split", "review": "needs_review", "clean": "ready_for_approval"}
# The review_reason a failed command leaves on the row.
FAILURE_REASONS = {"extract": EXTRACTION_ERROR, "split": SPLIT_ERROR, "export": EXPORT_ERROR}


def data_fields(data):
    """The row's columns from an InvoiceData. A None is not written."""
    values = {
        "document_type": data.document_type,
        "extracted_vendor_name": data.extracted_vendor_name,
        "vendor_name": data.vendor_name,
        "invoice_number": data.invoice_number,
        "order_number": data.order_number,
        "customer_number": data.customer_number,
        "invoice_total": data.invoice_total,
        "invoice_date": data.invoice_date,
    }
    return {column: value for column, value in values.items() if value not in (None, "")}


class Worker:
    def __init__(self, settings, db, name=None, intake=None, billing_insert=None):
        self.settings = settings
        self.db = db
        self.name = name or f"{socket.gethostname()}:{ACTOR}"
        self.intake = intake or Intake(settings, db)
        # How the billing row is written; the tests hand in a recorder.
        self.billing_insert = billing_insert or insert_billing_row

    # -- the loop ---------------------------------------------------------

    def run_once(self):
        """One cycle: intake, then every claimable job. Returns jobs done."""
        try:
            self.intake.scan()
        except Exception as e:
            print(f"  [!] Intake pass failed: {e}")
            traceback.print_exc()
        done = 0
        while True:
            row = self.db.claim_next(self.name, LEASE_SECONDS)
            if row is None:
                return done
            self.dispatch(row)
            done += 1

    def run_forever(self):
        print("======================================================================")
        print("                 AIM v2 WORKER (row-first)")
        print("======================================================================")
        print(f"Watching '{self.settings.base_dir}' and the rows in {self.settings.invoices_table}...")
        try:
            while True:
                if self.run_once() == 0:
                    time.sleep(IDLE_SLEEP_SECONDS)
        except KeyboardInterrupt:
            print("\nWorker stopped.")

    # -- one job ----------------------------------------------------------

    def dispatch(self, row):
        command = row.get("command")
        handler = {"extract": self.do_extract, "split": self.do_split, "export": self.do_export}.get(command)
        print(f"\n[{command or 'no command'}] {row['batch_id']}")
        if handler is None:
            self.db.transition(row["id"], row["state"], row["state"],
                               note=f"unknown command {command!r} ignored", command=None)
            return
        try:
            handler(row)
        except Exception as e:
            print(f"    [!] {command} failed for {row['batch_id']}: {e}")
            traceback.print_exc()
            self.fail(row, FAILURE_REASONS[command], e)

    def fail(self, row, reason, error):
        current = self.db.get(row["id"]) or row
        self.db.transition(current["id"], current["state"], "failed",
                           note=f"{reason}: {error}",
                           fields={"review_reason": reason, "review_note": str(error)[:2000]},
                           command=None)

    def do_extract(self, row):
        self.db.transition(row["id"], row["state"], "extracting", note=f"attempt {int(row.get('attempt') or 0) + 1}")
        aliases = self.db.load_aliases()
        rules = self.db.load_rules()
        result = extract(
            self.settings.pdf_path(row["batch_id"]), self.settings, aliases, rules,
            field_alias_text=field_alias_text(self.settings.field_aliases_file),
            split_check=True if row.get("split_check") is None else bool(row.get("split_check")),
            heartbeat=lambda: self.db.renew_lease(row["id"], LEASE_SECONDS),
        )
        if result.learned_alias:
            extracted, normalized, note = result.learned_alias
            self.db.upsert_alias(extracted, normalized, learned_by=ACTOR, note=note)

        fields = data_fields(result.data)
        fields.update({
            "extracted": result.data.model_dump_json(),
            "high_confidence": bool(result.high_confidence),
            "attempt": int(row.get("attempt") or 0) + 1,
            "review_reason": result.review_reason,
            "review_note": result.review_note,
        })
        if result.outcome == "split":
            fields["manifest"] = json.dumps(result.manifest)
        state = OUTCOME_STATES[result.outcome]
        note = result.review_note if result.outcome == "review" else (
            f"{len(result.manifest['invoices'])} invoices in one file" if result.outcome == "split"
            else "fully extracted")
        self.db.transition(row["id"], "extracting", state, note=note, fields=fields, command=None)
        print(f"    [✓] {row['batch_id']} -> {state}" + (f" ({result.review_reason})" if result.review_reason else ""))

    def do_split(self, row):
        children = split_batch(row, self.settings, self.db)
        print(f"    [✓] {row['batch_id']} -> split into {len(children)}")

    def do_export(self, row):
        self.db.transition(row["id"], row["state"], "exporting")
        row = dict(row, state="exporting")
        note = export_invoice(row, self.settings, self.db, insert=self.billing_insert)
        self.db.transition(row["id"], "exporting", "exported", note=note,
                           fields={"review_reason": None, "review_note": None},
                           stamp=("exported_at",), command=None)


def main():
    load_environment()
    settings = Settings.from_env()
    Worker(settings, Db(settings)).run_forever()


if __name__ == "__main__":
    sys.exit(main())
