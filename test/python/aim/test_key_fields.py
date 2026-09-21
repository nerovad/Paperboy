"""The key fields must reach storage as the vendor typed them.

`sanitize_data` rewrote "&" to "and" in the vendor name. 58 of the ~900
official vendors carry an ampersand, so "AT&T MOBILITY" was stored, keyed and
exported as "ATandT MOBILITY" -- and when a human corrected a vendor review in
Rails, the SQL row kept the real name while the regenerated XML did not. Two
records of the same invoice, disagreeing. Plan step 4.1, audit H5.
"""
import json
import os
import xml.etree.ElementTree as ET

import pytest

OFFICIAL_NAME = "AT&T MOBILITY"


@pytest.fixture
def invoice(pipeline):
    return pipeline.InvoiceData


def xml_fields(xml_path):
    """The Laserfiche field values, read back the way Laserfiche reads them."""
    fields = ET.parse(xml_path).getroot().find("./Doc/FieldData")
    return {field.get("Name"): field.text for field in fields}


def test_an_ampersand_survives_sanitising(pipeline, invoice):
    data = pipeline.sanitize_data(invoice(vendor_name=OFFICIAL_NAME))

    assert data.vendor_name == OFFICIAL_NAME


def test_surrounding_whitespace_is_still_removed(pipeline, invoice):
    data = pipeline.sanitize_data(invoice(vendor_name="  B & H Photo-Video \n"))

    assert data.vendor_name == "B & H Photo-Video"


def test_a_vendor_name_of_only_whitespace_is_still_none(pipeline, invoice):
    data = pipeline.sanitize_data(invoice(vendor_name="   "))

    assert data.vendor_name is None


def test_the_official_name_the_alias_table_returns_is_kept(pipeline, invoice, queue_tree,
                                                           monkeypatch):
    """Normalisation answers with the canonical name; sanitising must not edit it."""
    def no_database(*args, **kwargs):
        raise RuntimeError("tests never open a database connection")

    monkeypatch.setattr(pipeline, "get_sql_connection", no_database)
    with open(os.environ["AIM_ALIAS_DB_FILE"], "w", encoding="utf-8") as handle:
        json.dump({"ATT MOBILITY II": OFFICIAL_NAME}, handle)

    normalized, is_known = pipeline.normalize_vendor_name("ATT MOBILITY II")
    assert is_known

    data = pipeline.sanitize_data(invoice(vendor_name=normalized))
    assert data.vendor_name == OFFICIAL_NAME


def test_laserfiche_receives_the_vendor_name_intact(pipeline, invoice, tmp_path):
    xml_path = str(tmp_path / "0000_Smith_1.xml")
    data = pipeline.sanitize_data(invoice(vendor_name=OFFICIAL_NAME,
                                          document_type="INVOICE"))

    pipeline.generate_laserfiche_xml(data, "4601", "Smith", xml_path, "0000_Smith_1")

    assert xml_fields(xml_path)["Vendor Name"] == OFFICIAL_NAME
    with open(xml_path, encoding="utf-8") as handle:
        written = handle.read()
    assert "&amp;" in written, "the ampersand is escaped by the XML writer, not removed"
    assert "ATandT" not in written, "the ampersand must not be spelled out"


def test_the_sql_row_and_the_xml_agree(pipeline, invoice, queue_tree, tmp_path):
    """The two records of one invoice are written from one value."""
    data = pipeline.sanitize_data(invoice(vendor_name=OFFICIAL_NAME,
                                          document_type="INVOICE",
                                          invoice_number="INV-10",
                                          invoice_total="100.00",
                                          invoice_date="2026-09-21"))

    pipeline.write_log("invoice.pdf", "SQL Worker", "SUCCESS", "", "4601", "Smith",
                       "0000_Smith_1", data)
    xml_path = str(tmp_path / "0000_Smith_1.xml")
    pipeline.generate_laserfiche_xml(data, "4601", "Smith", xml_path, "0000_Smith_1")

    payload_path = os.path.join(queue_tree.queue("AIM_SQL_QUEUE_DIR"), "0000_Smith_1",
                                f"0000_Smith_1{pipeline.PAYLOAD_SUFFIX}")
    with open(payload_path, encoding="utf-8") as handle:
        payload = json.load(handle)

    assert payload["VendorName"] == OFFICIAL_NAME
    assert xml_fields(xml_path)["Vendor Name"] == payload["VendorName"]


def test_a_corrected_payload_is_not_rewritten_on_its_way_back_out(pipeline, invoice):
    """Rails writes the real name into a vendor-review payload; regenerating the
    XML from it must not change what the row already says."""
    payload = {"VendorName": OFFICIAL_NAME, "InvoiceNumber": "INV-10"}

    corrected = pipeline.sanitize_data(invoice(
        extracted_vendor_name=payload["VendorName"],
        vendor_name=payload["VendorName"],
        invoice_number=payload["InvoiceNumber"],
    ))

    assert corrected.vendor_name == payload["VendorName"]
