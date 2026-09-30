"""A batch is cut into the invoices its manifest names, each a row of its own."""
import json

import fitz
import pytest

PARENT = "4601.20260924_090000.Batch-[AB12]"
# Shaped exactly as Aim::SplitPlan#manifest writes it: pages are integers.
MANIFEST = {"invoices": [{"vendor_name": "ACME", "invoice_number": "INV-1", "pages": [1, 2]},
                         {"vendor_name": "ACME", "invoice_number": "INV-2", "pages": [3]}]}


@pytest.fixture
def worker(v2, settings, fake_db):
    """A worker that does exactly one job per call: the split, not the
    extractions of the children it makes (those need the models)."""
    intake = v2("intake").Intake(settings, fake_db, stable=lambda p: True)
    real = v2("worker").Worker(settings, fake_db, name="test-worker", intake=intake)

    class OneJob:
        def run_once(self):
            job = fake_db.claim_next("test-worker", 900)
            assert job is not None, "nothing to do"
            real.dispatch(job)
            return 1

    return OneJob()


def parent_row(fake_db, pdf_maker, settings, manifest=MANIFEST):
    pdf_maker(settings.pdf_path(PARENT), pages=3)
    return fake_db.insert_invoice(PARENT, "needs_split", "split", {
        "budget_unit": "4601", "submitter": "Jane Doe", "assigned_to": "Jane Doe",
        "assignment_source": "folder", "source_filename": "Batch.pdf", "manifest": json.dumps(manifest),
    })


def pages_in(path):
    with fitz.open(path) as doc:
        return len(doc)


def test_every_invoice_becomes_a_child_row_with_its_pages(worker, fake_db, pdf_maker, settings):
    parent_id = parent_row(fake_db, pdf_maker, settings)

    assert worker.run_once() == 1

    children = sorted((r for r in fake_db.rows.values() if r.get("parent_id") == parent_id), key=lambda r: r["batch_id"])
    assert [c["batch_id"] for c in children] == [f"{PARENT}_SPLIT_1", f"{PARENT}_SPLIT_2"]
    assert pages_in(settings.pdf_path(children[0]["batch_id"])) == 2
    assert pages_in(settings.pdf_path(children[1]["batch_id"])) == 1
    for child in children:
        assert child["state"] == "received"
        assert child["command"] == "extract"
        assert child["split_check"] is False
        assert (child["budget_unit"], child["submitter"], child["assigned_to"]) == ("4601", "Jane Doe", "Jane Doe")
        assert child["source_filename"] == "Batch.pdf"
    assert children[0]["invoice_number"] == "INV-1", "what the manifest said starts the review"


def test_the_parent_ends_as_split_naming_its_children(worker, fake_db, pdf_maker, settings):
    parent_id = parent_row(fake_db, pdf_maker, settings)

    worker.run_once()

    parent = fake_db.get(parent_id)
    assert parent["state"] == "split"
    assert parent["command"] is None
    last = [e for e in fake_db.events if e["invoice_id"] == parent_id][-1]
    assert last["to_state"] == "split"
    assert f"{PARENT}_SPLIT_1" in last["note"] and f"{PARENT}_SPLIT_2" in last["note"]


def test_the_children_are_extracted_next_oldest_first(worker, fake_db, pdf_maker, settings):
    parent_row(fake_db, pdf_maker, settings)
    worker.run_once()

    claimed = fake_db.claim_next("another-worker", 60)

    assert claimed["batch_id"] == f"{PARENT}_SPLIT_1"


def test_a_manifest_with_one_invoice_is_a_failure_not_a_split(worker, fake_db, pdf_maker, settings):
    parent_id = parent_row(fake_db, pdf_maker, settings,
                           manifest={"invoices": [{"invoice_number": "INV-1", "pages": [1, 2, 3]}]})

    worker.run_once()

    parent = fake_db.get(parent_id)
    assert parent["state"] == "failed"
    assert parent["review_reason"] == "split_error"
    assert parent["command"] is None
    assert "at least two invoices" in parent["review_note"]
    assert len(fake_db.rows) == 1, "no children were made"


def test_a_pdf_missing_from_the_store_is_a_split_error_not_an_export_error(worker, fake_db, settings, pdf_maker):
    parent_id = parent_row(fake_db, pdf_maker, settings)
    import os
    os.remove(settings.pdf_path(PARENT))

    worker.run_once()

    parent = fake_db.get(parent_id)
    assert parent["state"] == "failed"
    assert parent["review_reason"] == "split_error"


@pytest.mark.parametrize("pages", ["3", "1-3", ["3-5"], [], [0], [1.5], [True], None])
def test_pages_that_are_not_page_numbers_fail_the_split_rather_than_being_dropped(
        worker, fake_db, pdf_maker, settings, pages):
    """Paperboy parses what people type; the worker never guesses at a string."""
    manifest = {"invoices": [{"invoice_number": "INV-1", "pages": [1, 2]},
                             {"invoice_number": "INV-2", "pages": pages}]}
    parent_id = parent_row(fake_db, pdf_maker, settings, manifest=manifest)

    worker.run_once()

    parent = fake_db.get(parent_id)
    assert parent["state"] == "failed"
    assert parent["review_reason"] == "split_error"
    assert "invoice 2" in parent["review_note"]
    assert len(fake_db.rows) == 1, "no children were made"


def test_pages_are_cut_in_page_order_whatever_order_the_manifest_lists(worker, fake_db, pdf_maker, settings):
    manifest = {"invoices": [{"invoice_number": "INV-1", "pages": [3, 1, 1]},
                             {"invoice_number": "INV-2", "pages": [2]}]}
    parent_id = parent_row(fake_db, pdf_maker, settings, manifest=manifest)

    worker.run_once()

    first = next(r for r in fake_db.rows.values() if r["batch_id"] == f"{PARENT}_SPLIT_1")
    assert first["page_count"] == 2
    assert fake_db.get(parent_id)["state"] == "split"
