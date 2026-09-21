"""The key fields must reach storage as the vendor typed them.

`sanitize_data` rewrote "&" to "and" in the vendor name. 58 of the ~900
official vendors carry an ampersand, so "AT&T MOBILITY" was stored, keyed and
exported as "ATandT MOBILITY" -- and when a human corrected a vendor review in
Rails, the SQL row kept the real name while the regenerated XML did not. Two
records of the same invoice, disagreeing. Plan step 4.1, audit H5.

`_clean_text_field` did the same to the invoice and order numbers, deleting
every character outside `[a-zA-Z0-9_\\- ]`, so `INV-2024/001` was stored as
`INV-2024001`. Plan step 4.2.

The total was canonical only on the path the AI worker writes. A payload
corrected in Rails was sanitised for the XML and inserted raw, so one invoice
held two totals; and a credit printed as `(100.00)` lost its brackets with its
dollar sign and was stored as a charge. Plan step 4.3.
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


# Invoice and order numbers -- step 4.2.

PUNCTUATED_NUMBERS = [
    "INV-2024/001",        # a slash-separated series
    "2024.01.00123",       # dotted
    "INV #2024-1",         # the hash is part of the number the vendor prints
    "PO-2024/1 (REV A)",
    "12,345-B",
    "S:2024:1",
    "INV_2024\\001",       # a backslash-separated series
    "N/A-000",
]


@pytest.mark.parametrize("number", PUNCTUATED_NUMBERS)
def test_a_punctuated_invoice_number_round_trips(pipeline, invoice, number):
    data = pipeline.sanitize_data(invoice(invoice_number=number))

    assert data.invoice_number == number


@pytest.mark.parametrize("number", PUNCTUATED_NUMBERS)
def test_the_order_number_is_treated_the_same(pipeline, invoice, number):
    data = pipeline.sanitize_data(invoice(order_number=number))

    assert data.order_number == number


def test_whitespace_around_a_number_is_still_removed(pipeline, invoice):
    data = pipeline.sanitize_data(invoice(invoice_number="  INV-2024/001 \n"))

    assert data.invoice_number == "INV-2024/001"


def test_a_line_break_inside_a_number_becomes_one_space(pipeline, invoice):
    data = pipeline.sanitize_data(invoice(invoice_number="INV\t\n 2024"))

    assert data.invoice_number == "INV 2024"


def test_a_number_of_only_whitespace_is_none(pipeline, invoice):
    data = pipeline.sanitize_data(invoice(invoice_number="   "))

    assert data.invoice_number is None


def test_an_invisible_character_cannot_split_the_key(pipeline, invoice):
    """Two numbers that read the same on the page must compare the same."""
    typed = pipeline.sanitize_data(invoice(invoice_number="INV-2024/001"))
    scanned = pipeline.sanitize_data(invoice(invoice_number="INV-2024\u200b/001"))

    assert scanned.invoice_number == typed.invoice_number


def test_a_non_breaking_space_is_stored_as_an_ordinary_space(pipeline, invoice):
    data = pipeline.sanitize_data(invoice(invoice_number="INV\u00a02024"))

    assert data.invoice_number == "INV 2024"


def test_a_control_code_is_removed(pipeline, invoice):
    data = pipeline.sanitize_data(invoice(invoice_number="INV-1\x00"))

    assert data.invoice_number == "INV-1"


def test_laserfiche_receives_the_numbers_intact(pipeline, invoice, tmp_path):
    xml_path = str(tmp_path / "0000_Smith_2.xml")
    data = pipeline.sanitize_data(invoice(vendor_name=OFFICIAL_NAME,
                                          document_type="INVOICE",
                                          invoice_number="INV-2024/001",
                                          order_number="PO-2024/7"))

    pipeline.generate_laserfiche_xml(data, "4601", "Smith", xml_path, "0000_Smith_2")

    fields = xml_fields(xml_path)
    assert fields["Invoice Number"] == "INV-2024/001"
    assert fields["Order Number"] == "PO-2024/7"


def test_a_punctuated_number_reaches_both_records_the_same(pipeline, invoice, queue_tree,
                                                           tmp_path):
    data = pipeline.sanitize_data(invoice(vendor_name=OFFICIAL_NAME,
                                          document_type="INVOICE",
                                          invoice_number="INV-2024/001",
                                          invoice_total="100.00",
                                          invoice_date="2026-09-21"))

    pipeline.write_log("invoice.pdf", "SQL Worker", "SUCCESS", "", "4601", "Smith",
                       "0000_Smith_2", data)
    xml_path = str(tmp_path / "0000_Smith_2.xml")
    pipeline.generate_laserfiche_xml(data, "4601", "Smith", xml_path, "0000_Smith_2")

    payload_path = os.path.join(queue_tree.queue("AIM_SQL_QUEUE_DIR"), "0000_Smith_2",
                                f"0000_Smith_2{pipeline.PAYLOAD_SUFFIX}")
    with open(payload_path, encoding="utf-8") as handle:
        payload = json.load(handle)

    assert payload["InvoiceNumber"] == "INV-2024/001"
    assert xml_fields(xml_path)["Invoice Number"] == payload["InvoiceNumber"]


def test_a_slash_in_a_number_does_not_become_a_folder(pipeline, invoice, queue_tree):
    """A queue folder is named after the processing id. The numbers are data,
    and the one place a number does name a path -- the batch splitter, from the
    manifest -- makes it safe where it builds that path."""
    data = pipeline.sanitize_data(invoice(invoice_number="INV-2024/001",
                                          order_number="PO/7"))

    pipeline.write_log("invoice.pdf", "AI Worker", "SUCCESS", "", "4601", "Smith",
                       "0000_Smith_3", data)

    assert os.listdir(queue_tree.queue("AIM_SQL_QUEUE_DIR")) == ["0000_Smith_3"]


# Totals -- step 4.3.

@pytest.fixture
def sql_worker(import_worker):
    return import_worker("02_sql_worker")


def test_the_three_spellings_of_one_total_agree(pipeline, invoice):
    """The step's own test: 100.0, 100.00 and $100.00 are one stored value."""
    stored = {pipeline.sanitize_data(invoice(invoice_total=spelling)).invoice_total
              for spelling in ("100.0", "100.00", "$100.00")}

    assert stored == {"100.00"}


