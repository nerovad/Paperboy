"""Stop the AI (#192): a person takes an invoice from the worker -- Paperboy
clears its lease -- and the worker gives it up. It stops at its next check in
(no more pages read) and writes nothing over the person's choice, before or
after the AI answers, and a failure after the stop is not recorded either."""
import pytest

BATCH = "4601.20261022_090000.Batch-[ST0P]"


@pytest.fixture
def worker(v2, settings, fake_db, pdf_maker):
    pdf_maker(settings.pdf_path(BATCH), pages=2)
    return v2("worker").Worker(settings, fake_db, name="test-host:aim_worker")


def take_from_ai(fake_db, invoice_id, state):
    """What Paperboy does: the person's move, the command and lease cleared."""
    fake_db.rows[invoice_id].update(state=state, command=None, lease_owner=None, lease_until=None)


def test_the_lease_says_the_worker_can_be_stopped(worker):
    assert worker.name == "test-host:aim_worker+stop"


def test_stopped_while_reading_it_reads_no_further_and_writes_nothing(worker, fake_db, v2, monkeypatch):
    invoice_id = fake_db.insert_invoice(BATCH, "received", "extract", {})
    pages_read = []

    def extract(*args, heartbeat, **kwargs):
        pages_read.append(1)
        heartbeat()
        take_from_ai(fake_db, invoice_id, "needs_review")
        heartbeat()  # the next check in finds it taken
        pages_read.append(2)
        raise AssertionError("never reached")

    monkeypatch.setattr(v2("worker"), "extract", extract)
    worker.run_once()

    row = fake_db.get(invoice_id)
    assert pages_read == [1]
    assert (row["state"], row["command"], row["lease_owner"]) == ("needs_review", None, None)
    assert [e["to_state"] for e in fake_db.events if e["invoice_id"] == invoice_id] == ["received", "extracting"]


def test_stopped_just_before_the_answer_is_written_drops_the_answer(worker, fake_db, v2, monkeypatch):
    extraction = v2("extraction")
    invoice_id = fake_db.insert_invoice(BATCH, "received", "extract", {})

    def extract(*args, **kwargs):
        take_from_ai(fake_db, invoice_id, "rejected")
        return extraction.ExtractionResult(outcome="clean", data=extraction.InvoiceData(document_type="Invoice", vendor_name="ACME"))

    monkeypatch.setattr(v2("worker"), "extract", extract)
    worker.run_once()

    row = fake_db.get(invoice_id)
    assert row["state"] == "rejected"
    assert row.get("vendor_name") is None, "the AI's answer is not written over the person's choice"


def test_a_failure_after_the_stop_is_not_recorded(worker, fake_db, v2, monkeypatch):
    invoice_id = fake_db.insert_invoice(BATCH, "received", "extract", {})

    def extract(*args, **kwargs):
        take_from_ai(fake_db, invoice_id, "received")  # held: no command
        raise RuntimeError("the model went away")

    monkeypatch.setattr(v2("worker"), "extract", extract)
    worker.run_once()

    row = fake_db.get(invoice_id)
    assert (row["state"], row["command"], row["review_reason"]) == ("received", None, None)


def test_a_held_invoice_is_left_alone_until_released(worker, fake_db, v2, monkeypatch):
    invoice_id = fake_db.insert_invoice(BATCH, "received", None, {})
    monkeypatch.setattr(v2("worker"), "extract", lambda *a, **k: pytest.fail("a held invoice was read"))

    assert worker.run_once() == 0
    assert fake_db.get(invoice_id)["state"] == "received"
