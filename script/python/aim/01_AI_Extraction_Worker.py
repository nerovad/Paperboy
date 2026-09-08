import os
import time
import shutil
import json
import random
import string
import re
from datetime import datetime

import ollama
import fitz
from PIL import Image
import pytesseract

from pydantic import BaseModel

from pipeline_common import (
    BASE_DIR, PENDING_VISION_DIR, ACTION_NEEDED_DIR, LOG_DIR, TEMP_IMAGE,
    BATCH_SPLIT_DIR, DocumentManifest, is_file_stable,
    InvoiceData, write_log, check_missing_fields, apply_invoice_number_rules,
    sanitize_data, generate_laserfiche_xml, pdf_page_to_image,
    normalize_vendor_name, VENDOR_REVIEW_DIR, SQL_QUEUE_DIR, REPROCESS_QUEUE_DIR, LOW_CONFIDENCE_REVIEW_DIR,
    ERROR_QUEUE_DIR, get_rules_for_vendor, get_global_field_aliases,
    bootstrap,
)
from typing import Optional

STALE_QUEUE_FOLDER_SECONDS = 300
AI_QUEUE_ERROR_MARKER = ".ai_queue_error.json"
REPROCESS_ERROR_MARKER = ".ai_reprocess_error.json"

class Phase1Data(BaseModel):
    contains_multiple_invoices: bool
    is_high_confidence: bool
    document_type: str
    extracted_vendor_name: Optional[str] = None

def generate_unique_id(bu_number, filename):
    name_without_ext, _ = os.path.splitext(filename)
    if name_without_ext.startswith("ERROR_"):
        name_without_ext = name_without_ext.replace("ERROR_", "", 1)
    id_pattern = r"^\d+\.\d{8}_\d{6}\..+-\[[A-Z0-9]{4}\]$"
    test_name = name_without_ext
    if "_SPLIT_" in name_without_ext:
        test_name = name_without_ext.split("_SPLIT_")[0]
    if re.match(id_pattern, test_name):
        return name_without_ext
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    hash_str = ''.join(random.choices(string.ascii_uppercase + string.digits, k=4))
    return f"{bu_number}.{timestamp}.{name_without_ext}-[{hash_str}]"

def mark_reprocess_error(folder_path, folder_name, pdf_path, error):
    marker_path = os.path.join(folder_path, REPROCESS_ERROR_MARKER)
    error_id = f"REPROCESS_ERROR_{folder_name}"
    dest_folder = os.path.join(ERROR_QUEUE_DIR, error_id)
    os.makedirs(dest_folder, exist_ok=True)

    message = str(error)
    ticket_path = os.path.join(dest_folder, f"{error_id}.ticket")
    with open(ticket_path, "w", encoding="utf-8") as f:
        f.write("--- MANUAL ACTION NEEDED (REPROCESS FAILED) ---\n")
        f.write(f"Original folder: {folder_path}\n")
        f.write(f"Original PDF: {pdf_path}\n\n")
        f.write("The AI worker could not finish a reprocess item and stopped retrying it automatically.\n")
        f.write(f"Error Details: {message}\n\n")
        f.write("Close anything that may have the PDF open, then move the original folder back into the reprocess flow if needed.\n")

    try:
        with open(marker_path, "w", encoding="utf-8") as marker:
            json.dump({
                "error": message,
                "action_needed_folder": error_id,
                "timestamp": datetime.now().isoformat()
            }, marker, indent=4)
    except Exception:
        pass

def folder_age_seconds(folder_path):
    try:
        return time.time() - os.path.getmtime(folder_path)
    except OSError:
        return STALE_QUEUE_FOLDER_SECONDS + 1

def mark_ai_queue_error(folder_path, folder_name, reason, error=None, pdf_path=None):
    marker_path = os.path.join(folder_path, AI_QUEUE_ERROR_MARKER)
    error_id = f"AI_QUEUE_ERROR_{folder_name}"
    dest_folder = os.path.join(ERROR_QUEUE_DIR, error_id)
    os.makedirs(dest_folder, exist_ok=True)

    message = str(error) if error else reason
    ticket_path = os.path.join(dest_folder, f"{error_id}.ticket")
    with open(ticket_path, "w", encoding="utf-8") as f:
        f.write("--- MANUAL ACTION NEEDED (AI QUEUE FAILED) ---\n")
        f.write(f"Original folder: {folder_path}\n")
        if pdf_path:
            f.write(f"Original PDF: {pdf_path}\n")
        f.write(f"\nProblem: {reason}\n")
        if error:
            f.write(f"Error Details: {message}\n")
        f.write("\nThe AI worker stopped retrying this queue item automatically.\n")
        f.write("Review the original queue folder, then re-spool the invoice if needed.\n")

    try:
        with open(marker_path, "w", encoding="utf-8") as marker:
            json.dump({
                "reason": reason,
                "error": message,
                "action_needed_folder": error_id,
                "timestamp": datetime.now().isoformat()
            }, marker, indent=4)
    except Exception:
        pass

