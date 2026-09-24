"""A file dropped in the watch tree becomes one row and one stored PDF.

    <BU>/<Name>/        that person's queue       (the default)
    <BU>/SHARED/        the BU's shared queue
    <BU>/<loose file>   ignored -- each BU folder carries a README
"""
import os
import re

import fitz
import pytest
from PIL import Image


@pytest.fixture
def intake(v2, settings, fake_db):
    return v2("intake").Intake(settings, fake_db, stable=lambda path: True)


def drop(settings, pdf_maker, *parts, pages=1):
    path = os.path.join(settings.base_dir, *parts)
    return pdf_maker(path, pages=pages)


def only_row(fake_db):
    assert len(fake_db.rows) == 1, fake_db.rows
    return next(iter(fake_db.rows.values()))


def test_a_file_in_a_named_folder_becomes_that_persons_invoice(intake, settings, fake_db, pdf_maker):
    source = drop(settings, pdf_maker, "4601", "Jane Doe", "Scan 001.pdf", pages=2)

    [batch_id] = intake.scan()

    row = only_row(fake_db)
    assert re.match(r"^4601\.\d{8}_\d{6}\.Scan 001-\[[A-Z0-9]{4}\]$", batch_id)
    assert row["state"] == "received"
    assert row["command"] == "extract"
    assert row["budget_unit"] == "4601"
    assert row["submitter"] == "Jane Doe"
    assert row["assigned_to"] == "Jane Doe"
    assert row["assignment_source"] == "folder"
    assert row["source_filename"] == "Scan 001.pdf"
    assert row["source_path"] == source
    assert re.match(r"^[0-9a-f]{64}$", row["content_hash"])
    assert row["page_count"] == 2
    assert row["split_check"] is True
    assert os.path.isfile(settings.pdf_path(batch_id)), "the PDF lands in the store under the batch id"
    assert not os.path.exists(source), "the original is gone once the row exists"
    assert fake_db.events == [{"invoice_id": row["id"], "action": "transition", "from_state": None,
                               "to_state": "received", "actor": "aim_worker", "note": "received from Scan 001.pdf"}]


def test_a_file_in_shared_belongs_to_the_bu(intake, settings, fake_db, pdf_maker):
    drop(settings, pdf_maker, "4601", "SHARED", "Scan 002.pdf")

    intake.scan()

    row = only_row(fake_db)
    assert row["assigned_to"] is None
    assert row["assignment_source"] is None
    assert row["submitter"] == "SHARED"


def test_a_loose_file_at_the_bu_root_is_left_alone(intake, settings, fake_db, pdf_maker):
    loose = drop(settings, pdf_maker, "4601", "Scan 003.pdf")

    assert intake.scan() == []
    assert fake_db.rows == {}
    assert os.path.exists(loose)


def test_every_bu_folder_gets_the_readme_and_it_is_never_renamed(intake, settings, fake_db, pdf_maker, v2):
    for bu in ("4601", "4703"):
        os.makedirs(os.path.join(settings.base_dir, bu), exist_ok=True)
    os.makedirs(os.path.join(settings.base_dir, "_Archive"), exist_ok=True)
    readme_name = v2("intake").BU_README_NAME

    intake.scan()
    intake.scan()

    for bu in ("4601", "4703"):
        assert os.path.isfile(os.path.join(settings.base_dir, bu, readme_name))
        assert not os.path.exists(os.path.join(settings.base_dir, bu, f"UNSUPPORTED_FILETYPE_{readme_name}"))
    assert not os.path.exists(os.path.join(settings.base_dir, "_Archive", readme_name))


def test_an_unsupported_file_in_a_person_folder_is_marked_not_taken(intake, settings, fake_db):
    folder = os.path.join(settings.base_dir, "4601", "Jane Doe")
    os.makedirs(folder)
    with open(os.path.join(folder, "letter.docx"), "wb") as handle:
        handle.write(b"word")

    intake.scan()

    assert fake_db.rows == {}
    assert os.path.exists(os.path.join(folder, "UNSUPPORTED_FILETYPE_letter.docx"))


def test_an_image_is_taken_in_as_a_pdf(intake, settings, fake_db):
    folder = os.path.join(settings.base_dir, "4601", "Jane Doe")
    os.makedirs(folder)
    Image.new("RGB", (40, 60), "white").save(os.path.join(folder, "photo.png"))

    [batch_id] = intake.scan()

    row = only_row(fake_db)
    assert row["source_filename"] == "photo.png"
    assert row["page_count"] == 1
    with fitz.open(settings.pdf_path(batch_id)) as doc:
        assert len(doc) == 1


def test_a_file_windows_would_not_release_is_not_taken_twice(intake, settings, fake_db, pdf_maker, monkeypatch, v2):
    source = drop(settings, pdf_maker, "4601", "Jane Doe", "Scan 004.pdf")
    real_remove = os.remove

    def refuse_the_source(path):
        if path == source:
            raise PermissionError(13, "Access is denied")
        real_remove(path)

    monkeypatch.setattr(v2("intake").os, "remove", refuse_the_source)

    intake.scan()
    assert os.path.exists(source), "the original could not be removed"
    intake.scan()

    assert len(fake_db.rows) == 1, "the same file, still there, is not a second invoice"
