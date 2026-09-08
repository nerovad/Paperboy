"""The SQL worker must know which file is the payload.

It took `json_files[0]` -- whichever .json the filesystem happened to list
first -- so a vendor-rule sidecar could be read as an invoice, and a folder
with no payload at all could be archived and deleted as though it had been
inserted. Plan step 1.3.
"""
import importlib
import json
import os

import pytest


@pytest.fixture
def sql_worker(fake_environment):
    """02_sql_worker imported against the fake environment."""
    return importlib.import_module("02_sql_worker")


def batch(folder, files):
    os.makedirs(folder, exist_ok=True)
    for name, body in files.items():
        with open(os.path.join(folder, name), "w", encoding="utf-8") as handle:
            json.dump(body, handle)
    return folder


def test_the_payload_is_found_by_name(sql_worker, tmp_path):
    folder = batch(str(tmp_path / "INV-1"), {
        "INV-1_VENDOR_RULE.json": {"new_vendor_rule": ""},
        "INV-1_READY_FOR_SQL.json": {"InvoiceNumber": "INV-10"},
        ".claim.json": {"email": "staff@example.com"},
    })

    assert sql_worker.find_payload(folder) == "INV-1_READY_FOR_SQL.json"


def test_a_folder_of_sidecars_has_no_payload(sql_worker, tmp_path):
    folder = batch(str(tmp_path / "INV-2"), {
        "INV-2_VENDOR_RULE.json": {"new_vendor_rule": ""},
        "INV-2_LEARN.json": {"extracted_name": "AIR GAS"},
    })

    assert sql_worker.find_payload(folder) is None


def test_a_sidecar_only_folder_is_skipped_not_deleted(sql_worker, queue_tree, monkeypatch):
    """The batch stays put. Nothing is inserted, archived or removed."""
    folder = queue_tree.add_invoice("AIM_SQL_QUEUE_DIR", "INV-3", pdf=True)
    with open(os.path.join(folder, "INV-3_VENDOR_RULE.json"), "w", encoding="utf-8") as handle:
        json.dump({"new_vendor_rule": ""}, handle)

    def refuse(*args, **kwargs):
        raise AssertionError("a folder with no payload must not reach SQL")

    monkeypatch.setattr(sql_worker, "insert_sql_record", refuse)
    monkeypatch.setattr(sql_worker, "archive_batch", refuse)

    sql_worker.run_sql_worker()

    assert os.path.isdir(folder), "the batch folder must survive"
    assert os.path.exists(os.path.join(folder, "INV-3_VENDOR_RULE.json"))


def test_the_suffix_is_the_shared_one(sql_worker, pipeline):
    """One name, defined once, matching Aim::InvoiceQueueSupport."""
    assert sql_worker.PAYLOAD_SUFFIX == pipeline.PAYLOAD_SUFFIX == "_READY_FOR_SQL.json"


def test_a_success_payload_is_written_under_the_payload_name(pipeline, queue_tree):
    """write_log routes a SUCCESS batch to the SQL queue as the payload."""
    pipeline.write_log("INV-4.pdf", "CPU Test", "SUCCESS", "", "4641", "Test User", "INV-4")

    folder = os.path.join(os.environ["AIM_SQL_QUEUE_DIR"], "INV-4")
    assert os.path.exists(os.path.join(folder, "INV-4_READY_FOR_SQL.json"))
    assert not os.path.exists(os.path.join(folder, "INV-4.json")), (
        "the SUCCESS payload must not use the old ambiguous name"
    )
