"""What the worker records after reading a PDF, with the models scripted.

Every outcome ends with the command cleared, the lease released, the attempt
counted and the extracted JSON kept, so a row is never left claimed.
"""
import json

import pytest

BATCH = "4601.20260924_090000.Scan 001-[AB12]"

PHASE1_CLEAN = {"contains_multiple_invoices": False, "is_high_confidence": True,
                "document_type": "Invoice", "extracted_vendor_name": "ACME SUPPLY"}
VISION_CLEAN = {"document_type": "Invoice", "extracted_vendor_name": "ACME SUPPLY",
                "invoice_date": "2026-09-21", "invoice_number": "INV-1001", "invoice_number_label": "Invoice #",
                "invoice_total": "$100.00", "order_number": "", "customer_number": "",
                "handwritten_financial_fields": []}
MANIFEST = {"invoices": [{"vendor_name": "ACME", "invoice_number": "INV-1", "pages": [1, 2]},
                         {"vendor_name": "ACME", "invoice_number": "INV-2", "pages": [3]}]}


def reply(payload):
    return {"message": {"content": json.dumps(payload)}}


@pytest.fixture
def run(v2, settings, fake_db, pdf_maker, monkeypatch):
    """Insert one received row with a PDF, script the models, run the worker once."""
    extraction = v2("extraction")
    intake = v2("intake")
    worker_module = v2("worker")

    def _run(phase1=PHASE1_CLEAN, vision=VISION_CLEAN, manifest=MANIFEST, smart="NO",
             aliases=None, pages=1, split_check=True, crash=None):
        calls = {"vision": 0, "text": 0}

        def chat(model, messages, format=None, options=None):
            if crash:
                raise crash
            message = messages[0]
            if "images" in message:
                calls["vision"] += 1
                return reply(vision)
            content = message["content"]
            if "Reply strictly with YES or NO" in content:
                return {"message": {"content": smart}}
            if "Identify each distinct invoice" in content:
                return reply(manifest)
            calls["text"] += 1
            return reply(phase1)

        monkeypatch.setattr(extraction.ollama, "chat", chat)
        monkeypatch.setattr(extraction.pytesseract, "image_to_string", lambda image: "ACME SUPPLY INVOICE INV-1001")
        fake_db.aliases = dict({"ACME SUPPLY": "ACME SUPPLY"} if aliases is None else aliases)

        pdf_maker(settings.pdf_path(BATCH), pages=pages)
        invoice_id = fake_db.insert_invoice(BATCH, "received", "extract", {
            "budget_unit": "4601", "submitter": "Jane Doe", "assigned_to": "Jane Doe",
            "assignment_source": "folder", "split_check": split_check, "attempt": 0,
        })
        worker = worker_module.Worker(settings, fake_db, name="test-worker",
                                      intake=intake.Intake(settings, fake_db, stable=lambda p: True))
        assert worker.run_once() == 1
        return fake_db.get(invoice_id), calls

    return _run


def states(fake_db):
    return [(e["from_state"], e["to_state"]) for e in fake_db.events]


def test_a_clean_invoice_is_ready_for_approval_with_its_fields(run, fake_db):
    row, calls = run()

    assert row["state"] == "ready_for_approval"
    assert row["review_reason"] is None
    assert row["vendor_name"] == "ACME SUPPLY"
    assert row["extracted_vendor_name"] == "ACME SUPPLY"
    assert row["invoice_number"] == "INV-1001"
    assert row["invoice_total"] == "100.00", "sanitised: one spelling for an amount"
    assert row["invoice_date"] == "2026-09-21"
    assert row["document_type"] == "Invoice"
    assert row["high_confidence"] is True
    assert calls["vision"] == 1
    assert json.loads(row["extracted"])["invoice_number"] == "INV-1001"
    assert states(fake_db) == [(None, "received"), ("received", "extracting"), ("extracting", "ready_for_approval")]


@pytest.mark.parametrize("phase1_type", ["Unknown", "Receipt", ""])
def test_a_document_the_text_pass_cannot_place_stops_before_vision(run, phase1_type):
    row, calls = run(phase1=dict(PHASE1_CLEAN, document_type=phase1_type))

    assert row["state"] == "needs_review"
    assert row["review_reason"] == "unknown_type"
    assert row["document_type"] == "Unknown"
    assert calls["vision"] == 0


