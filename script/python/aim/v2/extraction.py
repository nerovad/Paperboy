"""The extraction core: a PDF in, a result out. No routing, no folders.

Lifted from v1's process_cpu_hybrid. The OCR pass, the phase-1 text pass,
the vision passes, the merge rules, the late vendor-rule injection and every
prompt are as they were. What it no longer does is decide where the invoice
goes: it says what it found and why a person might be needed, and the worker
records that on the row.
"""
import os
import time
from dataclasses import dataclass, field
from typing import Optional

import fitz
import ollama
import pytesseract
from PIL import Image

from cleaning import apply_invoice_number_rules, check_missing_fields, sanitize_data
from invoice_models import (
    DOCUMENT_TYPE_GUIDE, UNKNOWN_DOCUMENT_TYPE, VISION_SCHEMA, DocumentManifest, InvoiceData,
    Phase1Data, merge_vision_fields, normalize_document_type,
)
from vendors import normalize_vendor_name, rules_for

# Why a person is needed. These are the row's review_reason values.
UNKNOWN_TYPE = "unknown_type"
UNKNOWN_VENDOR = "unknown_vendor"
MISSING_FIELDS = "missing_fields"
LOW_CONFIDENCE = "low_confidence"
HANDWRITTEN = "handwritten"
EXTRACTION_ERROR = "extraction_error"

TEMP_IMAGE_NAME = "_vision_page.png"


@dataclass
class ExtractionResult:
    outcome: str  # 'split' | 'review' | 'clean'
    data: InvoiceData
    review_reason: Optional[str] = None
    review_note: Optional[str] = None
    manifest: Optional[dict] = None
    high_confidence: bool = True
    # An alias the AI smart match learned, for the worker to record.
    learned_alias: Optional[tuple] = None
    vision_calls: int = field(default=0)


def pdf_page_to_image(pdf_path, page_num, output_path):
    doc = fitz.open(pdf_path)
    page = doc[page_num]
    pix = page.get_pixmap(matrix=fitz.Matrix(1.5, 1.5))
    pix.save(output_path)
    doc.close()


def page_count(pdf_path):
    doc = fitz.open(pdf_path)
    try:
        return len(doc)
    finally:
        doc.close()


def _chat(model, content, schema, images=None, num_predict=None):
    message = {"role": "user", "content": content}
    if images:
        message["images"] = images
    options = {"temperature": 0, "num_ctx": 8192}
    if num_predict:
        options["num_predict"] = num_predict
    return ollama.chat(model=model, messages=[message], format=schema, options=options)


def _vision(settings, prompt, image_path, label):
    response = _chat(settings.vision_model, prompt, VISION_SCHEMA, images=[image_path], num_predict=1024)
    try:
        return InvoiceData.model_validate_json(response["message"]["content"])
    except Exception as e:
        raise RuntimeError(f"{label} Vision AI Hallucination Error: Model failed to return valid JSON schema. Error: {e}")


