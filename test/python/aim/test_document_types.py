"""Six document types, one spelling, and only Unknown held back. Plan step 5.3a.

The extraction worker asked the models for `INVOICE`, `STATEMENT`, `CREDIT`
or `UNKNOWN` and sent anything but an invoice to review. The decided list is
Invoice, Memo, Credit, Coupon, Statement and Unknown, and every type flows
through the same queues -- so a Memo, Credit, Coupon or Statement is now
extracted like an invoice, and only Unknown stops for AIM staff to settle in
QA review.

These tests stub the model, OCR and PDF calls and drive the worker's real
routing. Whether the model classifies a real document well is not something a
unit test can say; that is checked by hand on GSA-SCAN02.
"""
import json
import os
import xml.etree.ElementTree as ET

import pytest

KNOWN_TYPES = ["Invoice", "Memo", "Credit", "Coupon", "Statement"]


@pytest.fixture
def ai_worker(import_worker):
    return import_worker("01_AI_Extraction_Worker")


# ---------------------------------------------------------------------------
# One spelling
# ---------------------------------------------------------------------------

def test_the_six_types(pipeline):
    assert pipeline.DOCUMENT_TYPES == ("Invoice", "Memo", "Credit", "Coupon", "Statement", "Unknown")


@pytest.mark.parametrize("answer, spelled", [
    ("Invoice", "Invoice"),
    ("INVOICE", "Invoice"),
    ("credit", "Credit"),
    ("  Statement ", "Statement"),
    ("'Coupon'", "Coupon"),
    ("MEMO", "Memo"),
    ("UNKNOWN", "Unknown"),
])
def test_any_case_of_a_known_type_is_spelled_one_way(pipeline, answer, spelled):
    assert pipeline.normalize_document_type(answer) == spelled


@pytest.mark.parametrize("answer", [None, "", "   ", "Receipt", "Bill of sale", 42])
def test_anything_else_is_unknown(pipeline, answer):
    assert pipeline.normalize_document_type(answer) == "Unknown"


def test_invoice_data_spells_the_type_it_is_given(pipeline):
    assert pipeline.InvoiceData(document_type="CREDIT").document_type == "Credit"
    assert pipeline.InvoiceData.model_validate_json('{"document_type": "memo"}').document_type == "Memo"


def test_invoice_data_leaves_an_unanswered_type_unset(pipeline):
    """merge_vision_fields fills blanks only, so "not answered" must stay None."""
    assert pipeline.InvoiceData().document_type is None


def test_the_xml_template_name_is_unchanged_for_legacy_payloads(pipeline, tmp_path):
    """Payloads written before 5.3a say INVOICE; Laserfiche must still see Invoice."""
    xml_path = tmp_path / "x.xml"
    pipeline.generate_laserfiche_xml(pipeline.InvoiceData(document_type="INVOICE"), "4601", "Jane", str(xml_path), "id")

    assert ET.parse(xml_path).find("Doc/TemplateName").text == "Invoice"


# ---------------------------------------------------------------------------
# What the models are asked
# ---------------------------------------------------------------------------

def test_both_prompts_describe_all_six(pipeline):
    for name in pipeline.DOCUMENT_TYPES:
        assert f"'{name}'" in pipeline.DOCUMENT_TYPE_GUIDE
        assert f"{name}:" in pipeline.DOCUMENT_TYPE_GUIDE


def test_both_schemas_confine_the_model_to_the_six(ai_worker, pipeline):
    phase1 = ai_worker.Phase1Data.model_json_schema()["properties"]["document_type"]
    vision = ai_worker.VISION_SCHEMA["properties"]["document_type"]

    assert phase1["enum"] == list(pipeline.DOCUMENT_TYPES)
    assert vision["enum"] == list(pipeline.DOCUMENT_TYPES)


def test_an_off_list_phase1_answer_is_not_a_hallucination_error(ai_worker):
    data = ai_worker.Phase1Data.model_validate_json(
        '{"contains_multiple_invoices": false, "is_high_confidence": true, "document_type": "INVOICE"}'
    )
    assert data.document_type == "INVOICE"


# ---------------------------------------------------------------------------
# Routing
# ---------------------------------------------------------------------------

class FakeDoc:
    def __len__(self):
        return 1

    def close(self):
        pass


