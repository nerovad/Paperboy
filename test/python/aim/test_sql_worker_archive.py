"""A batch that could not be archived must survive.

`archive_batch` swallows its own errors and reports the outcome as a boolean.
Both callers in the SQL worker ignored it and called `shutil.rmtree` anyway,
so a share that was full, locked or briefly unreachable took the only copy of
the invoice with it. Plan step 1.4.
"""
import json
import os

import pytest


@pytest.fixture
def sql_worker(import_worker):
    """02_sql_worker imported against the fake environment."""
    return import_worker("02_sql_worker")


@pytest.fixture
def queued_batch(queue_tree):
    """One batch in the SQL queue, with a payload the worker will accept."""
    folder = queue_tree.add_invoice("AIM_SQL_QUEUE_DIR", "INV-1", pdf=True)
    payload = {"BU": "4641", "Submitter": "Test User", "VendorName": "AIRGAS USA, LLC",
               "InvoiceNumber": "INV-10", "InvoiceConcatID": "INV-1"}
    with open(os.path.join(folder, "INV-1_READY_FOR_SQL.json"), "w", encoding="utf-8") as handle:
        json.dump(payload, handle)
    return folder


@pytest.fixture
def inserts_cleanly(sql_worker, monkeypatch):
    """SQL accepts everything; the XML generator does nothing."""
    monkeypatch.setattr(sql_worker, "insert_sql_record", lambda section, payload: None)
    monkeypatch.setattr(sql_worker, "generate_laserfiche_xml",
                        lambda *args, **kwargs: None)


def failed_dir(name):
    return os.path.join(os.environ["AIM_SQL_FAILED_DIR"], name)


def test_a_failed_archive_leaves_the_batch_alone(sql_worker, queued_batch,
                                                 inserts_cleanly, monkeypatch):
    monkeypatch.setattr(sql_worker, "archive_batch", lambda *args: False)

    sql_worker.run_sql_worker()

    assert not os.path.isdir(queued_batch), "the batch should have moved, not stayed"
    assert os.path.isdir(failed_dir("INV-1")), "a failed archive belongs in the failed queue"
    assert os.path.exists(os.path.join(failed_dir("INV-1"), "INV-1_READY_FOR_SQL.json"))
    assert os.path.exists(os.path.join(failed_dir("INV-1"), "INV-1.pdf")), (
        "the PDF must survive; it is the invoice"
    )


def test_an_archive_that_raises_is_the_same(sql_worker, queued_batch,
                                            inserts_cleanly, monkeypatch):
    def explode(*args):
        raise OSError("share is read-only")

    monkeypatch.setattr(sql_worker, "archive_batch", explode)

    sql_worker.run_sql_worker()

    assert os.path.isdir(failed_dir("INV-1"))
    assert os.path.exists(os.path.join(failed_dir("INV-1"), "INV-1.pdf"))


def test_a_successful_archive_still_completes(sql_worker, queued_batch,
                                              inserts_cleanly, monkeypatch):
    archived = []
    monkeypatch.setattr(sql_worker, "archive_batch",
                        lambda *args: archived.append(args) or True)

    sql_worker.run_sql_worker()

    assert archived, "the batch should have been archived"
    assert not os.path.isdir(queued_batch), "a completed batch is removed from the queue"
    assert not os.path.isdir(failed_dir("INV-1")), "a good batch must not reach the failed queue"
    assert os.path.exists(
        os.path.join(os.environ["AIM_PROCESSED_DIR"], "INV-1.pdf")
    ), "the PDF moves to the processed folder"


def test_a_duplicate_whose_archive_failed_is_not_deleted(sql_worker, queued_batch,
                                                         inserts_cleanly, monkeypatch):
    """The duplicate-key path deletes too, and had the same hole."""
    import pyodbc

    def duplicate(section, payload):
        raise pyodbc.IntegrityError("23000", "[23000] Violation of UNIQUE KEY 2627")

    monkeypatch.setattr(sql_worker, "insert_sql_record", duplicate)
    monkeypatch.setattr(sql_worker, "archive_batch", lambda *args: False)

    sql_worker.run_sql_worker()

    assert os.path.isdir(failed_dir("INV-1")), (
        "an unarchived duplicate must be kept, not discarded"
    )
    assert os.path.exists(os.path.join(failed_dir("INV-1"), "INV-1.pdf"))
