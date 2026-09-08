import os
import time
import json
import shutil
from datetime import datetime

# Import shared core FIRST so it auto-installs missing dependencies
from pipeline_common import (
    SQL_QUEUE_DIR, SQL_FAILED_DIR, ACTION_NEEDED_DIR, PROCESSED_DIR,
    READY_TO_DELETE_DIR, DELETED_DIR, VENDOR_REVIEW_DIR,
    insert_sql_record, archive_batch, InvoiceData, generate_laserfiche_xml, sanitize_data,
    bootstrap, PAYLOAD_SUFFIX,
)

import pyodbc

def find_payload(folder_path):
    """The batch's SQL payload, by name, or None.

    A batch folder holds several JSON files -- the payload, the vendor-rule
    sidecar, the learn sidecar, a claim marker. Taking whichever one the
    filesystem listed first meant a sidecar could be read as an invoice and
    the real payload never inserted. Only this name is a payload. Step 1.3.
    """
    for file_name in sorted(os.listdir(folder_path)):
        if file_name.endswith(PAYLOAD_SUFFIX):
            return file_name
    return None

def move_folder_to_failed(folder_path, folder_name):
    if not os.path.exists(folder_path):
        print(f"    [i] SQL queue folder already moved or removed: {folder_path}")
        return

    failed_dest = os.path.join(SQL_FAILED_DIR, folder_name)
    if os.path.exists(failed_dest):
        shutil.rmtree(failed_dest)

    try:
        shutil.move(folder_path, failed_dest)
        print(f"    [!] Moved folder to SQL failed queue: {failed_dest}")
    except FileNotFoundError:
        print(f"    [i] SQL queue folder disappeared before it could be moved to failed: {folder_path}")