def process_cpu_hybrid(pdf_path, bu_number, submitter_name, is_urgent=False):
    filename = os.path.basename(pdf_path)
    name_without_ext, _ = os.path.splitext(filename)
    processing_id = generate_unique_id(bu_number, filename)
    
    sidecar = os.path.join(os.path.dirname(pdf_path), f"{name_without_ext}.json")
    bypass_split = False
    if os.path.exists(sidecar):
        try:
            with open(sidecar, "r", encoding="utf-8") as sf:
                meta = json.load(sf)
            bu_number = meta.get("bu", bu_number)
            submitter_name = meta.get("submitter", submitter_name)
            bypass_split = meta.get("bypass_split", False)
        except Exception:
            pass

    print(f"\n========================================================")
    print(f"[TEST SCRIPT] Processing: {filename}")
    print(f"ID: {processing_id}")
    print(f"========================================================")
    
    doc = fitz.open(pdf_path)
    total_pages = len(doc)
    doc.close()
    
    # ---------------------------------------------------------
    # PHASE 1: Tesseract OCR + Splitting Check
    # ---------------------------------------------------------
    full_document_text = ""
    is_high_confidence = True
    extracted_vendor = None
    if not bypass_split:
        print(f"  [>] Phase 1: Running Tesseract OCR on {total_pages} pages...")
        for page_num in range(total_pages):
            start_time = time.time()
            pdf_page_to_image(pdf_path, page_num, TEMP_IMAGE)
                
            try:
                page_text = pytesseract.image_to_string(Image.open(TEMP_IMAGE))
                full_document_text += f"\n--- PAGE {page_num + 1} ---\n{page_text}"
                print(f"      - Page {page_num + 1} OCR complete in {time.time()-start_time:.1f}s")
            except Exception as e:
                print(f"      [!] OCR Engine Error on page {page_num + 1}: {e}")
        
        print(f"  [>] Phase 1: Asking Text Model to check for Multiple Invoices, Quality, and Document Type...")
        start_time = time.time()
        tier1_prompt = (
            f"Analyze this raw document text: \n\n{full_document_text}\n\n"
            "1. Does this document contain MULTIPLE DISTINCT invoices? "
            "CRITICAL RULES FOR MULTIPLE INVOICES: "
            "- Do NOT set 'contains_multiple_invoices' to true for a multi-page invoice. A document that spans multiple pages, shares the same invoice number across pages, or has page indicators like 'Page X of Y' or 'Page X' is a SINGLE invoice. "
            "- Set 'contains_multiple_invoices' to true ONLY if you find completely distinct invoices with different invoice numbers, different transactions, or different vendors combined in the same file.\n"
            "2. Is this text a clean read? Set 'is_high_confidence' to true if you can clearly identify a vendor name and an invoice number. Set it to false if the text looks like garbage, random letters, or is missing a clear invoice number/vendor (likely due to handwriting or a bad scan).\n"
            "3. What is the document_type? Choose one of: 'INVOICE', 'STATEMENT', 'CREDIT', or 'UNKNOWN'. If it is a letter, a notice, or anything that is not a bill of sale, choose 'UNKNOWN'. (Exception: 'Member Statement' or 'Customer Receipt' documents from stores like Home Depot should be classified as 'INVOICE').\n"
            "4. Extract the exact literal vendor name as 'extracted_vendor_name' if you can find it. If it is illegible, leave it null.\n"
            "Return strictly as JSON."
        )
        response = ollama.chat(
            model='qwen2.5',
            messages=[{'role': 'user', 'content': tier1_prompt}],
            format=Phase1Data.model_json_schema(),
            options={'temperature': 0, 'num_ctx': 8192}
        )
        try:
            p1_data = Phase1Data.model_validate_json(response['message']['content'])
        except Exception as e:
            raise RuntimeError(f"Phase 1 AI Hallucination Error: Model failed to return valid JSON. Error: {e}")
        is_high_confidence = p1_data.is_high_confidence
        doc_type = p1_data.document_type
        extracted_vendor = p1_data.extracted_vendor_name
        print(f"      - Check complete in {time.time()-start_time:.1f}s. Multiple Invoices = {p1_data.contains_multiple_invoices}, High Confidence = {is_high_confidence}, Type = {doc_type}")

        if doc_type != "INVOICE":
            dest_folder = os.path.join(ACTION_NEEDED_DIR, processing_id)
            os.makedirs(dest_folder, exist_ok=True)
            print(f"  [!] Document Type is {doc_type}. Bypassing Vision Model. Routing to human review.")
            shutil.move(pdf_path, os.path.join(dest_folder, f"{processing_id}.pdf"))
            with open(os.path.join(dest_folder, f"{processing_id}.ticket"), "w") as f:
                f.write(f"AI rejected this document before Vision extraction because Phase 1 Text OCR determined the Document Type is: {doc_type}.")
            write_log(filename, "CPU Test (Phase 1)", "REJECTED_TYPE", f"Document type is {doc_type}", bu_number, submitter_name, processing_id, InvoiceData())
            if os.path.exists(sidecar): os.remove(sidecar)
            return

        if p1_data.contains_multiple_invoices:
            print(f"  [!] Multiple invoices detected. Generating split manifest...")
            manifest_prompt = (
                f"Analyze this raw document text from a {total_pages}-page PDF: \n\n{full_document_text}\n\n"
                "This document contains multiple invoices. Identify each distinct invoice. "
                "For each invoice, provide the 'vendor_name', the 'invoice_number', and a list of 'pages' (integers starting from 1) that belong to that invoice. "
                f"Make sure every page from 1 to {total_pages} is assigned to an invoice. "
                "Return strictly as JSON."
            )
            manifest_response = ollama.chat(
                model='qwen2.5',
                messages=[{'role': 'user', 'content': manifest_prompt}],
                format=DocumentManifest.model_json_schema(),
                options={'temperature': 0, 'num_ctx': 8192}
            )
            try:
                manifest_data = DocumentManifest.model_validate_json(manifest_response['message']['content'])
            except Exception as e:
                raise RuntimeError(f"Split Manifest AI Hallucination Error: Model failed to return valid JSON. Error: {e}")
            
            dest_folder = os.path.join(BATCH_SPLIT_DIR, processing_id)
            os.makedirs(dest_folder, exist_ok=True)
            shutil.move(pdf_path, os.path.join(dest_folder, f"{processing_id}.pdf"))
            
            manifest_path = os.path.join(dest_folder, f"{processing_id}_MANIFEST.json")
            with open(manifest_path, "w", encoding="utf-8") as f:
                raw_json = manifest_data.model_dump_json(indent=4)
                collapsed_json = re.sub(r'\[\s+([\d,\s]+)\s+\]', lambda m: "[" + ", ".join(x.strip().strip(',') for x in m.group(1).split()) + "]", raw_json)
                f.write(collapsed_json)
                
            write_log(filename, "CPU Test (Split)", "ROUTED_TO_SPLIT", "Multiple invoices detected", bu_number, submitter_name, processing_id, InvoiceData())
            print(f"  [✓] Routed to _BATCH_SPLIT for human review.")
            return
    else:
        print("  [>] Phase 1: Split check bypassed by sidecar metadata.")

    # ---------------------------------------------------------
    # PHASE 2: Vision Extraction
    # ---------------------------------------------------------
    print(f"  [>] Phase 2: Passing to Vision Model for extraction...")
    
    vendor_hint = ""
    if extracted_vendor:
        normalized, is_known = normalize_vendor_name(extracted_vendor)
        if is_known:
            vendor_hint = get_rules_for_vendor(normalized)
            if vendor_hint:
                print(f"      - Injected Vendor Rules for {normalized}")

    global_aliases_str = get_global_field_aliases()
    
    tier2_prompt = (
        "Analyze this document image. "
        "First, determine the document_type. It must be strictly one of: 'INVOICE', 'STATEMENT', 'CREDIT', or 'UNKNOWN'. "
        "Extract the exact literal vendor name as 'extracted_vendor_name', invoice_date, invoice_number, invoice_total, and if present order_number, "
        "and customer_number. "
        f"{global_aliases_str} "
        "CRITICAL RULES: "
        "1. For 'invoice_number', use the vendor's invoice number. Do NOT use the transaction number (TRANS#), SALES#, "
        "terminal/store/register number, KEYED REFID, PO / LAR PO, sales order, or customer/account number. Keep any "
        "leading zeros. Set invoice_number_label to the exact label text next to the number you chose, and treat a "
        "'LAR PO' or 'PO' number as order_number. "
        "2. If you see multiple values that map to invoice_total, and one is $0.00, IGNORE the $0.00 value and extract the non-zero amount. "
        "3. Determine if the invoice total is handwritten. If the total is written by hand (pen, pencil, marker), set 'contains_handwritten_financials' to true. Ignore pre-printed or typed invoice numbers — only look at the financial amounts. "
        "4. HOW TO INTERPRET VENDOR RULES: Vendor rules are written by human users in plain English to help you locate values on the page. Treat them as helpful visual hints. However, you MUST still strictly obey the requested JSON schema. Do NOT invent new JSON keys based on user rules, and do NOT delete or omit standard JSON keys just because a user tells you to 'ignore' a visual label on the document. "
        "5. DO NOT dump raw unstructured text or multiple lines into any field. If a value is too long or you are unsure, leave it blank."
        "Return strictly as JSON."
    )
    
    if vendor_hint:
        tier2_prompt += f"\n\nVENDOR-SPECIFIC RULES FOR THIS INVOICE:\n{vendor_hint}"

    master_data = InvoiceData(is_urgent=is_urgent)
    print(f"      - Processing Page 1 visually...")
    start_time = time.time()
    pdf_page_to_image(pdf_path, 0, TEMP_IMAGE)
    VISION_SCHEMA = {
        "type": "object",
        "properties": {
            "document_type": {"type": "string"},
            "extracted_vendor_name": {"type": "string"},
            "invoice_date": {"type": "string"},
            "invoice_number": {"type": "string"},
            "invoice_number_label": {"type": "string"},
            "invoice_total": {"type": "string"},
            "order_number": {"type": "string"},
            "customer_number": {"type": "string"},
            "contains_handwritten_financials": {"type": "boolean"}
        },
        "required": [
            "document_type", "extracted_vendor_name", "invoice_date", 
            "invoice_number", "invoice_number_label", "invoice_total", 
            "order_number", "customer_number", "contains_handwritten_financials"
        ]
    }
    
    v_response = ollama.chat(
        model='qwen2.5vl',
        messages=[{'role': 'user', 'content': tier2_prompt, 'images': [TEMP_IMAGE]}],
        format=VISION_SCHEMA,
        options={'temperature': 0, 'num_ctx': 8192, 'num_predict': 1024}
    )
    
    try:
        v_data1 = InvoiceData.model_validate_json(v_response['message']['content'])
    except Exception as e:
        raise RuntimeError(f"Phase 2 Vision AI Hallucination Error: Model failed to return valid JSON schema. Error: {e}")
    for field in InvoiceData.model_fields:
        if getattr(master_data, field) is None and getattr(v_data1, field) is not None:
            setattr(master_data, field, getattr(v_data1, field))
            
    print(f"      - Page 1 Vision extraction complete in {time.time()-start_time:.1f}s.")
    
    sanitize_data(master_data)
    missing = check_missing_fields(master_data)
    
    if missing and total_pages > 1:
        last_page_idx = total_pages - 1
        print(f"      - Still missing {missing}. Processing Last Page ({total_pages}) visually...")
        start_time = time.time()
        pdf_page_to_image(pdf_path, last_page_idx, TEMP_IMAGE)
        
        v_response2 = ollama.chat(
            model='qwen2.5vl',
            messages=[{'role': 'user', 'content': tier2_prompt, 'images': [TEMP_IMAGE]}],
            format=VISION_SCHEMA,
            options={'temperature': 0, 'num_ctx': 8192, 'num_predict': 1024}
        )
        try:
            v_data2 = InvoiceData.model_validate_json(v_response2['message']['content'])
        except Exception as e:
            raise RuntimeError(f"Phase 2 Last Page Vision AI Hallucination Error: Model failed to return valid JSON schema. Error: {e}")
        for field in InvoiceData.model_fields:
            if getattr(master_data, field) is None and getattr(v_data2, field) is not None:
                setattr(master_data, field, getattr(v_data2, field))
                
        print(f"      - Last Page Vision extraction complete in {time.time()-start_time:.1f}s.")

    sanitize_data(master_data)
    missing = check_missing_fields(master_data)

    # ---------------------------------------------------------
    # FALLBACK: Late Vendor Rule Injection
    # ---------------------------------------------------------
    if not vendor_hint and master_data.extracted_vendor_name and missing:
        normalized, is_known = normalize_vendor_name(master_data.extracted_vendor_name)
        if is_known:
            late_hint = get_rules_for_vendor(normalized)
            if late_hint:
                print(f"      [!] Late Vendor identified: {normalized}. Re-running Vision with rules to find {missing}...")
                enhanced_prompt = tier2_prompt + f"\n\nVENDOR-SPECIFIC RULES FOR THIS INVOICE:\n{late_hint}"
                start_time = time.time()
                pdf_page_to_image(pdf_path, 0, TEMP_IMAGE)
                v_response3 = ollama.chat(
                    model='qwen2.5vl',
                    messages=[{'role': 'user', 'content': enhanced_prompt, 'images': [TEMP_IMAGE]}],
                    format=VISION_SCHEMA,
                    options={'temperature': 0, 'num_ctx': 8192, 'num_predict': 1024}
                )
                try:
                    v_data3 = InvoiceData.model_validate_json(v_response3['message']['content'])
                except Exception as e:
                    raise RuntimeError(f"Fallback Vision AI Hallucination Error: Model failed to return valid JSON schema. Error: {e}")
                for field in InvoiceData.model_fields:
                    if getattr(master_data, field) is None and getattr(v_data3, field) is not None:
                        setattr(master_data, field, getattr(v_data3, field))
                print(f"      - Fallback Vision extraction complete in {time.time()-start_time:.1f}s.")
                sanitize_data(master_data)

    apply_invoice_number_rules(master_data)
    
    # ---------------------------------------------------------
    # PHASE 3: Routing & Validation
    # ---------------------------------------------------------
    print(f"  [>] Phase 3: Validation and Routing...")
    
    # Check Document Type Reject Path
    if master_data.document_type not in ["INVOICE"]:
        dest_folder = os.path.join(ACTION_NEEDED_DIR, processing_id)
        os.makedirs(dest_folder, exist_ok=True)
        ticket_path = os.path.join(dest_folder, f"{processing_id}.ticket")
        
        print(f"      [!] AI rejected document as: {master_data.document_type}. Routing to human review.")
        with open(ticket_path, "w", encoding="utf-8") as f:
            f.write(f"--- MANUAL ACTION NEEDED (AI REJECTED) ---\n")
            f.write(f"File: {processing_id}.pdf\n")
            f.write(f"Document Type: {master_data.document_type}\n\n")
            f.write(f"The AI rejected this document because it classified it as a '{master_data.document_type}' rather than an 'INVOICE'.\n")
            f.write(f"Please review the document. If it needs to be processed, update the generated XML file and drop this folder onto the SQL shortcut.")
            
        generate_laserfiche_xml(master_data, bu_number, submitter_name, os.path.join(dest_folder, f"{processing_id}.xml"), processing_id)
        shutil.move(pdf_path, os.path.join(dest_folder, f"{processing_id}.pdf"))
        write_log(filename, "CPU Test", "ACTION_NEEDED", f"Rejected as {master_data.document_type}", bu_number, submitter_name, processing_id, master_data)
        if os.path.exists(sidecar): os.remove(sidecar)
        return

    # Check Handwritten Financials Reject Path
    if getattr(master_data, 'contains_handwritten_financials', False):
        dest_folder = os.path.join(LOW_CONFIDENCE_REVIEW_DIR, processing_id)
        os.makedirs(dest_folder, exist_ok=True)
        ticket_path = os.path.join(dest_folder, f"{processing_id}.ticket")
        
        print(f"      [!] AI detected handwritten financial amounts. Routing to human review.")
        with open(ticket_path, "w", encoding="utf-8") as f:
            f.write(f"--- MANUAL ACTION NEEDED (HANDWRITTEN FINANCIALS) ---\n")
            f.write(f"File: {processing_id}.pdf\n\n")
            f.write(f"The AI detected handwritten financial amounts (subtotal, tax, or total). These must be manually verified to ensure accuracy.\n")
            f.write(f"Please review the document, verify the values in the XML file, and drop this folder onto the SQL shortcut.")
            
        generate_laserfiche_xml(master_data, bu_number, submitter_name, os.path.join(dest_folder, f"{processing_id}.xml"), processing_id)
        shutil.move(pdf_path, os.path.join(dest_folder, f"{processing_id}.pdf"))
        
        # Add sidecar data for GUI rule entry
        rule_sidecar = {
            "vendor_name": master_data.vendor_name or master_data.extracted_vendor_name or "",
            "existing_vendor_rules": get_rules_for_vendor(master_data.vendor_name or master_data.extracted_vendor_name or "") if master_data.vendor_name else "",
            "new_vendor_rule": ""
        }
        with open(os.path.join(dest_folder, f"{processing_id}.json"), "w", encoding="utf-8") as sf:
            json.dump(rule_sidecar, sf, indent=4)
            
        write_log(filename, "CPU Test", "LOW_CONFIDENCE", "Handwritten financials detected", bu_number, submitter_name, processing_id, master_data)
        if os.path.exists(sidecar): os.remove(sidecar)
        return

    # Vendor Normalization
    normalized_name, is_known = normalize_vendor_name(master_data.extracted_vendor_name)
    if is_known:
        master_data.vendor_name = normalized_name
    elif master_data.extracted_vendor_name:
        print(f"      [!] Unknown Vendor: '{master_data.extracted_vendor_name}'. Routing to Vendor Review.")
        dest_folder = os.path.join(VENDOR_REVIEW_DIR, processing_id)
        os.makedirs(dest_folder, exist_ok=True)
        shutil.move(pdf_path, os.path.join(dest_folder, f"{processing_id}.pdf"))

        review_payload = {
            "FileName": filename,
            "Submitter": submitter_name,
            "BU": bu_number,
            "submitter": submitter_name,
            "bu": bu_number,
            "ExtractedVendorName": master_data.extracted_vendor_name,
            "VendorName": master_data.extracted_vendor_name,
            "NormalizedVendor": "",
            "InvoiceNumber": master_data.invoice_number,
            "InvoiceTotal": master_data.invoice_total,
            "InvoiceDate": master_data.invoice_date,
            "OrderNumber": master_data.order_number,
            "CustomerNumber": master_data.customer_number,
            "DocumentType": master_data.document_type,
            "ExtractedMetadata": master_data.model_dump_json(),
            "Status": "Vendor Review",
            "ErrorMessage": f"Unknown vendor: {master_data.extracted_vendor_name}",
            "InvoiceConcatID": processing_id
        }
        with open(os.path.join(dest_folder, f"{processing_id}.json"), "w", encoding="utf-8") as sf:
            json.dump(review_payload, sf, indent=4)

        generate_laserfiche_xml(master_data, bu_number, submitter_name, os.path.join(dest_folder, f"{processing_id}.xml"), processing_id)
        
        review_data = {
            "extracted_name": master_data.extracted_vendor_name,
            "suggested_normalized_name": ""
        }
        with open(os.path.join(dest_folder, f"{processing_id}_LEARN.json"), "w", encoding="utf-8") as f:
            json.dump(review_data, f, indent=4)
            
        write_log(filename, "CPU Test", "ROUTED_TO_LEARN", f"Unknown vendor: {master_data.extracted_vendor_name}", bu_number, submitter_name, processing_id, master_data)
        return

    # Missing Fields Check
    missing = check_missing_fields(master_data)
    if missing:
        dest_folder = os.path.join(ACTION_NEEDED_DIR, processing_id)
        os.makedirs(dest_folder, exist_ok=True)
        ticket_path = os.path.join(dest_folder, f"{processing_id}.ticket")
        print(f"      [!] Vision Model failed to find: {missing}. Routing to human review.")
        
        with open(ticket_path, "w", encoding="utf-8") as f:
            f.write(f"--- MANUAL ACTION NEEDED ---\n")
            f.write(f"File: {processing_id}.pdf\n")
            f.write(f"Document Type: {master_data.document_type}\n\n")
            f.write(f"The AI failed to locate the following required fields:\n")
            for m in missing:
                f.write(f"- {m}\n")
            f.write("\nPlease update the associated XML file with this information before importing into Laserfiche.")
        
        generate_laserfiche_xml(master_data, bu_number, submitter_name, os.path.join(dest_folder, f"{processing_id}.xml"), processing_id)
        shutil.move(pdf_path, os.path.join(dest_folder, f"{processing_id}.pdf"))
        
        # Add sidecar data for GUI rule entry
        rule_sidecar = {
            "vendor_name": master_data.vendor_name or master_data.extracted_vendor_name or "",
            "existing_vendor_rules": get_rules_for_vendor(master_data.vendor_name or master_data.extracted_vendor_name or "") if master_data.vendor_name else "",
            "new_vendor_rule": ""
        }
        with open(os.path.join(dest_folder, f"{processing_id}.json"), "w", encoding="utf-8") as sf:
            json.dump(rule_sidecar, sf, indent=4)
            
        write_log(filename, "CPU Test", "ACTION_NEEDED", f"Missing: {missing}", bu_number, submitter_name, processing_id, master_data)
        if os.path.exists(sidecar): os.remove(sidecar)
        return

    # Success Routing
    if not is_high_confidence:
        dest_folder = os.path.join(LOW_CONFIDENCE_REVIEW_DIR, processing_id)
        os.makedirs(dest_folder, exist_ok=True)
        print(f"  [?] Extracted, but Low Confidence. Routing to Low Confidence Review.")
        
        generate_laserfiche_xml(master_data, bu_number, submitter_name, os.path.join(dest_folder, f"{processing_id}.xml"), processing_id)
        shutil.move(pdf_path, os.path.join(dest_folder, f"{processing_id}.pdf"))
        
        # Add sidecar data for GUI rule entry
        rule_sidecar = {
            "vendor_name": master_data.vendor_name or master_data.extracted_vendor_name or "",
            "existing_vendor_rules": get_rules_for_vendor(master_data.vendor_name or master_data.extracted_vendor_name or "") if master_data.vendor_name else "",
            "new_vendor_rule": ""
        }
        with open(os.path.join(dest_folder, f"{processing_id}.json"), "w", encoding="utf-8") as sf:
            json.dump(rule_sidecar, sf, indent=4)
            
        write_log(filename, "CPU Test", "LOW_CONFIDENCE", "Routed for manual check", bu_number, submitter_name, processing_id, master_data)
        if os.path.exists(sidecar): os.remove(sidecar)
    else:
        dest_folder = os.path.join(SQL_QUEUE_DIR, processing_id)
        os.makedirs(dest_folder, exist_ok=True)
        print(f"  [✓] Fully Extracted! Routing to SQL Queue.")
        
        generate_laserfiche_xml(master_data, bu_number, submitter_name, os.path.join(dest_folder, f"{processing_id}.xml"), processing_id)
        shutil.move(pdf_path, os.path.join(dest_folder, f"{processing_id}.pdf"))
        write_log(filename, "CPU Test", "SUCCESS", "", bu_number, submitter_name, processing_id, master_data)
        if os.path.exists(sidecar): os.remove(sidecar)

