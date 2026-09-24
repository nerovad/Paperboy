"""Every invoice that arrives is billed, and its billing row follows it.

We charge for each invoice added, whatever becomes of it -- approved, rejected,
deleted. v2 first wrote the billing row only at export, so nothing reached
[GSA_Scan].[dbo].[Aim_Invoices] until someone approved. Now the worker upserts
the row, keyed by BatchID, whenever an invoice's state differs from what
billing last showed. Found 2026-09-24.
"""
import pytest

BATCH = "4601.20260924_100000.scan-[AB12]"


@pytest.fixture
def worker(v2, settings, fake_db):
    written = []
    worker_module = v2("worker")

    class NoIntake:
        def scan(self):
            pass

    w = worker_module.Worker(settings, fake_db, name="test-worker", intake=NoIntake(),
                             billing_insert=lambda s, payload: written.append(payload))
    return w, written


def test_an_invoice_is_billed_the_moment_it_arrives(worker, fake_db):
    w, written = worker
    invoice_id = fake_db.insert_invoice(BATCH, "received", None, {"budget_unit": "4601", "submitter": "Jane Doe"})

    w.sync_billing()

    [payload] = written
    assert payload["BatchID"] == BATCH and payload["Status"] == "Received" and payload["BU"] == "4601"
    assert fake_db.get(invoice_id)["billed_state"] == "received"
    w.sync_billing()
    assert len(written) == 1, "nothing is rewritten while the state is unchanged"


@pytest.mark.parametrize("state, status", [("rejected", "Rejected"), ("deleted", "Deleted"), ("exported", "Exported")])
def test_every_ending_reaches_billing(worker, fake_db, state, status):
    w, written = worker
    invoice_id = fake_db.insert_invoice(BATCH, "received", None, {})
    w.sync_billing()
    fake_db.rows[invoice_id]["state"] = state

    w.sync_billing()

    assert written[-1]["Status"] == status


def test_the_approver_is_named(worker, fake_db):
    w, written = worker
    invoice_id = fake_db.insert_invoice(BATCH, "ready_for_approval", None, {})
    fake_db.transition(invoice_id, "ready_for_approval", "approved", actor="gary.howard@example.com")

    w.sync_billing()

    assert written[-1]["Status"] == "Approved"
    assert written[-1]["ApprovedBy"] == "gary.howard@example.com"


def test_a_billing_failure_is_retried_and_holds_nothing_up(worker, fake_db, v2, settings):
    w, _ = worker
    w.billing_insert = lambda s, payload: (_ for _ in ()).throw(OSError("billing server away"))
    invoice_id = fake_db.insert_invoice(BATCH, "received", None, {})

    w.sync_billing()

    assert fake_db.get(invoice_id).get("billed_state") is None, "left for the next cycle"


def test_the_mapping_keys_the_row_by_batch_id(v2, settings):
    exporting = v2("exporting")
    columns = dict(exporting.billing_columns(settings, exporting.billing_payload(
        {"batch_id": BATCH, "state": "received"})))
    assert columns["[BatchID]"] == BATCH
    assert columns["[Invoice Status]"] == "Received"
    assert columns["[Source]"] == "AIM"
