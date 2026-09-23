"""Only a handwritten money amount sends an invoice to a person.

The vision model was asked whether the financials were handwritten, and
answered yes for an invoice whose subtotal, tax and total were all printed:
the only handwriting was an "OK to pay" and a signature beside them. The
flag also latched across pages, so any document with a signature page was
flagged, and the early return meant the vendor and missing-field checks never
ran -- the same invoice had no vendor name, and nobody would have been told.
Found in testing 2026-09-23 on Incentive Services CV62744.

The model now names which of subtotal, tax and total are handwritten, and the
flag follows that list. These tests stub the model and drive the worker's
real routing.
"""
import json
import os

import pytest


@pytest.fixture
def ai_worker(import_worker):
    return import_worker("01_AI_Extraction_Worker")


# ---------------------------------------------------------------------------
# The payload: the flag follows the named fields
# ---------------------------------------------------------------------------

def test_a_signature_alone_does_not_raise_the_flag(pipeline):
    """The model may still say "handwriting!" -- an empty list overrules it."""
    data = pipeline.InvoiceData(contains_handwritten_financials=True, handwritten_financial_fields=[])

    assert data.contains_handwritten_financials is False


def test_a_handwritten_total_raises_it(pipeline):
    data = pipeline.InvoiceData(handwritten_financial_fields=["total"])

    assert data.contains_handwritten_financials is True
    assert data.handwritten_financial_fields == ["total"]


def test_only_money_fields_count(pipeline):
    data = pipeline.InvoiceData(handwritten_financial_fields=["signature", "invoice_number", " TOTAL "])

    assert data.handwritten_financial_fields == ["total"]
    assert data.contains_handwritten_financials is True


def test_nothing_but_non_money_fields_is_no_flag(pipeline):
    data = pipeline.InvoiceData(handwritten_financial_fields=["signature", "po_number"])

    assert data.handwritten_financial_fields == []
    assert data.contains_handwritten_financials is False


def test_a_payload_from_before_the_change_reads_as_it_did(pipeline):
    """No list means the model was never asked; keep the flag as written."""
    assert pipeline.InvoiceData(contains_handwritten_financials=True).contains_handwritten_financials is True
    assert pipeline.InvoiceData().contains_handwritten_financials is False


# ---------------------------------------------------------------------------
# Across pages: the latch is per money field
# ---------------------------------------------------------------------------

def test_a_signature_page_does_not_flag_the_document(ai_worker, pipeline):
    master = pipeline.InvoiceData()
    ai_worker.merge_vision_fields(master, pipeline.InvoiceData(handwritten_financial_fields=[]))
    ai_worker.merge_vision_fields(master, pipeline.InvoiceData(handwritten_financial_fields=[]))

    assert master.contains_handwritten_financials is False


def test_a_handwritten_amount_on_a_later_page_still_flags_it(ai_worker, pipeline):
    master = pipeline.InvoiceData()
    ai_worker.merge_vision_fields(master, pipeline.InvoiceData(handwritten_financial_fields=[]))
    ai_worker.merge_vision_fields(master, pipeline.InvoiceData(handwritten_financial_fields=["tax"]))

    assert master.handwritten_financial_fields == ["tax"]
    assert master.contains_handwritten_financials is True


def test_a_clean_later_page_does_not_clear_an_earlier_find(ai_worker, pipeline):
    master = pipeline.InvoiceData()
    ai_worker.merge_vision_fields(master, pipeline.InvoiceData(handwritten_financial_fields=["total"]))
    ai_worker.merge_vision_fields(master, pipeline.InvoiceData(handwritten_financial_fields=[]))

    assert master.handwritten_financial_fields == ["total"]
    assert master.contains_handwritten_financials is True


def test_every_page_contributes(ai_worker, pipeline):
    master = pipeline.InvoiceData()
    ai_worker.merge_vision_fields(master, pipeline.InvoiceData(handwritten_financial_fields=["total"]))
    ai_worker.merge_vision_fields(master, pipeline.InvoiceData(handwritten_financial_fields=["subtotal"]))

    assert master.handwritten_financial_fields == ["subtotal", "total"]


# ---------------------------------------------------------------------------
# What the model is asked
# ---------------------------------------------------------------------------