@pytest.mark.parametrize("typed,stored", [
    ("1,234.56", "1234.56"),
    ("$ 1,234.5", "1234.50"),
    ("$1,234", "1234.00"),
    ("USD 100", "100.00"),
    ("100", "100.00"),
])
def test_a_total_is_stored_one_way(pipeline, invoice, typed, stored):
    assert pipeline.sanitize_data(invoice(invoice_total=typed)).invoice_total == stored


@pytest.mark.parametrize("typed", ["(100.00)", "100.00-", "-100.00", "($100.00)"])
def test_a_credit_keeps_its_sign(pipeline, invoice, typed):
    """An invoice prints a credit as brackets or a trailing minus. Dropping
    either stored a credit as a charge, or lost the amount entirely."""
    assert pipeline.sanitize_data(invoice(invoice_total=typed)).invoice_total == "-100.00"


@pytest.mark.parametrize("typed", ["0.00", "$0.00", "-0.00", "(0.00)", "0"])
def test_zero_has_one_spelling(pipeline, invoice, typed):
    assert pipeline.sanitize_data(invoice(invoice_total=typed)).invoice_total == "0.00"


@pytest.mark.parametrize("typed", ["1.234,56", "1,50"])
def test_a_comma_decimal_is_refused_rather_than_guessed(pipeline, invoice, typed):
    """Reading ",56" as a decimal needs a locale nobody stated, and guessing
    stored 1.23. An empty total routes the invoice to review instead."""
    assert pipeline.sanitize_data(invoice(invoice_total=typed)).invoice_total is None


@pytest.mark.parametrize("typed", ["n/a", "12-3456", "", "   "])
def test_something_that_is_not_money_is_not_stored_as_money(pipeline, invoice, typed):
    assert pipeline.sanitize_data(invoice(invoice_total=typed)).invoice_total is None


def test_the_row_and_the_xml_carry_one_set_of_values(sql_worker, queue_tree,
                                                     monkeypatch):
    """A reviewer's corrections reach SQL the way they reach Laserfiche.

    Rails writes what the reviewer typed. The worker sanitised a copy for the
    XML and inserted the payload untouched, so the row said "$1,234.5" and the
    export said "1234.50".
    """
    folder = queue_tree.add_invoice("AIM_SQL_QUEUE_DIR", "INV-9", pdf=True)
    typed = {"BU": "4641", "Submitter": "Test User", "DocumentType": "INVOICE",
             "VendorName": OFFICIAL_NAME, "InvoiceNumber": "INV-2024/001",
             "InvoiceTotal": "$1,234.5", "InvoiceDate": "09/21/2026",
             "OrderNumber": "PO-2024/7", "InvoiceConcatID": "INV-9"}
    with open(os.path.join(folder, "INV-9_READY_FOR_SQL.json"), "w",
              encoding="utf-8") as handle:
        json.dump(typed, handle)

    inserted = []
    monkeypatch.setattr(sql_worker, "insert_sql_record",
                        lambda section, payload: inserted.append(dict(payload)))
    monkeypatch.setattr(sql_worker, "archive_batch", lambda *args: True)

    sql_worker.run_sql_worker()

    row = inserted[0]
    fields = xml_fields(os.path.join(os.environ["AIM_PROCESSED_DIR"], "INV-9.xml"))

    assert row["InvoiceTotal"] == "1234.50"
    assert row["InvoiceDate"] == "2026-09-21"
    assert fields["Invoice Total"] == row["InvoiceTotal"]
    assert fields["Invoice Date"] == row["InvoiceDate"]
    assert fields["Vendor Name"] == row["VendorName"] == OFFICIAL_NAME
    assert fields["Invoice Number"] == row["InvoiceNumber"] == "INV-2024/001"
    assert fields["Order Number"] == row["OrderNumber"] == "PO-2024/7"


def test_every_insert_of_one_batch_carries_the_same_values(sql_worker, queue_tree,
                                                           monkeypatch):
    """Tracking and billing are two tables, one invoice."""
    folder = queue_tree.add_invoice("AIM_SQL_QUEUE_DIR", "INV-8", pdf=True)
    with open(os.path.join(folder, "INV-8_READY_FOR_SQL.json"), "w",
              encoding="utf-8") as handle:
        json.dump({"BU": "4641", "Submitter": "Test User", "VendorName": OFFICIAL_NAME,
                   "InvoiceTotal": "(100.00)", "InvoiceConcatID": "INV-8"}, handle)

    inserted = []
    monkeypatch.setattr(sql_worker, "insert_sql_record",
                        lambda section, payload: inserted.append(dict(payload)))
    monkeypatch.setattr(sql_worker, "archive_batch", lambda *args: True)

    sql_worker.run_sql_worker()

    assert len(inserted) == 2, "the batch is inserted into tracking and billing"
    assert {row["InvoiceTotal"] for row in inserted} == {"-100.00"}
