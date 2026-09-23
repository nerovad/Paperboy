"""A split batch keeps its owner, and ends as `split`. Plan step 5.7c.

Two faults found reading the splitter on 2026-09-23. It took the submitter
from the batch id's third part -- which is the file name -- so every split
invoice carried the wrong submitter and no owner. And it deleted the batch
folder without recording what became of it, so the batch's row sat in
`ready_to_split` for ever.

Now the AI worker writes the BU, submitter and owner into the manifest, the
splitter hands them to every piece, and the batch is recorded as `split`,
naming the pieces.
"""
import json
import os

import fitz
import pytest


@pytest.fixture
def splitter(import_worker):
    return import_worker("03_batch_splitter")


@pytest.fixture
def ai_worker(import_worker):
    return import_worker("01_AI_Extraction_Worker")


def make_pdf(path, pages):
    doc = fitz.open()
    for number in range(1, pages + 1):
        page = doc.new_page()
        page.insert_text((72, 72), f"page {number}")
    doc.save(path)
    doc.close()


def approved_batch(queue_tree, batch_id, manifest, pages=3):
    folder = os.path.join(queue_tree.queue("AIM_READY_TO_SPLIT_DIR"), batch_id)
    os.makedirs(folder)
    make_pdf(os.path.join(folder, f"{batch_id}.pdf"), pages)
    with open(os.path.join(folder, f"{batch_id}_MANIFEST.json"), "w", encoding="utf-8") as handle:
        json.dump(manifest, handle)
    return folder


def run(splitter, monkeypatch):
    recorded = []
    monkeypatch.setattr(splitter, "record_state",
                        lambda batch_id, state, actor, note=None, **kwargs: recorded.append((batch_id, state, note)))
    splitter.run_batch_splitter()
    return recorded


BATCH = "4601.20260923_120000.Scan 001"


def test_every_piece_carries_the_batchs_owner(splitter, queue_tree, monkeypatch):
    approved_batch(queue_tree, BATCH, {
        "bu": "4601", "submitter": "Jane Doe", "owner": "Jane Doe",
        "invoices": [
            {"vendor_name": "ACME", "invoice_number": "INV-1", "pages": [1, 2]},
            {"vendor_name": "ACME", "invoice_number": "INV-2", "pages": [3]},
        ],
    })

    run(splitter, monkeypatch)

    reprocess = queue_tree.queue("AIM_REPROCESS_QUEUE_DIR")
    pieces = sorted(os.listdir(reprocess))
    assert pieces == [f"{BATCH}_SPLIT_INV-1", f"{BATCH}_SPLIT_INV-2"]
    for piece in pieces:
        with open(os.path.join(reprocess, piece, f"{piece}.json"), encoding="utf-8") as handle:
            sidecar = json.load(handle)
        assert sidecar == {"bu": "4601", "submitter": "Jane Doe", "owner": "Jane Doe", "bypass_split": True}


def test_the_submitter_is_no_longer_guessed_from_the_file_name(splitter, queue_tree, monkeypatch):
    """A manifest from before 5.7c has no submitter; the file name is not one."""
    approved_batch(queue_tree, BATCH, {"invoices": [{"invoice_number": "INV-1", "pages": [1, 2, 3]}]})

    run(splitter, monkeypatch)

    piece = f"{BATCH}_SPLIT_INV-1"
    with open(os.path.join(queue_tree.queue("AIM_REPROCESS_QUEUE_DIR"), piece, f"{piece}.json"),
              encoding="utf-8") as handle:
        sidecar = json.load(handle)
    assert sidecar["bu"] == "4601"
    assert sidecar["submitter"] == "Unknown"
    assert sidecar["submitter"] != "Scan 001"


def test_the_pieces_hold_the_pages_asked_for(splitter, queue_tree, monkeypatch):
    approved_batch(queue_tree, BATCH, {
        "invoices": [{"invoice_number": "INV-1", "pages": [1, 3]}, {"invoice_number": "INV-2", "pages": [2]}],
    })

    run(splitter, monkeypatch)

    reprocess = queue_tree.queue("AIM_REPROCESS_QUEUE_DIR")
    first = fitz.open(os.path.join(reprocess, f"{BATCH}_SPLIT_INV-1", f"{BATCH}_SPLIT_INV-1.pdf"))
    assert [page.get_text().strip() for page in first] == ["page 1", "page 3"]
    first.close()


def test_the_batch_is_recorded_as_split_naming_its_pieces(splitter, queue_tree, monkeypatch):
    folder = approved_batch(queue_tree, BATCH, {
        "invoices": [{"invoice_number": "INV-1", "pages": [1, 2]}, {"invoice_number": "INV-2", "pages": [3]}],
    })

    recorded = run(splitter, monkeypatch)

    assert not os.path.exists(folder)
    [(batch_id, state, note)] = recorded
    assert (batch_id, state) == (BATCH, "split")
    assert note.startswith("split into 2:")
    assert f"{BATCH}_SPLIT_INV-1" in note and f"{BATCH}_SPLIT_INV-2" in note


# ---------------------------------------------------------------------------
# The AI worker writes who the batch belongs to into the manifest
# ---------------------------------------------------------------------------

class FakeDoc:
    def __len__(self):
        return 3

    def close(self):
        pass


def test_the_manifest_carries_the_bu_submitter_and_owner(ai_worker, queue_tree, monkeypatch):
    def chat(model, messages, format, options):
        prompt = messages[0]["content"]
        if "Identify each distinct invoice" in prompt:
            return {"message": {"content": json.dumps({"invoices": [
                {"vendor_name": "ACME", "invoice_number": "INV-1", "pages": [1, 2]},
                {"vendor_name": "ACME", "invoice_number": "INV-2", "pages": [3]},
            ]})}}
        return {"message": {"content": json.dumps({
            "contains_multiple_invoices": True, "is_high_confidence": True,
            "document_type": "Invoice", "extracted_vendor_name": "ACME",
        })}}

    monkeypatch.setattr(ai_worker.ollama, "chat", chat)
    monkeypatch.setattr(ai_worker.fitz, "open", lambda path: FakeDoc())
    monkeypatch.setattr(ai_worker, "pdf_page_to_image", lambda *args, **kwargs: None)
    monkeypatch.setattr(ai_worker.Image, "open", lambda path: None)
    monkeypatch.setattr(ai_worker.pytesseract, "image_to_string", lambda image: "ACME INV-1 ... INV-2")
    monkeypatch.setattr(ai_worker, "write_log", lambda *args, **kwargs: None)
    monkeypatch.setattr(ai_worker, "record_state", lambda *args, **kwargs: True)

    folder = queue_tree.add_invoice("AIM_AI_QUEUE_DIR", BATCH)
    ai_worker.process_cpu_hybrid(os.path.join(folder, f"{BATCH}.pdf"), "4601", "Jane Doe",
                                 processing_id=BATCH, original_filename="Scan 001.pdf", owner="Jane Doe")

    manifest_path = os.path.join(queue_tree.queue("AIM_BATCH_SPLIT_DIR"), BATCH, f"{BATCH}_MANIFEST.json")
    with open(manifest_path, encoding="utf-8") as handle:
        manifest = json.load(handle)
    assert (manifest["bu"], manifest["submitter"], manifest["owner"]) == ("4601", "Jane Doe", "Jane Doe")
    assert [invoice["pages"] for invoice in manifest["invoices"]] == [[1, 2], [3]]