def extract(pdf_path, settings, aliases, rules, field_alias_text="", split_check=True, heartbeat=None):
    """Read one PDF. Raises on a model or file failure; the worker records it."""
    beat = heartbeat or (lambda: None)
    temp_image = os.path.join(os.path.dirname(pdf_path), TEMP_IMAGE_NAME)
    pytesseract.pytesseract.tesseract_cmd = settings.tesseract_cmd
    result = ExtractionResult(outcome="clean", data=InvoiceData())

    def ask_model(prompt):
        response = ollama.chat(model=settings.text_model, messages=[{"role": "user", "content": prompt}],
                               options={"temperature": 0})
        return response["message"]["content"]

    try:
        total_pages = page_count(pdf_path)

        # -------------------------------------------------------------
        # PHASE 1: Tesseract OCR + the split, quality and type check
        # -------------------------------------------------------------
        full_document_text = ""
        is_high_confidence = True
        extracted_vendor = None
        if split_check:
            print(f"  [>] Phase 1: Running Tesseract OCR on {total_pages} pages...")
            for page_num in range(total_pages):
                started = time.time()
                pdf_page_to_image(pdf_path, page_num, temp_image)
                try:
                    page_text = pytesseract.image_to_string(Image.open(temp_image))
                    full_document_text += f"\n--- PAGE {page_num + 1} ---\n{page_text}"
                    print(f"      - Page {page_num + 1} OCR complete in {time.time() - started:.1f}s")
                except Exception as e:
                    print(f"      [!] OCR Engine Error on page {page_num + 1}: {e}")
                beat()

            print("  [>] Phase 1: Asking Text Model to check for Multiple Invoices, Quality, and Document Type...")
            started = time.time()
            tier1_prompt = (
                f"Analyze this raw document text: \n\n{full_document_text}\n\n"
                "1. Does this document contain MULTIPLE DISTINCT invoices? "
                "CRITICAL RULES FOR MULTIPLE INVOICES: "
                "- Do NOT set 'contains_multiple_invoices' to true for a multi-page invoice. A document that spans multiple pages, shares the same invoice number across pages, or has page indicators like 'Page X of Y' or 'Page X' is a SINGLE invoice. "
                "- Set 'contains_multiple_invoices' to true ONLY if you find completely distinct invoices with different invoice numbers, different transactions, or different vendors combined in the same file.\n"
                "2. Is this text a clean read? Set 'is_high_confidence' to true if you can clearly identify a vendor name and an invoice number. Set it to false if the text looks like garbage, random letters, or is missing a clear invoice number/vendor (likely due to handwriting or a bad scan).\n"
                f"3. What is the document_type? {DOCUMENT_TYPE_GUIDE}\n"
                "4. Extract the exact literal vendor name as 'extracted_vendor_name' if you can find it. If it is illegible, leave it null.\n"
                "Return strictly as JSON."
            )
            response = _chat(settings.text_model, tier1_prompt, Phase1Data.model_json_schema())
            try:
                p1_data = Phase1Data.model_validate_json(response["message"]["content"])
            except Exception as e:
                raise RuntimeError(f"Phase 1 AI Hallucination Error: Model failed to return valid JSON. Error: {e}")
            is_high_confidence = p1_data.is_high_confidence
            doc_type = normalize_document_type(p1_data.document_type)
            extracted_vendor = p1_data.extracted_vendor_name
            print(f"      - Check complete in {time.time() - started:.1f}s. Multiple Invoices = "
                  f"{p1_data.contains_multiple_invoices}, High Confidence = {is_high_confidence}, Type = {doc_type}")
            beat()

            # Only a document the model could not place stops here, for AIM
            # staff to type in review. Every known type goes on to extraction.
            if doc_type == UNKNOWN_DOCUMENT_TYPE:
                result.data = InvoiceData(document_type=doc_type, extracted_vendor_name=extracted_vendor)
                result.outcome, result.review_reason = "review", UNKNOWN_TYPE
                result.review_note = "The AI could not tell what kind of document this is, so it was not extracted."
                result.high_confidence = is_high_confidence
                return result

            if p1_data.contains_multiple_invoices:
                print("  [!] Multiple invoices detected. Generating split manifest...")
                manifest_prompt = (
                    f"Analyze this raw document text from a {total_pages}-page PDF: \n\n{full_document_text}\n\n"
                    "This document contains multiple invoices. Identify each distinct invoice. "
                    "For each invoice, provide the 'vendor_name', the 'invoice_number', and a list of 'pages' (integers starting from 1) that belong to that invoice. "
                    f"Make sure every page from 1 to {total_pages} is assigned to an invoice. "
                    "Return strictly as JSON."
                )
                manifest_response = _chat(settings.text_model, manifest_prompt, DocumentManifest.model_json_schema())
                try:
                    manifest_data = DocumentManifest.model_validate_json(manifest_response["message"]["content"])
                except Exception as e:
                    raise RuntimeError(f"Split Manifest AI Hallucination Error: Model failed to return valid JSON. Error: {e}")
                result.data = InvoiceData(document_type=doc_type, extracted_vendor_name=extracted_vendor)
                result.outcome = "split"
                result.manifest = manifest_data.model_dump()
                result.high_confidence = is_high_confidence
                return result
        else:
            print("  [>] Phase 1: Split check bypassed: this is one invoice.")

        # -------------------------------------------------------------
        # PHASE 2: Vision extraction
        # -------------------------------------------------------------
        print("  [>] Phase 2: Passing to Vision Model for extraction...")
        vendor_hint = ""
        if extracted_vendor:
            match = normalize_vendor_name(extracted_vendor, aliases, ask_model)
            if match.known:
                vendor_hint = rules_for(match.normalized, rules)
                if match.learned:
                    result.learned_alias = match.learned
                if vendor_hint:
                    print(f"      - Injected Vendor Rules for {match.normalized}")

        tier2_prompt = (
            "Analyze this document image. "
            f"First, determine the document_type. {DOCUMENT_TYPE_GUIDE} "
            "Extract the exact literal vendor name as 'extracted_vendor_name', invoice_date, invoice_number, invoice_total, and if present order_number, "
            "and customer_number. "
            f"{field_alias_text} "
            "CRITICAL RULES: "
            "1. For 'invoice_number', use the vendor's invoice number. Do NOT use the transaction number (TRANS#), SALES#, "
            "terminal/store/register number, KEYED REFID, PO / LAR PO, sales order, or customer/account number. Keep any "
            "leading zeros. Set invoice_number_label to the exact label text next to the number you chose, and treat a "
            "'LAR PO' or 'PO' number as order_number. "
            "2. If you see multiple values that map to invoice_total, and one is $0.00, IGNORE the $0.00 value and extract the non-zero amount. "
            "3. List in 'handwritten_financial_fields' which of the money amounts -- 'subtotal', 'tax', 'total' -- are written by hand (pen, pencil, marker) rather than printed or typed. "
            "Signatures, initials, approval notes such as 'OK to pay', handwritten dates and handwritten invoice or PO numbers are NOT money amounts: they do not belong in the list. "
            "If every amount is printed, return an empty list, even when the page carries a signature or a note. "
            "4. HOW TO INTERPRET VENDOR RULES: Vendor rules are written by human users in plain English to help you locate values on the page. Treat them as helpful visual hints. However, you MUST still strictly obey the requested JSON schema. Do NOT invent new JSON keys based on user rules, and do NOT delete or omit standard JSON keys just because a user tells you to 'ignore' a visual label on the document. "
            "5. DO NOT dump raw unstructured text or multiple lines into any field. If a value is too long or you are unsure, leave it blank."
            "Return strictly as JSON."
        )
        if vendor_hint:
            tier2_prompt += f"\n\nVENDOR-SPECIFIC RULES FOR THIS INVOICE:\n{vendor_hint}"

        master_data = InvoiceData()
        print("      - Processing Page 1 visually...")
        started = time.time()
        pdf_page_to_image(pdf_path, 0, temp_image)
        merge_vision_fields(master_data, _vision(settings, tier2_prompt, temp_image, "Phase 2"))
        result.vision_calls += 1
        print(f"      - Page 1 Vision extraction complete in {time.time() - started:.1f}s.")
        beat()

        sanitize_data(master_data)
        missing = check_missing_fields(master_data)

        if missing and total_pages > 1:
            print(f"      - Still missing {missing}. Processing Last Page ({total_pages}) visually...")
            started = time.time()
            pdf_page_to_image(pdf_path, total_pages - 1, temp_image)
            merge_vision_fields(master_data, _vision(settings, tier2_prompt, temp_image, "Phase 2 Last Page"))
            result.vision_calls += 1
            print(f"      - Last Page Vision extraction complete in {time.time() - started:.1f}s.")
            beat()

        sanitize_data(master_data)
        missing = check_missing_fields(master_data)

        # Late vendor rule injection: the vendor was only readable by vision.
        if not vendor_hint and master_data.extracted_vendor_name and missing:
            match = normalize_vendor_name(master_data.extracted_vendor_name, aliases, ask_model)
            if match.known:
                if match.learned:
                    result.learned_alias = match.learned
                late_hint = rules_for(match.normalized, rules)
                if late_hint:
                    print(f"      [!] Late Vendor identified: {match.normalized}. Re-running Vision with rules to find {missing}...")
                    enhanced_prompt = tier2_prompt + f"\n\nVENDOR-SPECIFIC RULES FOR THIS INVOICE:\n{late_hint}"
                    started = time.time()
                    pdf_page_to_image(pdf_path, 0, temp_image)
                    merge_vision_fields(master_data, _vision(settings, enhanced_prompt, temp_image, "Fallback"))
                    result.vision_calls += 1
                    print(f"      - Fallback Vision extraction complete in {time.time() - started:.1f}s.")
                    sanitize_data(master_data)
                    beat()

        apply_invoice_number_rules(master_data)

        # -------------------------------------------------------------
        # PHASE 3: what was found, and whether a person is needed
        # -------------------------------------------------------------
        print("  [>] Phase 3: Validation...")
        master_data.document_type = normalize_document_type(master_data.document_type)
        result.data = master_data
        result.high_confidence = is_high_confidence

        if master_data.document_type == UNKNOWN_DOCUMENT_TYPE:
            return _review(result, UNKNOWN_TYPE, "The AI could not tell what kind of document this is.")

        if getattr(master_data, "contains_handwritten_financials", False):
            handwritten = ", ".join(master_data.handwritten_financial_fields or []) or "subtotal, tax, or total"
            return _review(result, HANDWRITTEN,
                           f"The AI found these amounts written by hand: {handwritten}. They must be verified by a person.")

        match = normalize_vendor_name(master_data.extracted_vendor_name, aliases, ask_model)
        if match.known:
            master_data.vendor_name = match.normalized
            if match.learned:
                result.learned_alias = match.learned
        elif master_data.extracted_vendor_name:
            return _review(result, UNKNOWN_VENDOR,
                           f"Unknown vendor: {master_data.extracted_vendor_name}. Choose the official name, or teach the alias.")

        missing = check_missing_fields(master_data)
        if missing:
            return _review(result, MISSING_FIELDS, f"The AI could not find: {', '.join(missing)}.")

        if not is_high_confidence:
            return _review(result, LOW_CONFIDENCE, "The scan read poorly. Check every field against the page.")

        result.outcome = "clean"
        return result
    finally:
        if os.path.exists(temp_image):
            try:
                os.remove(temp_image)
            except OSError:
                pass


def _review(result, reason, note):
    result.outcome = "review"
    result.review_reason = reason
    result.review_note = note
    return result