def vision_answer(document_type):
    return json.dumps({
        "document_type": document_type,
        "extracted_vendor_name": "ACME SUPPLY",
        "invoice_date": "2026-09-21",
        "invoice_number": "INV-1001",
        "invoice_number_label": "Invoice #",
        "invoice_total": "100.00",
        "order_number": "",
        "customer_number": "",
        "contains_handwritten_financials": False,
    })


@pytest.fixture
def run_worker(ai_worker, queue_tree, monkeypatch):
    """Run one PDF through process_cpu_hybrid with the models scripted.

    Returns (queue directory the invoice landed in, vision calls made).
    """
    def _run(phase1_type, vision_type=None):
        calls = {"vision": 0}

        def chat(model, messages, format, options):
            if "images" in messages[0]:
                calls["vision"] += 1
                return {"message": {"content": vision_answer(vision_type or phase1_type)}}
            return {"message": {"content": json.dumps({
                "contains_multiple_invoices": False, "is_high_confidence": True,
                "document_type": phase1_type, "extracted_vendor_name": "ACME SUPPLY",
            })}}

        monkeypatch.setattr(ai_worker.ollama, "chat", chat)
        monkeypatch.setattr(ai_worker.fitz, "open", lambda path: FakeDoc())
        monkeypatch.setattr(ai_worker, "pdf_page_to_image", lambda *args, **kwargs: None)
        monkeypatch.setattr(ai_worker.Image, "open", lambda path: None)
        monkeypatch.setattr(ai_worker.pytesseract, "image_to_string", lambda image: "ACME SUPPLY INVOICE INV-1001")
        monkeypatch.setattr(ai_worker, "normalize_vendor_name", lambda name: ("ACME SUPPLY", True))
        monkeypatch.setattr(ai_worker, "get_rules_for_vendor", lambda name: "")
        monkeypatch.setattr(ai_worker, "get_global_field_aliases", lambda: "")
        monkeypatch.setattr(ai_worker, "apply_invoice_number_rules", lambda data: None)
        monkeypatch.setattr(ai_worker, "write_log", lambda *args, **kwargs: None)

        batch_id = "4601.20260922_120000.scan-[AB12]"
        folder = queue_tree.add_invoice("AIM_AI_QUEUE_DIR", batch_id)
        ai_worker.process_cpu_hybrid(os.path.join(folder, f"{batch_id}.pdf"), "4601", "Jane Doe",
                                     processing_id=batch_id, original_filename="scan.pdf")

        landed = [variable for variable in ("AIM_SQL_QUEUE_DIR", "AIM_ACTION_NEEDED_DIR")
                  if os.path.isdir(os.path.join(queue_tree.queue(variable), batch_id))]
        assert len(landed) == 1, f"expected the invoice in exactly one queue, found {landed}"
        return landed[0], os.path.join(queue_tree.queue(landed[0]), batch_id, f"{batch_id}.xml"), calls

    return _run


@pytest.mark.parametrize("document_type", KNOWN_TYPES)
def test_every_known_type_is_extracted_and_queued(run_worker, document_type):
    queue, xml_path, calls = run_worker(document_type)

    assert queue == "AIM_SQL_QUEUE_DIR"
    assert calls["vision"] == 1
    assert ET.parse(xml_path).find("Doc/TemplateName").text == document_type


def test_the_old_uppercase_answer_is_still_understood(run_worker):
    queue, xml_path, _ = run_worker("CREDIT")

    assert queue == "AIM_SQL_QUEUE_DIR"
    assert ET.parse(xml_path).find("Doc/TemplateName").text == "Credit"


@pytest.mark.parametrize("phase1_type", ["Unknown", "Receipt", ""])
def test_a_document_the_text_pass_cannot_place_stops_before_vision(run_worker, phase1_type):
    queue, _, calls = run_worker(phase1_type)

    assert queue == "AIM_ACTION_NEEDED_DIR"
    assert calls["vision"] == 0


def test_a_document_the_vision_pass_cannot_place_goes_to_review(run_worker):
    queue, xml_path, calls = run_worker("Statement", vision_type="Unknown")

    assert queue == "AIM_ACTION_NEEDED_DIR"
    assert calls["vision"] == 1
    assert ET.parse(xml_path).find("Doc/TemplateName").text == "Unknown"
