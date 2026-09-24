"""A batch folder reaches its queue whole, or not at all. Found 2026-09-24.

The AI worker built a folder directly in the SQL queue -- XML first, then the
PDF, then the payload -- and Windows refused to move the PDF of CV62744 because
something had it open. The copy had landed, the payload never followed, and
the SQL worker skipped the half-built folder every five seconds for a day.
The same lock then made the worker file a crash against an invoice that had
routed fine, because removing the source folder was inside the try.

Now the folder is assembled under _TEMP and moved into its queue as one step,
the original PDF is let go of afterwards, and a source folder that lingers is
marked and retired later rather than reprocessed or reported as a crash.
"""
import json
import os

import pytest


@pytest.fixture
def ai_worker(import_worker):
    return import_worker("01_AI_Extraction_Worker")


def files_in(folder):
    return sorted(os.listdir(folder))


class FakeDoc:
    def __len__(self):
        return 1

    def close(self):
        pass


# ---------------------------------------------------------------------------
# The drop itself
# ---------------------------------------------------------------------------

def test_nothing_appears_in_the_queue_until_the_folder_is_complete(pipeline, queue_tree):
    source = queue_tree.add_invoice("AIM_AI_QUEUE_DIR", "INV-1")
    pdf = os.path.join(source, "INV-1.pdf")
    drop = pipeline.QueueDrop(queue_tree.queue("AIM_SQL_QUEUE_DIR"), "INV-1")

    with open(drop.path("INV-1.xml"), "w", encoding="utf-8") as handle:
        handle.write("<ImportSession/>")
    drop.take_pdf(pdf)
    assert os.listdir(queue_tree.queue("AIM_SQL_QUEUE_DIR")) == [], "nothing shows until it is whole"

    landed = drop.publish()

    assert files_in(landed) == ["INV-1.pdf", "INV-1.xml"]
    assert not os.path.exists(drop.staging)
    assert not os.path.exists(pdf), "the original PDF goes once the folder is placed"


def test_a_pdf_windows_will_not_release_still_arrives(pipeline, queue_tree, monkeypatch):
    """The CV62744 case: the copy lands, the original stays, nothing is half done."""
    source = queue_tree.add_invoice("AIM_REPROCESS_QUEUE_DIR", "INV-2")
    pdf = os.path.join(source, "INV-2.pdf")
    real_remove = os.remove

    def refuse_the_source(path):
        if path == pdf:
            raise PermissionError(13, "Access is denied")
        real_remove(path)

    monkeypatch.setattr(pipeline.os, "remove", refuse_the_source)
    drop = pipeline.QueueDrop(queue_tree.queue("AIM_SQL_QUEUE_DIR"), "INV-2")
    drop.take_pdf(pdf)

    landed = drop.publish()

    assert files_in(landed) == ["INV-2.pdf"]
    assert os.path.exists(pdf), "the original is left for a later pass, not fought over"


def test_write_log_puts_the_payload_where_the_folder_is_assembled(pipeline, queue_tree):
    drop = pipeline.QueueDrop(queue_tree.queue("AIM_SQL_QUEUE_DIR"), "INV-3")

    pipeline.write_log("INV-3.pdf", "CPU Test", "SUCCESS", "", "4601", "Jane Doe", "INV-3",
                       payload_dir=drop.staging)

    assert os.path.exists(drop.path("INV-3_READY_FOR_SQL.json"))
    assert os.listdir(queue_tree.queue("AIM_SQL_QUEUE_DIR")) == []


# ---------------------------------------------------------------------------
# The worker's real routing, with the models scripted
# ---------------------------------------------------------------------------

