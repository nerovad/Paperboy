"""One invoice, one id, minted once. Plan step 3.1.

The watcher mints `{BU}.{timestamp}.{name}` and names the queue folder that,
but drops the PDF under whatever the submitter called it. The AI worker then
looked at the filename, failed to recognise it as an id, and minted a second
one -- so the id naming the AI queue folder and the id naming every downstream
folder, ticket, payload and log row were different. Audit H3.

The fix is one id: the watcher renames the PDF to the batch id on spool and
records the submitter's filename in the job ticket, and the worker adopts the
ticket's `processing_id` instead of inventing its own.
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
    """The queue tree with the two directories the watcher writes to itself.

    `AIM_BASE_DIR` is the watch tree rather than a managed queue, and
    `AIM_SPOOL_STATE_DIR` is read by the watcher alone, so neither is created
    by `bootstrap`.
    """
    os.makedirs(os.environ["AIM_BASE_DIR"], exist_ok=True)
    os.makedirs(os.environ["AIM_SPOOL_STATE_DIR"], exist_ok=True)
    return queue_tree


def drop_in_watch_tree(watcher, name, bu="4601", submitter="Jane Doe", content=None):
    """Put a file where a submitter would, and return its path."""
    folder = os.path.join(watcher.BASE_DIR, bu, submitter)
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, name)
    with open(path, "wb") as handle:
        handle.write(content if content is not None else b"%PDF-1.4 test\n")
    return path


def spool_one(watcher, monkeypatch, name="Scan 001.pdf", content=None):
    """Run one watcher pass over a single dropped file and return its queue folder."""
    monkeypatch.setattr(watcher, "is_file_stable", lambda *args, **kwargs: True)
    drop_in_watch_tree(watcher, name, content=content)

    watcher.scan_and_spool()

    spooled = sorted(os.listdir(watcher.AI_QUEUE_DIR))
    assert len(spooled) == 1, f"expected one spooled batch, got {spooled}"
    return spooled[0], os.path.join(watcher.AI_QUEUE_DIR, spooled[0])


def read_ticket(folder):
    with open(os.path.join(folder, "job_ticket.json"), "r", encoding="utf-8") as handle:
        return json.load(handle)


def test_the_spooled_pdf_is_named_after_the_batch_id(watcher, watch_tree, monkeypatch):
    """The PDF carries the id, so nothing downstream has to guess it back."""
    batch_id, folder = spool_one(watcher, monkeypatch)

    pdfs = [name for name in os.listdir(folder) if name.lower().endswith(".pdf")]

    assert pdfs == [f"{batch_id}.pdf"], (
        f"the queue folder is named {batch_id} but holds {pdfs}"
    )


def test_the_job_ticket_id_matches_the_folder_and_the_pdf(watcher, watch_tree,
                                                          monkeypatch):
    """All three names an invoice has in the AI queue are the same name."""
    batch_id, folder = spool_one(watcher, monkeypatch)

    ticket = read_ticket(folder)

    assert ticket["processing_id"] == batch_id
    assert os.path.exists(os.path.join(folder, f"{ticket['processing_id']}.pdf"))


def test_the_ticket_keeps_the_submitters_filename(watcher, watch_tree, monkeypatch):
    """Renaming the PDF must not lose what the submitter called it.

    `write_log` records it as `FileName`, and a reviewer looking for the file
    they sent has nothing else to go on.
    """
    _, folder = spool_one(watcher, monkeypatch, name="April phone bill.pdf")

    assert read_ticket(folder)["original_filename"] == "April phone bill.pdf"


def test_a_converted_image_is_also_named_after_the_batch_id(watcher, watch_tree,
                                                            monkeypatch):
    """Images take the same path: the conversion writes the id, not the name."""
    from PIL import Image

    scan = os.path.join(os.environ["AIM_TEMP_DIR"], "source.png")
    Image.new("RGB", (4, 4), "white").save(scan)
    with open(scan, "rb") as handle:
        png = handle.read()

    batch_id, folder = spool_one(watcher, monkeypatch, name="Fax page.png",
                                 content=png)

    pdfs = [name for name in os.listdir(folder) if name.lower().endswith(".pdf")]

    assert pdfs == [f"{batch_id}.pdf"]
    assert read_ticket(folder)["original_filename"] == "Fax page.png"


def queue_job(queue_tree, batch_id, original_filename):
    """An AI-queue folder as the fixed watcher leaves it."""
    folder = queue_tree.add_invoice("AIM_AI_QUEUE_DIR", batch_id, pdf=True)
    ticket = {
        "processing_id": batch_id,
        "original_filename": original_filename,
        "bu_number": "4641",
        "submitter_name": "Test User",
        "timestamp": batch_id,
    }
    with open(os.path.join(folder, "job_ticket.json"), "w", encoding="utf-8") as handle:
        json.dump(ticket, handle)
    return folder


def test_the_worker_adopts_the_batch_id_from_the_ticket(ai_worker, queue_tree,
                                                        monkeypatch):
    """The id reaching processing is the watcher's, not a fresh one."""
    batch_id = "4641.20260915_101500.Scan 001"
    queue_job(queue_tree, batch_id, "Scan 001.pdf")

    handled = []
    monkeypatch.setattr(ai_worker, "process_cpu_hybrid",
                        lambda *args, **kwargs: handled.append(kwargs))

    ai_worker.scan_directories()

    assert handled, "the queued invoice should have been processed"
    assert handled[0].get("processing_id") == batch_id
    assert handled[0].get("original_filename") == "Scan 001.pdf"


