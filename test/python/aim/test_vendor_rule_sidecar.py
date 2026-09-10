"""The vendor-rule sidecar must not look like a SQL payload.

The AI worker wrote it as "{processing_id}.json" into folders that already
hold "{processing_id}_READY_FOR_SQL.json", so whichever the filesystem listed
first was treated as the invoice's metadata. Plan step 1.2.
"""
import json
import os

import pytest


@pytest.fixture
def ai_worker(import_worker):
    """01_AI_Extraction_Worker imported against the fake environment."""
    return import_worker("01_AI_Extraction_Worker")


class FakeInvoice:
    def __init__(self, vendor_name=None, extracted_vendor_name=None):
        self.vendor_name = vendor_name
        self.extracted_vendor_name = extracted_vendor_name


def test_sidecar_is_written_under_the_vendor_rule_name(ai_worker, tmp_path, monkeypatch):
    monkeypatch.setattr(ai_worker, "get_rules_for_vendor", lambda name: "no dashes")
    folder = tmp_path / "INV-1"
    folder.mkdir()

    path = ai_worker.write_vendor_rule_sidecar(
        str(folder), "INV-1", FakeInvoice(vendor_name="AIRGAS USA, LLC")
    )

    assert os.path.basename(path) == "INV-1_VENDOR_RULE.json"
    assert not (folder / "INV-1.json").exists(), (
        "the sidecar must not be written under the payload's name"
    )
    with open(path, encoding="utf-8") as handle:
        written = json.load(handle)
    assert written["vendor_name"] == "AIRGAS USA, LLC"
    assert written["existing_vendor_rules"] == "no dashes"
    assert written["new_vendor_rule"] == ""


def test_sidecar_falls_back_to_the_extracted_name(ai_worker, tmp_path, monkeypatch):
    """An un-normalized vendor has no rules to look up, only a name."""
    monkeypatch.setattr(ai_worker, "get_rules_for_vendor", lambda name: "unexpected")
    folder = tmp_path / "INV-2"
    folder.mkdir()

    path = ai_worker.write_vendor_rule_sidecar(
        str(folder), "INV-2", FakeInvoice(extracted_vendor_name="AIRGAS USA LLC")
    )

    with open(path, encoding="utf-8") as handle:
        written = json.load(handle)
    assert written["vendor_name"] == "AIRGAS USA LLC"
    assert written["existing_vendor_rules"] == ""


def test_the_suffix_matches_what_rails_ignores(ai_worker):
    """Rails' Aim::InvoiceQueueSupport::VENDOR_RULE_SUFFIX is the same string."""
    assert ai_worker.VENDOR_RULE_SUFFIX == "_VENDOR_RULE.json"
