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


# What the billing table's [Invoice Status] says for each state. We bill for
# every invoice that arrives, whatever becomes of it, so the row is written at
# intake and kept current: this is how the status reaches it.
BILLING_STATUS = {
    "received": "Received", "extracting": "Processing", "needs_review": "Action Needed",
    "needs_split": "Needs Split", "ready_for_approval": "Ready for Approval",
    "approved": "Approved", "exporting": "Approved", "exported": "Exported",
    "failed": "Failed", "rejected": "Rejected", "deleted": "Deleted", "split": "Split",
}


def billing_payload(row, approved_by=None):
    """The billing row's values, from the invoice row."""
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
        "Status": BILLING_STATUS.get(row.get("state"), row.get("state")),
        "BatchID": row["batch_id"],
        "Source": "AIM",
        "ApprovedBy": approved_by,
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


def quoted(column):
    return column if column.startswith("[") else f"[{column}]"


def billing_columns(settings, payload):
    mapping = load_mapping(settings)
    pairs = [(quoted(column), payload[key]) for key, column in mapping.items()
             if key in payload and column != "InvoiceConcatID"]
    if not any(column == "[BatchID]" for column, _ in pairs):
        raise SqlMappingError(f"the billing mapping must map BatchID; it maps {sorted(mapping.keys())}")
    return pairs


def upsert_billing_row(settings, payload):
    """Write the invoice's one billing row: update it by BatchID, or insert it."""
    pairs = billing_columns(settings, payload)
    table = settings.billing_table
    conn = pyodbc.connect(settings.connection_string("billing"))
    try:
        cursor = conn.cursor()
        sets = ", ".join(f"{column} = ?" for column, _ in pairs)
        cursor.execute(f"UPDATE {table} SET {sets} WHERE [BatchID] = ?",
                       *[value for _, value in pairs], payload["BatchID"])
        if cursor.rowcount == 0:
            columns = ", ".join(column for column, _ in pairs)
            marks = ", ".join("?" for _ in pairs)
            cursor.execute(f"INSERT INTO {table} ({columns}) VALUES ({marks})", *[value for _, value in pairs])
        conn.commit()
    finally:
        conn.close()


insert_billing_row = upsert_billing_row  # the name the worker was built with


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

    # The billing row takes the approved values now; the status follows on
    # the next billing sync, once the row reads exported.
    note = "billing row updated with the approved values"
    try:
        insert(settings, billing_payload(row, approved_by=db.approved_by(row["id"])))
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