class Reached(Exception):
    """Raised in place of opening the PDF, once the id has been settled."""


def stop_at_the_pdf(ai_worker, monkeypatch):
    """Let `process_cpu_hybrid` settle the id, then stop before it does work."""
    def refuse(*args, **kwargs):
        raise Reached

    monkeypatch.setattr(ai_worker.fitz, "open", refuse)


def test_a_supplied_batch_id_is_never_re_minted(ai_worker, queue_tree, monkeypatch):
    """Given an id, the worker must not consult the filename-based minter."""
    folder = queue_tree.add_invoice("AIM_AI_QUEUE_DIR", "batch", pdf=True)

    def refuse_to_mint(*args, **kwargs):
        raise AssertionError("the batch id is minted by the watcher, not here")

    monkeypatch.setattr(ai_worker, "generate_unique_id", refuse_to_mint)
    stop_at_the_pdf(ai_worker, monkeypatch)

    with pytest.raises(Reached):
        ai_worker.process_cpu_hybrid(
            os.path.join(folder, "batch.pdf"), "4601", "Jane Doe",
            processing_id="4601.20260915_101500.Scan 001"
        )


def test_a_batch_with_no_ticket_still_mints_one(ai_worker, queue_tree, monkeypatch):
    """The reprocess queue has no job ticket, so that path keeps the minter."""
    folder = queue_tree.add_invoice("AIM_REPROCESS_QUEUE_DIR", "orphan", pdf=True)

    minted = []
    monkeypatch.setattr(ai_worker, "generate_unique_id",
                        lambda bu, name: minted.append((bu, name)) or "minted-id")
    stop_at_the_pdf(ai_worker, monkeypatch)

    with pytest.raises(Reached):
        ai_worker.process_cpu_hybrid(
            os.path.join(folder, "orphan.pdf"), "Unknown", "Internal_Retrying"
        )

    assert minted == [("Unknown", "orphan.pdf")]


def test_a_crash_files_under_the_batch_id(ai_worker, queue_tree, monkeypatch):
    """The error queue is a downstream queue, so it gets the same id too."""
    batch_id = "4641.20260915_101500.Scan 001"
    queue_job(queue_tree, batch_id, "Scan 001.pdf")

    def crash(*args, **kwargs):
        raise RuntimeError("AI server disconnected")

    monkeypatch.setattr(ai_worker, "process_cpu_hybrid", crash)

    logged = []
    monkeypatch.setattr(ai_worker, "write_log",
                        lambda filename, *args, **kwargs: logged.append((filename, args)))

    ai_worker.scan_directories()

    assert sorted(os.listdir(ai_worker.ERROR_QUEUE_DIR)) == [f"ERROR_{batch_id}"]
    assert logged[0][0] == "Scan 001.pdf", (
        "the crash log should record the submitter's filename, not the batch id"
    )
    assert logged[0][1][5] == f"ERROR_{batch_id}"