def test_the_model_names_fields_rather_than_answering_yes_or_no(ai_worker, pipeline):
    properties = ai_worker.VISION_SCHEMA["properties"]

    assert "contains_handwritten_financials" not in properties
    assert properties["handwritten_financial_fields"]["items"]["enum"] == list(pipeline.HANDWRITTEN_FINANCIAL_FIELDS)
    assert "handwritten_financial_fields" in ai_worker.VISION_SCHEMA["required"]


# ---------------------------------------------------------------------------
# Routing
# ---------------------------------------------------------------------------

class FakeDoc:
    def __len__(self):
        return 1

    def close(self):
        pass


@pytest.fixture
def run_worker(ai_worker, queue_tree, monkeypatch):
    """Run one PDF through the worker; return (queue, ticket text, prompt, notes)."""
    def _run(handwritten):
        prompts, notes = [], []

        def chat(model, messages, format, options):
            if "images" in messages[0]:
                prompts.append(messages[0]["content"])
                return {"message": {"content": json.dumps({
                    "document_type": "Invoice", "extracted_vendor_name": "INCENTIVE SERVICES",
                    "invoice_date": "2026-06-22", "invoice_number": "CV62744",
                    "invoice_number_label": "Invoice #", "invoice_total": "134.69",
                    "order_number": "", "customer_number": "",
                    "handwritten_financial_fields": handwritten,
                })}}
            return {"message": {"content": json.dumps({
                "contains_multiple_invoices": False, "is_high_confidence": True,
                "document_type": "Invoice", "extracted_vendor_name": "INCENTIVE SERVICES",
            })}}

        monkeypatch.setattr(ai_worker.ollama, "chat", chat)
        monkeypatch.setattr(ai_worker.fitz, "open", lambda path: FakeDoc())
        monkeypatch.setattr(ai_worker, "pdf_page_to_image", lambda *args, **kwargs: None)
        monkeypatch.setattr(ai_worker.Image, "open", lambda path: None)
        monkeypatch.setattr(ai_worker.pytesseract, "image_to_string", lambda image: "INCENTIVE SERVICES CV62744")
        monkeypatch.setattr(ai_worker, "normalize_vendor_name", lambda name: ("INCENTIVE SERVICES", True))
        monkeypatch.setattr(ai_worker, "get_rules_for_vendor", lambda name: "")
        monkeypatch.setattr(ai_worker, "get_global_field_aliases", lambda: "")
        monkeypatch.setattr(ai_worker, "apply_invoice_number_rules", lambda data: None)
        monkeypatch.setattr(ai_worker, "write_log", lambda *args, **kwargs: None)
        monkeypatch.setattr(ai_worker, "record_state",
                            lambda batch_id, state, actor, note=None: notes.append((state, note)))

        batch_id = "4601.20260922_122048.Incentive Services_CV62744"
        folder = queue_tree.add_invoice("AIM_AI_QUEUE_DIR", batch_id)
        ai_worker.process_cpu_hybrid(os.path.join(folder, f"{batch_id}.pdf"), "4601", "Test User 3",
                                     processing_id=batch_id, original_filename="Incentive Services_CV62744.pdf")

        for variable in ("AIM_SQL_QUEUE_DIR", "AIM_LOW_CONFIDENCE_REVIEW_DIR"):
            landed = os.path.join(queue_tree.queue(variable), batch_id)
            if os.path.isdir(landed):
                ticket = os.path.join(landed, f"{batch_id}.ticket")
                text = open(ticket, encoding="utf-8").read() if os.path.exists(ticket) else ""
                return variable, text, prompts, notes
        raise AssertionError("the invoice landed in neither queue")

    return _run


def test_printed_totals_with_a_signature_go_straight_through(run_worker):
    """CV62744: every amount printed, "OK to pay" signed beside them."""
    queue, _, _, _ = run_worker(handwritten=[])

    assert queue == "AIM_SQL_QUEUE_DIR"


def test_a_handwritten_total_goes_to_a_person_saying_which(run_worker):
    queue, ticket, _, notes = run_worker(handwritten=["total"])

    assert queue == "AIM_LOW_CONFIDENCE_REVIEW_DIR"
    assert "written by hand: total" in ticket
    assert ("low_confidence_review", "handwritten: total") in notes


def test_the_prompt_says_a_signature_is_not_a_money_amount(run_worker):
    _, _, prompts, _ = run_worker(handwritten=[])

    assert prompts, "the vision model was never asked"
    assert "Signatures" in prompts[0]
    assert "handwritten_financial_fields" in prompts[0]
