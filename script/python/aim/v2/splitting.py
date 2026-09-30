"""Split a batch into the invoices its manifest names.

The manifest is on the row, written by extraction and corrected by a person
on the Batch Split page. Each invoice's pages are cut into
`_STORE/<parent>_SPLIT_<n>/`, one child row is inserted per invoice, and the
parent ends as `split`, its event naming the children.
"""
import json
import os

import fitz

from store import ACTOR

# Why a person is needed after a split that could not be done.
SPLIT_ERROR = "split_error"


def manifest_pages(invoice, number):
    """An invoice's pages: the sorted list of 1-based page numbers it names.

    Pages arrive already as numbers. Paperboy's Aim::SplitPlan -- the only
    thing that asks for a split -- parses what a person typed ("1-3, 5"),
    refuses junk and reversed ranges, and writes integers; the extraction
    manifest is `list[int]` by its schema. So there is no page syntax to parse
    here, and anything that is not a list of page numbers is refused, not
    guessed at: the split fails and a person looks.
    """
    pages = invoice.get("pages")
    if (not isinstance(pages, list) or not pages
            or any(isinstance(p, bool) or not isinstance(p, int) or p < 1 for p in pages)):
        raise ValueError(f"invoice {number} of the manifest does not list its pages as page numbers: {pages!r}")
    return sorted(set(pages))


def read_manifest(row):
    """The manifest's invoices, each with its `pages` checked and sorted."""
    raw = row.get("manifest")
    if not raw:
        raise ValueError("the row has no manifest to split by")
    manifest = json.loads(raw) if isinstance(raw, str) else raw
    invoices = [dict(inv, pages=manifest_pages(inv, number))
                for number, inv in enumerate(manifest.get("invoices", []), start=1)]
    if len(invoices) < 2:
        raise ValueError("a split needs at least two invoices with pages")
    return invoices


def split_batch(row, settings, db):
    """Cut the parent's PDF by its manifest; returns the children's batch ids."""
    parent_id = row["batch_id"]
    invoices = read_manifest(row)
    source = settings.pdf_path(parent_id)
    doc = fitz.open(source)
    children = []
    try:
        for index, invoice in enumerate(invoices, start=1):
            pages = invoice["pages"]
            child_id = f"{parent_id}_SPLIT_{index}"
            folder = settings.store_folder(child_id)
            os.makedirs(folder, exist_ok=True)
            child_pdf = settings.pdf_path(child_id)

            new_doc = fitz.open()
            kept = 0
            for page in pages:
                page_idx = page - 1  # manifests are 1-based, PyMuPDF 0-based
                if 0 <= page_idx < len(doc):
                    new_doc.insert_pdf(doc, from_page=page_idx, to_page=page_idx)
                    kept += 1
            new_doc.save(child_pdf)
            new_doc.close()

            fields = {
                "budget_unit": row.get("budget_unit"),
                "submitter": row.get("submitter"),
                "assigned_to": row.get("assigned_to"),
                "assignment_source": row.get("assignment_source"),
                "source_filename": row.get("source_filename"),
                "source_path": row.get("source_path"),
                "parent_id": row["id"],
                "split_check": False,
                "page_count": kept,
                "attempt": 0,
                # What the manifest said, for the review page to start from.
                "extracted_vendor_name": invoice.get("vendor_name") or None,
                "invoice_number": invoice.get("invoice_number") or None,
            }
            db.insert_invoice(child_id, "received", "extract", fields,
                              note=f"split from {parent_id}, pages {', '.join(map(str, pages))}")
            children.append(child_id)
            print(f"    [✓] Created split invoice: {child_id}")
    finally:
        doc.close()

    db.transition(row["id"], row["state"], "split", note=f"split into {len(children)}: {', '.join(children)}",
                  command=None, actor=ACTOR)
    return children