def write_reprocess_batch(queue_tree, name, sidecar=None):
    """A reprocess-queue folder: a PDF, and the sidecar the retry path writes.

    The reprocess queue has no job ticket -- Rails and the batch splitter both
    put work here, and neither is the watcher -- so this is the one path that
    still mints its own id. Plan step 3.2.
    """
    folder = queue_tree.add_invoice("AIM_REPROCESS_QUEUE_DIR", name, pdf=False)
    with open(os.path.join(folder, f"{name}.pdf"), "wb") as handle:
        handle.write(b"%PDF-1.4 test\n")
    if sidecar is not None:
        with open(os.path.join(folder, f"{name}.json"), "w", encoding="utf-8") as handle:
            json.dump(sidecar, handle)
    return folder


def test_a_retry_sidecar_settles_the_bu_before_the_id_is_minted(ai_worker, queue_tree,
                                                                monkeypatch):
    """The minted id embeds the BU, so reading the sidecar afterwards is too late.

    Rails hands the reprocess queue `BU = "Unknown"` because it has no way to
    say otherwise; the sidecar beside the PDF is where the real one is. Reading
    it after the mint left the id stamped `Unknown` with the answer sitting in
    the next file along. Plan step 3.2.
    """
    folder = write_reprocess_batch(queue_tree, "INV-3_RETRY_1789",
                                   {"bu": "4601", "submitter": "Dana Reyes"})

    minted = []
    monkeypatch.setattr(ai_worker, "generate_unique_id",
                        lambda bu, name: minted.append(bu) or "minted-id")
    stop_at_the_pdf(ai_worker, monkeypatch)

    with pytest.raises(Reached):
        ai_worker.process_cpu_hybrid(
            os.path.join(folder, "INV-3_RETRY_1789.pdf"), "Unknown", "Internal_Retrying"
        )

    assert minted == ["4601"], (
        f"the id should be minted for BU 4601, not {minted}"
    )


def test_a_split_batch_keeps_its_parents_bu(ai_worker, queue_tree, monkeypatch):
    """`03_batch_splitter.py` writes the same sidecar, and lost the BU the same way."""
    folder = write_reprocess_batch(
        queue_tree, "4721.20260915_101500.Scan 001_SPLIT_INV-7",
        {"bu": "4721", "submitter": "Sam Rivera", "bypass_split": True}
    )

    minted = []
    monkeypatch.setattr(ai_worker, "generate_unique_id",
                        lambda bu, name: minted.append(bu) or "minted-id")
    stop_at_the_pdf(ai_worker, monkeypatch)

    with pytest.raises(Reached):
        ai_worker.process_cpu_hybrid(
            os.path.join(folder, "4721.20260915_101500.Scan 001_SPLIT_INV-7.pdf"),
            "Unknown", "Internal_Retrying"
        )

    assert minted == ["4721"]


def test_an_unreadable_sidecar_does_not_stop_the_batch(ai_worker, queue_tree,
                                                       monkeypatch):
    """A corrupt sidecar costs the BU, not the invoice."""
    folder = write_reprocess_batch(queue_tree, "INV-4_RETRY_1789")
    with open(os.path.join(folder, "INV-4_RETRY_1789.json"), "w", encoding="utf-8") as handle:
        handle.write("{not json")

    minted = []
    monkeypatch.setattr(ai_worker, "generate_unique_id",
                        lambda bu, name: minted.append(bu) or "minted-id")
    stop_at_the_pdf(ai_worker, monkeypatch)

    with pytest.raises(Reached):
        ai_worker.process_cpu_hybrid(
            os.path.join(folder, "INV-4_RETRY_1789.pdf"), "Unknown", "Internal_Retrying"
        )

    assert minted == ["Unknown"]