def test_a_document_the_vision_pass_cannot_place_goes_to_review(run):
    row, calls = run(vision=dict(VISION_CLEAN, document_type="Unknown"))

    assert row["state"] == "needs_review"
    assert row["review_reason"] == "unknown_type"
    assert calls["vision"] == 1


def test_an_unknown_vendor_goes_to_review_naming_it(run):
    row, _ = run(aliases={}, vision=dict(VISION_CLEAN, extracted_vendor_name="NEW CO"),
                 phase1=dict(PHASE1_CLEAN, extracted_vendor_name="NEW CO"))

    assert row["state"] == "needs_review"
    assert row["review_reason"] == "unknown_vendor"
    assert "NEW CO" in row["review_note"]
    assert row["extracted_vendor_name"] == "NEW CO"
    assert row["vendor_name"] is None


def test_missing_fields_go_to_review_naming_them(run):
    row, _ = run(vision=dict(VISION_CLEAN, invoice_number=""))

    assert row["state"] == "needs_review"
    assert row["review_reason"] == "missing_fields"
    assert "Invoice Number" in row["review_note"]


def test_a_poor_read_goes_to_review(run):
    row, _ = run(phase1=dict(PHASE1_CLEAN, is_high_confidence=False))

    assert row["state"] == "needs_review"
    assert row["review_reason"] == "low_confidence"
    assert row["high_confidence"] is False


def test_a_handwritten_total_goes_to_a_person_saying_which(run):
    row, _ = run(vision=dict(VISION_CLEAN, handwritten_financial_fields=["total"]))

    assert row["state"] == "needs_review"
    assert row["review_reason"] == "handwritten"
    assert "written by hand: total" in row["review_note"]


def test_several_invoices_in_one_file_go_to_split_with_the_manifest(run, fake_db):
    row, calls = run(phase1=dict(PHASE1_CLEAN, contains_multiple_invoices=True), pages=3)

    assert row["state"] == "needs_split"
    assert json.loads(row["manifest"])["invoices"][1]["pages"] == [3]
    assert calls["vision"] == 0
    assert states(fake_db)[-1] == ("extracting", "needs_split")


def test_a_model_failure_is_recorded_on_the_row_not_in_a_folder(run, fake_db):
    row, _ = run(crash=RuntimeError("AI server disconnected"))

    assert row["state"] == "failed"
    assert row["review_reason"] == "extraction_error"
    assert "AI server disconnected" in row["review_note"]
    assert states(fake_db)[-1] == ("extracting", "failed")


def test_process_as_one_invoice_skips_the_split_check(run):
    row, calls = run(phase1=dict(PHASE1_CLEAN, contains_multiple_invoices=True), split_check=False)

    assert row["state"] == "ready_for_approval"
    assert calls["text"] == 0, "no phase-1 pass at all"


@pytest.mark.parametrize("scenario", ["clean", "review", "split", "crash"])
def test_every_outcome_clears_the_command_and_counts_the_attempt(run, scenario):
    row, _ = {
        "clean": lambda: run(),
        "review": lambda: run(vision=dict(VISION_CLEAN, invoice_number="")),
        "split": lambda: run(phase1=dict(PHASE1_CLEAN, contains_multiple_invoices=True), pages=2),
        "crash": lambda: run(crash=RuntimeError("boom")),
    }[scenario]()

    assert row["command"] is None
    assert row["lease_owner"] is None
    assert row["lease_until"] is None
    if scenario != "crash":
        assert row["attempt"] == 1


def test_a_near_miss_the_model_confirms_is_learned_as_an_alias(run, fake_db):
    row, _ = run(aliases={"HOME DEPOT": "The Home Depot"}, smart="YES",
                 phase1=dict(PHASE1_CLEAN, extracted_vendor_name="HOME DEPOT #1234"),
                 vision=dict(VISION_CLEAN, extracted_vendor_name="HOME DEPOT #1234"))

    assert row["vendor_name"] == "The Home Depot"
    assert row["state"] == "ready_for_approval"
    assert fake_db.alias_writes[0][:2] == ("HOME DEPOT #1234", "The Home Depot")
