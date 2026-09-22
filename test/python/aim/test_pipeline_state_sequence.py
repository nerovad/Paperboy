"""A batch through the fake tree writes the history it should. Plan step 5.6.

The other state tests check one call. This one runs a document the way the
share does -- dropped in the watch tree, spooled by the watcher, picked up by
the AI worker -- and asks what the invoice's history says afterwards. That is
the question the folders could never answer: not where it is, but where it has
been, and who moved it.

The models, OCR and PDF calls are stubbed; the routing is the workers' own.
"""
import json
import os

import pytest


@pytest.fixture
def watcher(import_worker):
    return import_worker("00_Ingestion_Watcher")


@pytest.fixture
def ai_worker(import_worker):
    return import_worker("01_AI_Extraction_Worker")


@pytest.fixture
def watch_tree(queue_tree):
    os.makedirs(os.environ["AIM_BASE_DIR"], exist_ok=True)
    os.makedirs(os.environ["AIM_SPOOL_STATE_DIR"], exist_ok=True)
    return queue_tree


class FakeDoc:
    def __len__(self):
        return 1

    def close(self):
        pass


def vision_answer(document_type):
    return json.dumps({
        "document_type": document_type,
        "extracted_vendor_name": "ACME SUPPLY",
        "invoice_date": "2026-09-22",
        "invoice_number": "INV-1001",
        "invoice_number_label": "Invoice #",
        "invoice_total": "100.00",
        "order_number": "",
        "customer_number": "",
        "contains_handwritten_financials": False,
    })


@pytest.fixture
def pipeline_run(watcher, ai_worker, watch_tree, monkeypatch):
    """Drop a PDF in the watch tree, run both workers, return the history."""
    history = []

    def _run(document_type="Invoice", submitter="Jane Doe", bu="4601"):
        monkeypatch.setattr(watcher, "record_state",
                            lambda batch_id, state, actor, note=None: history.append((batch_id, state, actor)))
        monkeypatch.setattr(ai_worker, "record_state",
                            lambda batch_id, state, actor, note=None: history.append((batch_id, state, actor)))
        monkeypatch.setattr(watcher, "is_file_stable", lambda *args, **kwargs: True)

        folder = os.path.join(watcher.BASE_DIR, bu, submitter)
        os.makedirs(folder, exist_ok=True)
        with open(os.path.join(folder, "Scan 001.pdf"), "wb") as handle:
            handle.write(b"%PDF-1.4 test\n")

        watcher.scan_and_spool()

        def chat(model, messages, format, options):
            if "images" in messages[0]:
                return {"message": {"content": vision_answer(document_type)}}
            return {"message": {"content": json.dumps({
                "contains_multiple_invoices": False, "is_high_confidence": True,
                "document_type": document_type, "extracted_vendor_name": "ACME SUPPLY",
            })}}

        monkeypatch.setattr(ai_worker.ollama, "chat", chat)
        monkeypatch.setattr(ai_worker.fitz, "open", lambda path: FakeDoc())
        monkeypatch.setattr(ai_worker, "pdf_page_to_image", lambda *args, **kwargs: None)
        monkeypatch.setattr(ai_worker.Image, "open", lambda path: None)
        monkeypatch.setattr(ai_worker.pytesseract, "image_to_string", lambda image: "ACME SUPPLY INV-1001")
        monkeypatch.setattr(ai_worker, "normalize_vendor_name", lambda name: ("ACME SUPPLY", True))
        monkeypatch.setattr(ai_worker, "get_rules_for_vendor", lambda name: "")
        monkeypatch.setattr(ai_worker, "get_global_field_aliases", lambda: "")
        monkeypatch.setattr(ai_worker, "apply_invoice_number_rules", lambda data: None)
        monkeypatch.setattr(ai_worker, "write_log", lambda *args, **kwargs: None)

        ai_worker.scan_directories()
        return history

    return _run


def test_a_clean_invoice_leaves_the_history_it_should(pipeline_run):
    history = pipeline_run()

    assert [(state, actor) for _, state, actor in history] == [
        ("ai_queue", "00_ingestion_watcher"),
        ("sql_queue", "01_ai_extraction_worker"),
    ]


def test_the_whole_history_is_one_invoice(pipeline_run):
    """Plan step 3.1: one id per invoice. The history has to agree."""
    history = pipeline_run()

    assert len({batch_id for batch_id, _, _ in history}) == 1
    assert history[0][0].startswith("4601.")


def test_a_document_the_ai_cannot_place_is_recorded_as_going_to_review(pipeline_run):
    history = pipeline_run(document_type="Unknown")

    assert [(state, actor) for _, state, actor in history] == [
        ("ai_queue", "00_ingestion_watcher"),
        ("action_needed", "01_ai_extraction_worker"),
    ]


def test_a_statement_is_extracted_like_any_other_type(pipeline_run):
    """5.3a: every type flows through the same queues."""
    history = pipeline_run(document_type="Statement")

    assert history[-1][1] == "sql_queue"


def test_every_worker_signs_its_own_moves(pipeline_run):
    history = pipeline_run()

    assert all(actor for _, _, actor in history), "a move with no name is not an audit trail"