def run_sql_worker():
    if not os.path.exists(SQL_QUEUE_DIR):
        return

    for folder_name in os.listdir(SQL_QUEUE_DIR):
        folder_path = os.path.join(SQL_QUEUE_DIR, folder_name)
        if os.path.isdir(folder_path):
            # Find the JSON payload file in the subfolder, by name.
            try:
                json_file = find_payload(folder_path)
            except FileNotFoundError:
                print(f"    [i] SQL queue folder disappeared before it could be read: {folder_path}")
                continue

            if json_file is None:
                # The AI worker creates the folder, XML and PDF before the
                # payload, so a folder without one is either still being
                # written or is missing it. Leave it where it is either way --
                # this loop must never delete a batch it could not read.
                print(f"    [i] Skipping {folder_name}: no *{PAYLOAD_SUFFIX} payload in the folder.")
                continue

            filepath = os.path.join(folder_path, json_file)
            
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    payload = json.load(f)
            except Exception as e:
                print(f"[!] SQL Worker Error: Could not read {json_file} in folder {folder_name}: {e}")
                
                # Write syntax error details inside the folder
                err_file_path = os.path.join(folder_path, "ERROR_SQL_SYNTAX.txt")
                try:
                    with open(err_file_path, "w", encoding="utf-8") as ef:
                        ef.write(f"JSON Syntax Error in SQL payload file:\n\n{str(e)}\n\n")
                        ef.write("Please correct the JSON syntax in the _READY_FOR_SQL.json file and move this folder back to SQL queue.\n")
                except Exception:
                    pass
                
                # Route folder back to ACTION_NEEDED_DIR for correction
                dest_back = os.path.join(ACTION_NEEDED_DIR, folder_name)
                try:
                    if os.path.exists(dest_back):
                        shutil.rmtree(dest_back)
                    shutil.move(folder_path, dest_back)
                    print(f"    [!] Routed folder back to _ACTION_NEEDED for manual correction: {dest_back}")
                except Exception as ex:
                    print(f"    [!] Failed to route folder back: {ex}")
                continue
                
            processing_id = payload.get("InvoiceConcatID", folder_name)
            
            try:
                print(f"\n[SQL WORKER] Processing batch folder {folder_name}...")
                
                # The XML is regenerated from the payload that is about to be
                # inserted, so Laserfiche and the database cannot disagree.
                # This used to run only for "manual fix" batches, told apart by
                # their filename -- a distinction step 1.3 removed by giving
                # every payload one name. It is also not a distinction that
                # held: Rails writes a hand-corrected vendor-review payload
                # with Status "SUCCESS".
                print(f"    [i] Regenerating Laserfiche XML from the payload...")
                corrected_data = InvoiceData(
                    extracted_vendor_name=payload.get("VendorName"),
                    vendor_name=payload.get("VendorName"),
                    invoice_date=payload.get("InvoiceDate"),
                    invoice_number=payload.get("InvoiceNumber"),
                    invoice_total=payload.get("InvoiceTotal"),
                    order_number=payload.get("OrderNumber"),
                    subtotal=payload.get("Subtotal"),
                    sales_tax=payload.get("SalesTax"),
                    customer_number=payload.get("CustomerNumber"),
                    # Without this the XML's TemplateName fell back to
                    # "Unknown" on every regenerated batch.
                    document_type=payload.get("DocumentType")
                )
                corrected_data = sanitize_data(corrected_data)
                xml_path = os.path.join(folder_path, f"{processing_id}.xml")
                generate_laserfiche_xml(corrected_data, payload.get("BU"), payload.get("Submitter"), xml_path, processing_id)
                print(f"    [✓] Laserfiche XML updated successfully.")
                
                # Refresh ProcessedTimestamp to current time upon database insertion
                payload["ProcessedTimestamp"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                
                # 1. Update Tracking table (SQL_LOGGING)
                try:
                    payload["Status"] = "SUCCESS"  # Force status to SUCCESS in database
                    insert_sql_record("SQL_LOGGING", payload)
                    print(f"    [✓] Tracking inserted into SQL_LOGGING.")
                except pyodbc.IntegrityError:
                    pass # Ignore duplicate tracking
                except Exception as e:
                    print(f"    [!] Tracking insert error: {e}")
                
                # 2. Update Billing table (SQL_BILLING)
                insert_sql_record("SQL_BILLING", payload)
                print(f"    [✓] Billing inserted.")
                
                # 3. Archive the batch folder
                archive_batch(processing_id, payload.get("BU"), payload.get("Submitter"), folder_path)
                
                # 4. Move PDF and XML flat to ProcessedDir
                pdf_src = os.path.join(folder_path, f"{processing_id}.pdf")
                xml_src = os.path.join(folder_path, f"{processing_id}.xml")
                
                if os.path.exists(pdf_src):
                    shutil.move(pdf_src, os.path.join(PROCESSED_DIR, f"{processing_id}.pdf"))
                if os.path.exists(xml_src):
                    shutil.move(xml_src, os.path.join(PROCESSED_DIR, f"{processing_id}.xml"))
                
                # 5. Clean up subfolders
                shutil.rmtree(folder_path)
                
                # Clean up corresponding Action Needed folder if it was moved/copied
                old_action_folder = os.path.join(ACTION_NEEDED_DIR, processing_id)
                if os.path.exists(old_action_folder):
                    try:
                        shutil.rmtree(old_action_folder)
                    except Exception:
                        pass
                        
                print(f"    [✓] Processing complete. Batch folder removed.")
                
            except pyodbc.IntegrityError as e:
                if '2601' in str(e) or '2627' in str(e):
                    print(f"    [i] Duplicate billing key detected for {json_file}. Record already exists. Discarding batch.")
                    # Still archive and clean up to prevent infinite loops, and move PDF to ProcessedDir just in case
                    archive_batch(processing_id, payload.get("BU"), payload.get("Submitter"), folder_path)
                    pdf_src = os.path.join(folder_path, f"{processing_id}.pdf")
                    xml_src = os.path.join(folder_path, f"{processing_id}.xml")
                    if os.path.exists(pdf_src):
                        shutil.move(pdf_src, os.path.join(PROCESSED_DIR, f"{processing_id}.pdf"))
                    if os.path.exists(xml_src):
                        shutil.move(xml_src, os.path.join(PROCESSED_DIR, f"{processing_id}.xml"))
                    shutil.rmtree(folder_path)
                else:
                    print(f"    [!] IntegrityError on {json_file}: {e}. Moving to Failed queue.")
                    move_folder_to_failed(folder_path, folder_name)
            except Exception as e:
                print(f"    [!] SQL Insert Failed for {json_file}: {e}. Moving to Failed queue.")
                move_folder_to_failed(folder_path, folder_name)

def run_delete_worker():
    if not os.path.exists(READY_TO_DELETE_DIR):
        return

    for folder_name in os.listdir(READY_TO_DELETE_DIR):
        folder_path = os.path.join(READY_TO_DELETE_DIR, folder_name)
        if os.path.isdir(folder_path):
            print(f"\n[DELETE WORKER] Processing deleted batch folder {folder_name}...")
            
            # Try to load metadata from any JSON file inside the folder
            bu_number = "Unknown"
            submitter_name = "UnknownUser"
            payload_file = find_payload(folder_path)
            if payload_file:
                filepath = os.path.join(folder_path, payload_file)
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        payload = json.load(f)
                    bu_number = payload.get("BU", payload.get("bu", "Unknown"))
                    submitter_name = payload.get("Submitter", payload.get("submitter", "UnknownUser"))
                except Exception:
                    pass
            
            # If JSON metadata parsing failed, extract BU from the folder name
            if bu_number == "Unknown":
                parts = folder_name.split('.')
                bu_number = parts[0] if len(parts) > 0 else "Unknown"
                submitter_name = parts[2] if len(parts) > 2 else "UnknownUser"
                
            # Perform archiving to DELETED_DIR
            try:
                date_str = datetime.now().strftime("%Y-%m-%d")
                bu_clean = "".join(c for c in str(bu_number) if c.isalnum() or c in (' ', '-', '_')).strip()
                submitter_clean = "".join(c for c in str(submitter_name) if c.isalnum() or c in (' ', '-', '_')).strip()
                if not bu_clean: bu_clean = "UnknownBU"
                if not submitter_clean: submitter_clean = "UnknownUser"
                
                target_dest_dir = os.path.join(DELETED_DIR, bu_clean, submitter_clean, date_str, folder_name)
                os.makedirs(target_dest_dir, exist_ok=True)
                
                # Move all files
                for file in os.listdir(folder_path):
                    src_file = os.path.join(folder_path, file)
                    if os.path.isfile(src_file):
                        shutil.move(src_file, os.path.join(target_dest_dir, file))
                        
                print(f"    [✓] Batch moved to deleted archive: {target_dest_dir}")
                
                # Clean up corresponding Action Needed / Vendor Review folders if they still exist
                for parent_dir in [ACTION_NEEDED_DIR, VENDOR_REVIEW_DIR, SQL_QUEUE_DIR]:
                    old_folder = os.path.join(parent_dir, folder_name)
                    if os.path.exists(old_folder):
                        try:
                            shutil.rmtree(old_folder)
                        except Exception:
                            pass
                            
                # Delete folder from ReadyToDeleteDir
                shutil.rmtree(folder_path)
                print(f"    [✓] Temporary delete queue folder removed.")
            except Exception as e:
                print(f"    [!] Deletion / Archiving failed for {folder_name}: {e}")

if __name__ == "__main__":
    # Prepare the machine before any work: directories, shortcuts, alias
    # sync. Import alone does none of it.
    bootstrap()

    print(f"Monitoring '{SQL_QUEUE_DIR}' (SQL WORKER) for ready invoices and deletions...")
    try:
        while True:
            run_sql_worker()
            run_delete_worker()
            time.sleep(5)  
    except KeyboardInterrupt:
        print("\nSQL Worker stopped.")