def route(ai_worker, queue_tree, monkeypatch, batch_id):
    def chat(model, messages, format, options):
        if "images" in messages[0]:
            return {"message": {"content": json.dumps({
                "document_type": "Invoice", "extracted_vendor_name": "ACME SUPPLY",
                "invoice_date": "2026-09-21", "invoice_number": "INV-1001",
                "invoice_number_label": "Invoice #", "invoice_total": "100.00",
                "order_number": "", "customer_number": "", "handwritten_financial_fields": [],
            })}}
        return {"message": {"content": json.dumps({
            "contains_multiple_invoices": False, "is_high_confidence": True,
            "document_type": "Invoice", "extracted_vendor_name": "ACME SUPPLY",
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
    monkeypatch.setattr(ai_worker, "record_state", lambda *args, **kwargs: True)

    folder = queue_tree.add_invoice("AIM_AI_QUEUE_DIR", batch_id)
    ai_worker.process_cpu_hybrid(os.path.join(folder, f"{batch_id}.pdf"), "4601", "Jane Doe",
                                 processing_id=batch_id, original_filename="scan.pdf")


def test_a_routed_invoice_arrives_with_its_payload(ai_worker, pipeline, queue_tree, monkeypatch):
    """write_log is the real one here: the payload it writes lands in the folder."""
    batch_id = "4601.20260924_090000.scan-[AB12]"

    route(ai_worker, queue_tree, monkeypatch, batch_id)

    landed = os.path.join(queue_tree.queue("AIM_SQL_QUEUE_DIR"), batch_id)
    assert files_in(landed) == [f"{batch_id}.pdf", f"{batch_id}.xml", f"{batch_id}_READY_FOR_SQL.json"]
    staging = os.path.join(queue_tree.queue("AIM_TEMP_DIR"), pipeline.STAGING_DIR_NAME)
    assert os.listdir(staging) == [], "nothing is left behind where the folder was assembled"


# ---------------------------------------------------------------------------
# The queue loops: a source folder that lingers
# ---------------------------------------------------------------------------

def refuse_once(monkeypatch, module):
    """shutil.rmtree fails the first time only, as a briefly locked file does."""
    real_rmtree = module.shutil.rmtree

    def refuse(path, *args, **kwargs):
        monkeypatch.setattr(module.shutil, "rmtree", real_rmtree)
        raise PermissionError(13, "Access is denied")

    monkeypatch.setattr(module.shutil, "rmtree", refuse)


def test_an_ai_queue_folder_that_will_not_go_is_not_a_crash(ai_worker, queue_tree, monkeypatch):
    folder = queue_tree.add_invoice("AIM_AI_QUEUE_DIR", "INV-5")
    with open(os.path.join(folder, "job_ticket.json"), "w", encoding="utf-8") as handle:
        json.dump({"bu_number": "4601", "submitter_name": "Jane Doe", "timestamp": "1", "processing_id": "INV-5"}, handle)
    calls, recorded = [], []
    monkeypatch.setattr(ai_worker, "process_cpu_hybrid", lambda *args, **kwargs: calls.append(args))
    monkeypatch.setattr(ai_worker, "record_state", lambda *args, **kwargs: recorded.append(args))
    monkeypatch.setattr(ai_worker, "write_log", lambda *args, **kwargs: None)
    refuse_once(monkeypatch, ai_worker)

    ai_worker.scan_directories()

    assert len(calls) == 1
    assert os.path.exists(os.path.join(folder, ai_worker.ROUTED_MARKER))
    assert os.listdir(queue_tree.queue("AIM_ERROR_QUEUE_DIR")) == [], "a lingering folder is not a crash"
    assert recorded == [], "nor an error of the invoice, which routed fine"

    ai_worker.scan_directories()

    assert len(calls) == 1, "the leftover is not processed as a second invoice"
    assert not os.path.exists(folder)


def test_a_reprocess_folder_that_will_not_go_is_retired_later_not_reprocessed(ai_worker, queue_tree, monkeypatch):
    folder = queue_tree.add_invoice("AIM_REPROCESS_QUEUE_DIR", "INV-6")
    calls = []
    monkeypatch.setattr(ai_worker, "process_cpu_hybrid", lambda *args, **kwargs: calls.append(args))
    monkeypatch.setattr(ai_worker, "is_file_stable", lambda *args, **kwargs: True)
    refuse_once(monkeypatch, ai_worker)

    ai_worker.scan_directories()

    assert len(calls) == 1
    assert os.path.exists(os.path.join(folder, ai_worker.ROUTED_MARKER))
    assert not os.path.exists(os.path.join(folder, ai_worker.REPROCESS_ERROR_MARKER))
    assert os.listdir(queue_tree.queue("AIM_ERROR_QUEUE_DIR")) == []

    ai_worker.scan_directories()

    assert len(calls) == 1
    assert not os.path.exists(folder)
