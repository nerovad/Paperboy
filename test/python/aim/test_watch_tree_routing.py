"""Where a file is dropped says who owns it. Plan step 8b.0.

Agreed with Joshua 2026-09-23:

    <BU>/<Name>/        that person's queue       (the default)
    <BU>/SHARED/        the BU's shared queue
    <BU>/<loose file>   ignored -- each BU folder carries a README

and no HIGH PRIORITY folder, and no urgency. Before this, a file at the BU
root was ingested with its submitter recorded as "Unknown", and a README placed
there would have been renamed UNSUPPORTED_FILETYPE_ the first time the watcher
ran.
"""
import json
import os

import pytest


@pytest.fixture
def watcher(import_worker):
    return import_worker("00_Ingestion_Watcher")


@pytest.fixture
def watch_tree(queue_tree):
    os.makedirs(os.environ["AIM_BASE_DIR"], exist_ok=True)
    os.makedirs(os.environ["AIM_SPOOL_STATE_DIR"], exist_ok=True)
    return queue_tree


def drop(watcher, *path, content=b"%PDF-1.4 test\n"):
    full = os.path.join(watcher.BASE_DIR, *path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "wb") as handle:
        handle.write(content)
    return full


def spool(watcher, monkeypatch):
    """Run one watcher pass and return the job tickets it wrote."""
    monkeypatch.setattr(watcher, "is_file_stable", lambda *args, **kwargs: True)
    monkeypatch.setattr(watcher, "record_state", lambda *args, **kwargs: True)
    watcher.scan_and_spool()
    tickets = []
    for batch in sorted(os.listdir(watcher.AI_QUEUE_DIR)):
        with open(os.path.join(watcher.AI_QUEUE_DIR, batch, "job_ticket.json"), encoding="utf-8") as handle:
            tickets.append(json.load(handle))
    return tickets


# ---------------------------------------------------------------------------
# The rule itself
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("relative, expected", [
    ("4601/Jane Doe", {"bu_number": "4601", "owner": "Jane Doe", "queue": "person"}),
    ("4601/Jane Doe/scans", {"bu_number": "4601", "owner": "Jane Doe", "queue": "person"}),
    ("4601/SHARED", {"bu_number": "4601", "owner": None, "queue": "shared"}),
    ("4601/shared", {"bu_number": "4601", "owner": None, "queue": "shared"}),
    ("4601/SHARED/batch", {"bu_number": "4601", "owner": None, "queue": "shared"}),
])
def test_the_folder_decides_the_owner(watcher, watch_tree, relative, expected):
    assert watcher.route_for(relative.replace("/", os.sep)) == expected


@pytest.mark.parametrize("relative", [".", "", "4601"])
def test_the_watch_root_and_a_bu_root_belong_to_nobody(watcher, watch_tree, relative):
    assert watcher.route_for(relative) is None


def test_high_priority_is_just_a_name_now(watcher, watch_tree):
    route = watcher.route_for(os.path.join("4601", "HIGH PRIORITY"))

    assert route == {"bu_number": "4601", "owner": "HIGH PRIORITY", "queue": "person"}


# ---------------------------------------------------------------------------
# What the watcher does with them
# ---------------------------------------------------------------------------

def test_a_file_in_a_named_folder_goes_to_that_person(watcher, watch_tree, monkeypatch):
    drop(watcher, "4601", "Jane Doe", "Scan 001.pdf")

    [ticket] = spool(watcher, monkeypatch)

    assert ticket["bu_number"] == "4601"
    assert ticket["owner"] == "Jane Doe"
    assert ticket["queue"] == "person"
    assert ticket["assignment_source"] == "folder"
    assert ticket["submitter_name"] == "Jane Doe"


def test_a_file_in_shared_goes_to_the_shared_queue(watcher, watch_tree, monkeypatch):
    drop(watcher, "4601", "SHARED", "Scan 002.pdf")

    [ticket] = spool(watcher, monkeypatch)

    assert ticket["owner"] is None
    assert ticket["queue"] == "shared"
    assert ticket["submitter_name"] == "SHARED"


def test_a_loose_file_at_the_bu_root_is_left_alone(watcher, watch_tree, monkeypatch):
    loose = drop(watcher, "4601", "Scan 003.pdf")

    assert spool(watcher, monkeypatch) == []
    assert os.path.exists(loose), "a loose file is ignored, not moved or deleted"


def test_the_readme_at_the_bu_root_is_never_renamed(watcher, watch_tree, monkeypatch):
    drop(watcher, "4601", "Jane Doe", "Scan 004.pdf")
    notes = drop(watcher, "4601", "notes.txt", content=b"not an invoice")

    spool(watcher, monkeypatch)

    assert os.path.exists(notes), "the unsupported-file rename must not reach the BU root"
    assert not os.path.exists(os.path.join(watcher.BASE_DIR, "4601", "UNSUPPORTED_FILETYPE_notes.txt"))


def test_an_unsupported_file_in_a_person_folder_is_still_marked(watcher, watch_tree, monkeypatch):
    drop(watcher, "4601", "Jane Doe", "letter.docx", content=b"word")

    spool(watcher, monkeypatch)

    assert os.path.exists(os.path.join(watcher.BASE_DIR, "4601", "Jane Doe", "UNSUPPORTED_FILETYPE_letter.docx"))


def test_nothing_is_urgent_any_more(watcher, watch_tree, monkeypatch):
    drop(watcher, "4601", "HIGH PRIORITY", "Scan 005.pdf")

    [ticket] = spool(watcher, monkeypatch)

    assert "is_urgent" not in ticket


# ---------------------------------------------------------------------------
# The README
# ---------------------------------------------------------------------------

def test_every_bu_folder_gets_the_readme(watcher, watch_tree, monkeypatch):
    for bu in ("4601", "4703"):
        os.makedirs(os.path.join(watcher.BASE_DIR, bu), exist_ok=True)
    os.makedirs(os.path.join(watcher.BASE_DIR, "_Archive"), exist_ok=True)

    spool(watcher, monkeypatch)

    for bu in ("4601", "4703"):
        assert os.path.isfile(os.path.join(watcher.BASE_DIR, bu, watcher.BU_README_NAME))
    assert not os.path.exists(os.path.join(watcher.BASE_DIR, "_Archive", watcher.BU_README_NAME))


def test_an_edited_readme_is_kept(watcher, watch_tree, monkeypatch):
    readme = drop(watcher, "4601", watcher.BU_README_NAME, content=b"4601's own notes")

    spool(watcher, monkeypatch)

    with open(readme, "rb") as handle:
        assert handle.read() == b"4601's own notes"


def test_the_readme_ships_with_the_workers(watcher):
    assert os.path.isfile(watcher.BU_README_TEMPLATE)
    with open(watcher.BU_README_TEMPLATE, encoding="utf-8") as handle:
        text = handle.read()
    assert "SHARED" in text
    assert "ignored" in text