def scan_directories():
    from pipeline_common import REPROCESS_QUEUE_DIR, AI_QUEUE_DIR
    
    # 1. Reprocess Queue (Highest Priority - Immediate Error Fixes)
    if os.path.exists(REPROCESS_QUEUE_DIR):
        for folder_name in os.listdir(REPROCESS_QUEUE_DIR):
            folder_path = os.path.join(REPROCESS_QUEUE_DIR, folder_name)
            if os.path.isdir(folder_path):
                if os.path.exists(os.path.join(folder_path, REPROCESS_ERROR_MARKER)):
                    continue

                pdf_files = [f for f in os.listdir(folder_path) if f.lower().endswith(".pdf")]
                if not pdf_files:
                    try: shutil.rmtree(folder_path)
                    except Exception: pass
                    continue
                
                pdf_file = pdf_files[0]
                pdf_path = os.path.join(folder_path, pdf_file)
                if not is_file_stable(pdf_path): continue
                try:
                    process_cpu_hybrid(pdf_path, "Unknown", "Internal_Retrying", is_urgent=True)
                    if os.path.exists(folder_path):
                        shutil.rmtree(folder_path)
                except Exception as e:
                    print(f"    [!] Error in reprocess queue: {e}")
                    mark_reprocess_error(folder_path, folder_name, pdf_path, e)

    # 2. Main AI Queue (Managed by Watcher)
    if not os.path.exists(AI_QUEUE_DIR):
        return
        
    job_folders = [f for f in os.listdir(AI_QUEUE_DIR) if os.path.isdir(os.path.join(AI_QUEUE_DIR, f))]
    
    urgent_queue = []
    standard_queue = []
    
    # Build queues
    for folder_name in job_folders:
        folder_path = os.path.join(AI_QUEUE_DIR, folder_name)
        if os.path.exists(os.path.join(folder_path, AI_QUEUE_ERROR_MARKER)):
            continue

        ticket_path = os.path.join(folder_path, "job_ticket.json")
        
        pdf_files = [f for f in os.listdir(folder_path) if f.lower().endswith(".pdf")]
        if not pdf_files:
            if folder_age_seconds(folder_path) >= STALE_QUEUE_FOLDER_SECONDS:
                mark_ai_queue_error(folder_path, folder_name, "AI queue folder has no PDF after waiting for it to finish spooling.")
            continue
            
        pdf_path = os.path.join(folder_path, pdf_files[0])
        
        if not os.path.exists(ticket_path):
            if folder_age_seconds(folder_path) >= STALE_QUEUE_FOLDER_SECONDS:
                mark_ai_queue_error(folder_path, folder_name, "AI queue folder has a PDF but no job_ticket.json.", pdf_path=pdf_path)
            continue

        try:
            with open(ticket_path, "r", encoding="utf-8") as f:
                ticket = json.load(f)
            
            is_urgent = ticket.get("is_urgent", False)
            timestamp = ticket.get("timestamp", "")
            
            job_data = {
                "pdf_path": pdf_path,
                "folder_path": folder_path,
                "bu_number": ticket.get("bu_number", "Unknown"),
                "submitter_name": ticket.get("submitter_name", "Unknown"),
                "is_urgent": is_urgent,
                "timestamp": timestamp,
                "processing_id": ticket.get("processing_id", folder_name)
            }
            
            if is_urgent:
                urgent_queue.append(job_data)
            else:
                standard_queue.append(job_data)
        except Exception as e:
            print(f"    [!] Error reading job ticket {ticket_path}: {e}")
            if folder_age_seconds(folder_path) >= STALE_QUEUE_FOLDER_SECONDS:
                mark_ai_queue_error(folder_path, folder_name, "AI queue folder has an unreadable job_ticket.json.", error=e, pdf_path=pdf_path)
                
    # Sort queues by timestamp (oldest first)
    urgent_queue.sort(key=lambda x: x["timestamp"])
    standard_queue.sort(key=lambda x: x["timestamp"])
    
    master_queue = urgent_queue + standard_queue
    
    # Process queue
    for job in master_queue:
        pdf_path = job["pdf_path"]
        folder_path = job["folder_path"]
        bu_number = job["bu_number"]
        submitter_name = job["submitter_name"]
        is_urgent = job["is_urgent"]
        processing_id = job["processing_id"]
        filename = os.path.basename(pdf_path)
        name_only, _ = os.path.splitext(filename)
        
        try:
            process_cpu_hybrid(pdf_path, bu_number, submitter_name, is_urgent=is_urgent)
            
            # Clean up the AI Queue folder after successful processing (or successful routing)
            if os.path.exists(folder_path):
                shutil.rmtree(folder_path)
                
        except Exception as e:
            print(f"    [!] Critical error processing {filename}: {e}")
            crash_id = f"ERROR_{bu_number}.{datetime.now().strftime('%Y%m%d_%H%M%S')}.{name_only}"
            write_log(filename, "CPU Test", "ERROR", str(e), bu_number, submitter_name, crash_id, None)
            
            dest_folder = os.path.join(ERROR_QUEUE_DIR, crash_id)
            os.makedirs(dest_folder, exist_ok=True)
            
            with open(os.path.join(dest_folder, f"{crash_id}.ticket"), "w", encoding="utf-8") as f:
                f.write(f"--- FATAL SYSTEM CRASH ---\n")
                f.write(f"File: {crash_id}.pdf\n\n")
                f.write(f"The pipeline experienced a catastrophic crash while processing this document.\n")
                f.write(f"Error Details: {str(e)}\n\n")
                f.write(f"This could be due to a corrupt PDF, an AI server disconnect, or an unexpected schema validation failure.\n")
            
            cleanup_crashed_folder = True
            if os.path.exists(pdf_path):
                try:
                    shutil.move(pdf_path, os.path.join(dest_folder, f"{crash_id}.pdf"))
                except Exception as move_error:
                    cleanup_crashed_folder = False
                    print(f"    [!] Failed to move crashed PDF to Action Needed: {move_error}")
                    mark_ai_queue_error(folder_path, folder_name, "AI worker crashed and could not move the PDF to Action Needed.", error=move_error, pdf_path=pdf_path)
                    with open(os.path.join(dest_folder, f"{crash_id}.ticket"), "a", encoding="utf-8") as f:
                        f.write(f"\n\nThe PDF could not be moved automatically and remains in the original queue folder.\n")
                        f.write(f"Move Error: {move_error}\n")
                
            # Clean up the AI Queue folder if it crashed
            if cleanup_crashed_folder and os.path.exists(folder_path):
                try:
                    shutil.rmtree(folder_path)
                except Exception:
                    pass

if __name__ == "__main__":
    # Prepare the machine before any work: directories, shortcuts, alias
    # sync. Import alone does none of it.
    bootstrap()

    from pipeline_common import AI_QUEUE_DIR
    print(f"Monitoring '{AI_QUEUE_DIR}' for AI Extraction Jobs...")
    
    try:
        while True:
            scan_directories()
            time.sleep(2)
    except KeyboardInterrupt:
        print("\nWorker stopped.")
