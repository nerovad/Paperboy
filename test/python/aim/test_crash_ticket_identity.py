"""A crash must be filed against the invoice that crashed.

The handler read `folder_name`, which is not set in that loop -- it held
whatever the *queue-building* loop saw last. With several invoices queued, an
error marker was written into a folder that had nothing to do with the
failure, and the folder that did fail was cleaned up unmarked. Plan step 1.6.
"""
import json
import os

import pytest


@pytest.fixture
def ai_worker(import_worker):
    return import_worker("01_AI_Extraction_Worker")


def queue_job(queue_tree, folder_name, processing_id, is_urgent=False):
    """An AI-queue folder as the watcher leaves it: a PDF and a job ticket."""
    folder = queue_tree.add_invoice("AIM_AI_QUEUE_DIR", folder_name, pdf=True)
    ticket = {
        "bu_number": "4641",
        "submitter_name": "Test User",
        "is_urgent": is_urgent,
        "timestamp": processing_id,
        "processing_id": processing_id,
    }
    with open(os.path.join(folder, "job_ticket.json"), "w", encoding="utf-8") as handle:
        json.dump(ticket, handle)
    return folder


def test_a_crash_is_marked_against_the_folder_that_crashed(ai_worker, queue_tree,
                                                           monkeypatch):
    """The crashing invoice is deliberately not the last one the build loop saw.

    Queues are built in sorted order and processed urgent-first, so INV-1
    crashes while the leaked `folder_name` still holds INV-2. Reading the leak
    files the error against the wrong invoice; reading the job does not.
    """
    queue_job(queue_tree, "INV-1", "INV-1", is_urgent=True)
    queue_job(queue_tree, "INV-2", "INV-2")

    def crash_on_first(pdf_path, *args, **kwargs):
        if "INV-1" in pdf_path:
            raise RuntimeError("AI server disconnected")

    monkeypatch.setattr(ai_worker, "process_cpu_hybrid", crash_on_first)
    # The PDF failing to move is the one path that files a queue-folder marker.
    monkeypatch.setattr(ai_worker.shutil, "move", _refuse_to_move)
    monkeypatch.setattr(ai_worker, "write_log", lambda *args, **kwargs: None)

    marked = []
    monkeypatch.setattr(
        ai_worker, "mark_ai_queue_error",
        lambda folder_path, folder_name, *args, **kwargs: marked.append(folder_name)
    )

    ai_worker.scan_directories()

    assert marked == ["INV-1"], (
        f"the crash belongs to INV-1, but was filed against {marked}"
    )


def test_the_job_carries_its_own_folder_name(ai_worker, queue_tree, monkeypatch):
    """Nothing in the processing loop should depend on a leaked loop variable."""
    queue_job(queue_tree, "INV-3", "INV-3")

    seen = []
    monkeypatch.setattr(ai_worker, "process_cpu_hybrid",
                        lambda *args, **kwargs: seen.append(args))

    ai_worker.scan_directories()

    assert seen, "the queued invoice should have been processed"


def _refuse_to_move(*args, **kwargs):
    raise OSError("share is read-only")
