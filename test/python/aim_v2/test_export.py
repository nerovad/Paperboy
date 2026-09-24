"""Export: the billing row, the Laserfiche XML and the archive copy, all from
the row's columns -- the reviewer's corrections included."""
import datetime
import os
import xml.etree.ElementTree as ET

import pyodbc
import pytest

BATCH = "4601.20260924_090000.Scan 001-[AB12]"


@pytest.fixture
def exporting(v2, settings, fake_db, pdf_maker):
    """A worker whose billing insert is recorded rather than sent."""
    intake = v2("intake").Intake(settings, fake_db, stable=lambda p: True)
    worker_module = v2("worker")

    def _build(insert=None):
        inserted = []

        def record(settings_, payload):
            inserted.append(payload)
            if insert:
                insert(payload)

        worker = worker_module.Worker(settings, fake_db, name="test-worker", intake=intake, billing_insert=record)
        pdf_maker(settings.pdf_path(BATCH), pages=1)
        invoice_id = fake_db.insert_invoice(BATCH, "approved", "export", {
            "budget_unit": "4601", "submitter": "Jane Doe", "source_filename": "Scan 001.pdf",
            "vendor_name": "ACME SUPPLY", "invoice_number": "INV-1001", "invoice_total": "134.69",
            "invoice_date": datetime.date(2026, 6, 22), "order_number": "PO-7", "customer_number": "C-9",
            "subtotal": "125.00", "sales_tax": "9.69", "document_type": "Invoice",
        })
        return worker, invoice_id, inserted

    return _build


def fields_of(xml_path):
    root = ET.parse(xml_path).getroot()
    return {f.attrib["Name"]: f.text for f in root.iter("Field")}, root


def test_the_billing_row_carries_the_reviewed_values(exporting, fake_db):
    worker, invoice_id, inserted = exporting()

    assert worker.run_once() == 1

    # The export writes the approved values; the billing sync that ends the
    # cycle then brings the status up to Exported.
    payload = inserted[0]
    assert inserted[-1]["Status"] == "Exported"
    assert payload["VendorName"] == "ACME SUPPLY"
    assert payload["InvoiceNumber"] == "INV-1001"
    assert payload["InvoiceTotal"] == "134.69"
    assert payload["InvoiceDate"] == "2026-06-22"
    assert payload["Subtotal"] == "125.00"
    assert payload["SalesTax"] == "9.69"
    assert (payload["BU"], payload["Submitter"], payload["FileName"]) == ("4601", "Jane Doe", "Scan 001.pdf")
    assert payload["Status"] == "Approved"
    assert payload["BatchID"] == BATCH
    assert payload["InvoiceConcatID"] == BATCH


def test_laserfiche_gets_the_pdf_and_an_xml_written_from_the_row(exporting, fake_db, settings):
    worker, invoice_id, _ = exporting()

    worker.run_once()

    assert os.path.isfile(os.path.join(settings.processed_dir, f"{BATCH}.pdf"))
    fields, root = fields_of(os.path.join(settings.processed_dir, f"{BATCH}.xml"))
    assert root.find("Doc/DocFile").text == f"{BATCH}.pdf"
    assert root.find("Doc/TemplateName").text == "Invoice"
    assert root.find("Doc/FolderPath").text == r"\AIM\00 INBOX\4601"
    assert fields["Vendor Name"] == "ACME SUPPLY"
    assert fields["Invoice Number"] == "INV-1001"
    assert fields["Invoice Total"] == "134.69"
    assert fields["Invoice Date"] == "2026-06-22"
    assert fields["Processing ID"] == BATCH
    assert os.path.isfile(settings.xml_path(BATCH)), "the store keeps the XML too"


def test_a_copy_is_archived_under_bu_submitter_and_date(exporting, settings):
    worker, _, _ = exporting()

    worker.run_once()

    today = datetime.datetime.now().strftime("%Y-%m-%d")
    folder = os.path.join(settings.archive_dir, "4601", "Jane Doe", today, BATCH)
    assert sorted(os.listdir(folder)) == [f"{BATCH}.pdf", f"{BATCH}.xml"]


def test_the_row_ends_exported_with_the_time(exporting, fake_db):
    worker, invoice_id, _ = exporting()

    worker.run_once()

    row = fake_db.get(invoice_id)
    assert row["state"] == "exported"
    assert row["exported_at"] is not None
    assert row["command"] is None
    assert row["lease_owner"] is None
    assert [(e["from_state"], e["to_state"]) for e in fake_db.events] == [
        (None, "approved"), ("approved", "exporting"), ("exporting", "exported")]


def test_a_billing_row_that_already_exists_still_counts_as_exported(exporting, fake_db):
    def duplicate(payload):
        raise pyodbc.IntegrityError("23000", "[23000] Violation of UNIQUE KEY constraint (2627)")

    worker, invoice_id, _ = exporting(insert=duplicate)

    worker.run_once()

    row = fake_db.get(invoice_id)
    assert row["state"] == "exported"
    assert "duplicate billing key" in fake_db.events[-1]["note"]


def test_a_billing_failure_is_recorded_on_the_row(exporting, fake_db, settings):
    def refuse(payload):
        raise RuntimeError("login failed for GSAScanCenter")

    worker, invoice_id, _ = exporting(insert=refuse)

    worker.run_once()

    row = fake_db.get(invoice_id)
    assert row["state"] == "failed"
    assert row["review_reason"] == "export_error"
    assert "login failed" in row["review_note"]
    assert row["command"] is None
    assert not os.path.exists(os.path.join(settings.processed_dir, f"{BATCH}.pdf")), "nothing reached Laserfiche"
