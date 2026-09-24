"""Export: the billing row, the Laserfiche XML and the archive copy.

Everything is written from the row's columns -- the reviewer's corrections
included -- so the billing row, the XML and what the reviewer saw cannot
disagree. The XML is generated exactly as v1 generated it.
"""
import json
import os
import shutil
import xml.etree.ElementTree as ET
from datetime import datetime
from xml.dom import minidom

import pyodbc

from store import ACTOR

EXPORT_ERROR = "export_error"
DUPLICATE_CODES = ("2601", "2627")


class SqlMappingError(Exception):
    """The billing mapping did not apply, so nothing could be inserted."""


def money(value):
    return None if value is None else f"{float(value):.2f}"


def day(value):
    if value is None:
        return None
    return value.strftime("%Y-%m-%d") if hasattr(value, "strftime") else str(value)


def billing_payload(row):
    """The v1 payload shape, from the row."""
    return {
        "FileName": row.get("source_filename") or f"{row['batch_id']}.pdf",
        "Submitter": row.get("submitter"),
        "BU": row.get("budget_unit"),
        "VendorName": row.get("vendor_name"),
        "InvoiceNumber": row.get("invoice_number"),
        "InvoiceTotal": money(row.get("invoice_total")),
        "InvoiceDate": day(row.get("invoice_date")),
        "OrderNumber": row.get("order_number"),
        "CustomerNumber": row.get("customer_number"),
        "Subtotal": money(row.get("subtotal")),
        "SalesTax": money(row.get("sales_tax")),
        "ExtractedMetadata": row.get("extracted"),
        "Status": "SUCCESS",
        "ErrorMessage": None,
        "ProcessedTimestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "InvoiceConcatID": row["batch_id"],
    }


def load_mapping(settings):
    path = settings.billing_mapping_file
    if not os.path.exists(path):
        raise SqlMappingError(f"billing mapping file {path} does not exist; deploy it with bin/deploy-aim-workers --v2")
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def insert_billing_row(settings, payload):
    """v1's insert_sql_record, for the billing table."""
    mapping = load_mapping(settings)
    columns, values = [], []
    for script_key, sql_column in mapping.items():
        if script_key in payload:
            if sql_column == "InvoiceConcatID":
                continue  # computed by the database
            columns.append(sql_column)
            values.append(payload[script_key])
    if not columns:
        raise SqlMappingError(
            f"no column of {settings.billing_table} matched the payload; mapping expects "
            f"{sorted(mapping.keys())}, the payload carries {sorted(payload.keys())}")
    placeholders = ", ".join("?" for _ in columns)
    query = f"INSERT INTO {settings.billing_table} ({', '.join(columns)}) VALUES ({placeholders})"
    conn = pyodbc.connect(settings.connection_string("billing"))
    try:
        cursor = conn.cursor()
        cursor.execute(query, values)
        conn.commit()
    finally:
        conn.close()


def write_laserfiche_xml(row, settings, xml_path):
    """v1's generate_laserfiche_xml, from the row."""
    batch_id = row["batch_id"]
    root = ET.Element("ImportSession")
    doc = ET.SubElement(root, "Doc")
    ET.SubElement(doc, "DocFile").text = f"{batch_id}.pdf"
    doc_type = row.get("document_type") or "UNKNOWN"
    ET.SubElement(doc, "TemplateName").text = str(doc_type).title()
    inbox = settings.laserfiche_inbox_path
    bu_number = row.get("budget_unit")
    ET.SubElement(doc, "FolderPath").text = f"{inbox}\\{bu_number}" if bu_number else f"{inbox}\\_UNSORTED"
    field_data = ET.SubElement(doc, "FieldData")

    def add_field(name, value):
        f = ET.SubElement(field_data, "Field", Name=name)
        f.text = str(value) if value else ""

    add_field("Budget Unit Number", bu_number)
    add_field("Submitted by", row.get("submitter"))
    add_field("Processing ID", batch_id)
    add_field("Vendor Name", row.get("vendor_name"))
    add_field("Invoice Date", day(row.get("invoice_date")))
    add_field("Invoice Number", row.get("invoice_number"))
    add_field("Invoice Total", money(row.get("invoice_total")))
    add_field("Order Number", row.get("order_number"))
    add_field("Customer Number", row.get("customer_number"))

    xml_str = minidom.parseString(ET.tostring(root, encoding="utf-8")).toprettyxml(indent="  ")
    with open(xml_path, "w", encoding="utf-8") as handle:
        handle.write(xml_str)


def safe_name(value, fallback):
    cleaned = "".join(c for c in str(value or "") if c.isalnum() or c in (" ", "-", "_")).strip()
    return cleaned or fallback


def archive_folder(row, settings):
    return os.path.join(settings.archive_dir, safe_name(row.get("budget_unit"), "UnknownBU"),
                        safe_name(row.get("submitter"), "UnknownUser"),
                        datetime.now().strftime("%Y-%m-%d"), row["batch_id"])


def export_invoice(row, settings, db, insert=insert_billing_row):
    """Bill it, hand it to Laserfiche, keep a copy. Returns the note for the event."""
    batch_id = row["batch_id"]
    pdf_path = settings.pdf_path(batch_id)
    if not os.path.exists(pdf_path):
        raise FileNotFoundError(f"the PDF is not in the store: {pdf_path}")

    note = "billing row inserted"
    try:
        insert(settings, billing_payload(row))
    except pyodbc.IntegrityError as e:
        if any(code in str(e) for code in DUPLICATE_CODES):
            note = "duplicate billing key: the billing row already existed"
            print(f"    [i] {batch_id}: {note}")
        else:
            raise

    xml_path = settings.xml_path(batch_id)
    write_laserfiche_xml(row, settings, xml_path)

    os.makedirs(settings.processed_dir, exist_ok=True)
    shutil.copy2(pdf_path, os.path.join(settings.processed_dir, f"{batch_id}.pdf"))
    shutil.copy2(xml_path, os.path.join(settings.processed_dir, f"{batch_id}.xml"))

    target = archive_folder(row, settings)
    os.makedirs(target, exist_ok=True)
    shutil.copy2(pdf_path, os.path.join(target, f"{batch_id}.pdf"))
    shutil.copy2(xml_path, os.path.join(target, f"{batch_id}.xml"))
    print(f"    [✓] {batch_id} exported to Laserfiche and archived.")
    return note
