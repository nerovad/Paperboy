"""A folder with no payload is reported once, then failed where a person can
see it. Found 2026-09-24.

The SQL worker printed "Skipping ... no payload" for a half-built CV62744
folder every five seconds for a day, and would have done so for ever. A
folder without a payload is now not "still being written" -- the AI worker
places folders whole, and the review screens write the payload before they
move one -- so it is reported once, and after INCOMPLETE_BATCH_SECONDS it goes
to the failed queue with a note, recorded on its row.
"""
import os
import time

import pytest


@pytest.fixture
def sql_worker(import_worker):
    return import_worker("02_sql_worker")


def test_a_folder_with_no_payload_is_reported_once_and_left_alone(sql_worker, queue_tree, capsys):
    folder = queue_tree.add_invoice("AIM_SQL_QUEUE_DIR", "INV-1")

    for _ in range(3):
        sql_worker.run_sql_worker()

    out = capsys.readouterr().out
    assert out.count("INV-1 has no *_READY_FOR_SQL.json payload") == 1
    assert os.path.isdir(folder)


def test_a_folder_still_incomplete_after_the_wait_is_failed_with_a_note(sql_worker, queue_tree, monkeypatch):
    folder = queue_tree.add_invoice("AIM_SQL_QUEUE_DIR", "INV-2")
    long_ago = time.time() - sql_worker.INCOMPLETE_BATCH_SECONDS - 1
    os.utime(folder, (long_ago, long_ago))
    recorded = []
    monkeypatch.setattr(sql_worker, "record_state",
                        lambda batch_id, state, actor, note=None, **kwargs: recorded.append((batch_id, state, note)))

    sql_worker.run_sql_worker()

    failed = os.path.join(queue_tree.queue("AIM_SQL_FAILED_DIR"), "INV-2")
    assert not os.path.exists(folder)
    assert sorted(os.listdir(failed)) == ["INV-2.pdf", "INV-2.ticket"], "the PDF travels with its note"
    with open(os.path.join(failed, "INV-2.ticket"), encoding="utf-8") as handle:
        assert "NO SQL PAYLOAD" in handle.read()
    assert recorded == [("INV-2", "sql_failed", "no *_READY_FOR_SQL.json payload after 10 minutes")]


def test_a_fresh_folder_is_given_time(sql_worker, queue_tree, monkeypatch):
    """Nothing is failed on sight: a folder a person is moving right now is not a leftover."""
    folder = queue_tree.add_invoice("AIM_SQL_QUEUE_DIR", "INV-3")
    monkeypatch.setattr(sql_worker, "record_state", lambda *args, **kwargs: pytest.fail("nothing to record yet"))

    sql_worker.run_sql_worker()

    assert os.path.isdir(folder)
    assert os.listdir(queue_tree.queue("AIM_SQL_FAILED_DIR")) == []
