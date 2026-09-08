import os
import time
import shutil
import json

# Import shared core FIRST so it auto-installs missing dependencies
from pipeline_common import BASE_DIR, BATCH_SPLIT_DIR, READY_TO_SPLIT_DIR, SPLIT_FOLDER_NAME, REPROCESS_QUEUE_DIR, ERROR_QUEUE_DIR, bootstrap

import fitz

def parse_page_range(pages_input):
    """
    Parses various page range formats into a list of integers.
    Supports:
      - A list of integers: [1, 2, 3]
      - A string: "1-3, 5, 7-10"
      - A list containing mixed integers and strings: [1, "3-5", 7]
    """
    if isinstance(pages_input, list):
        resolved_pages = []
        for item in pages_input:
            if isinstance(item, int):
                resolved_pages.append(item)
            elif isinstance(item, str):
                resolved_pages.extend(parse_range_string(item))
        return sorted(list(set(resolved_pages)))
    elif isinstance(pages_input, str):
        return parse_range_string(pages_input)
    elif isinstance(pages_input, int):
        return [pages_input]
    return []

def parse_range_string(s):
    resolved = []
    parts = s.split(',')
    for part in parts:
        part = part.strip()
        if not part: continue
        if '-' in part:
            try:
                start, end = part.split('-')
                resolved.extend(range(int(start), int(end) + 1))
            except ValueError:
                pass
        else:
            try:
                resolved.append(int(part))
            except ValueError:
                pass
    return resolved


def run_batch_splitter():
    if not os.path.exists(READY_TO_SPLIT_DIR):
        return

    for folder_name in os.listdir(READY_TO_SPLIT_DIR):
        folder_path = os.path.join(READY_TO_SPLIT_DIR, folder_name)
        if os.path.isdir(folder_path):
            manifest_files = [f for f in os.listdir(folder_path) if f.endswith("_MANIFEST.json")]
            if not manifest_files:
                # Clean up empty folder
                try:
                    shutil.rmtree(folder_path)
                except Exception:
                    pass
                continue
                
            manifest_file = manifest_files[0]
            manifest_path = os.path.join(folder_path, manifest_file)
            base_name = folder_name
            pdf_name = f"{base_name}.pdf"

            pdf_path = os.path.join(folder_path, pdf_name)
            if not os.path.exists(pdf_path):
                print(f"[!] Original PDF {pdf_name} not found in folder {folder_name}. Cannot split.")
                continue

            try:
                with open(manifest_path, 'r', encoding='utf-8') as f:
                    manifest = json.load(f)
            except Exception as e:
                print(f"[!] Error reading manifest {manifest_file}: {e}")
                
                # Write syntax error details inside the folder
                err_file_path = os.path.join(folder_path, "ERROR_MANIFEST_SYNTAX.txt")
                try:
                    with open(err_file_path, "w", encoding="utf-8") as ef:
                        ef.write(f"JSON Syntax Error in manifest file:\n\n{str(e)}\n\n")
                        ef.write("Please correct the JSON syntax in the _MANIFEST.json file and move this folder back to split queue.\n")
                except Exception:
                    pass
                
                # Route folder back to BATCH_SPLIT_DIR for correction
                dest_back = os.path.join(BATCH_SPLIT_DIR, folder_name)
                try:
                    if os.path.exists(dest_back):
                        shutil.rmtree(dest_back)
                    shutil.move(folder_path, dest_back)
                    print(f"    [!] Routed folder back to _BATCH_SPLIT for manual correction: {dest_back}")
                except Exception as ex:
                    print(f"    [!] Failed to route folder back: {ex}")
                continue

            try:
                print(f"\n[SPLITTER] Processing approved manifest folder for {base_name}...")
                doc = fitz.open(pdf_path)

                parts = base_name.split('.')
                bu_number = parts[0] if len(parts) > 0 else "Unknown"
                submitter_name = parts[2] if len(parts) > 2 else "UnknownUser" # Best effort sub-folder mapping

                for idx, inv in enumerate(manifest.get('invoices', [])):
                    pages_raw = inv.get('pages', [])
                    pages = parse_page_range(pages_raw)
                    if not pages: continue
                    
                    inv_num = inv.get('invoice_number', f'part_{idx+1}')
                    inv_num_clean = "".join(c for c in inv_num if c.isalnum() or c in ('-', '_')).strip()
                    if not inv_num_clean: inv_num_clean = f'part_{idx+1}'
                    
                    split_id = f"{base_name}_SPLIT_{inv_num_clean}"
                    split_folder = os.path.join(REPROCESS_QUEUE_DIR, split_id)
                    os.makedirs(split_folder, exist_ok=True)
                    
                    new_pdf_path = os.path.join(split_folder, f"{split_id}.pdf")
                    
                    new_doc = fitz.open()
                    for p in pages:
                        page_idx = p - 1 # Manifest is 1-based, PyMuPDF is 0-based
                        if 0 <= page_idx < len(doc):
                            new_doc.insert_pdf(doc, from_page=page_idx, to_page=page_idx)
                    
                    new_doc.save(new_pdf_path)
                    new_doc.close()
                    
                    # Create sidecar inside split folder to preserve BU and Submitter
                    with open(os.path.join(split_folder, f"{split_id}.json"), "w", encoding="utf-8") as sf:
                        json.dump({"bu": bu_number, "submitter": submitter_name, "bypass_split": True}, sf)

                    print(f"    [✓] Created split batch: {split_id}")
                
                doc.close()
                shutil.rmtree(folder_path)
                print(f"    [✓] Splitting complete. Batch folder removed and routed to hidden queue.")
                
            except Exception as e:
                print(f"    [!] Error splitting batch folder {base_name}: {e}")
                
                # Move folder to the technical error queue.
                error_dest = os.path.join(ERROR_QUEUE_DIR, f"ERROR_{folder_name}")
                try:
                    if os.path.exists(error_dest):
                        shutil.rmtree(error_dest)
                    shutil.move(folder_path, error_dest)
                    print(f"    [!] Routed crashed split batch to: {error_dest}")
                except Exception as ex:
                    print(f"    [!] Failed to route crashed split batch: {ex}")

if __name__ == "__main__":
    # Prepare the machine before any work: directories, shortcuts, alias
    # sync. Import alone does none of it.
    bootstrap()

    print(f"Monitoring '{READY_TO_SPLIT_DIR}' (BATCH SPLITTER) for approved manifests...")
    try:
        while True:
            run_batch_splitter()
            time.sleep(5)
    except KeyboardInterrupt:
        print("\nBatch Splitter stopped.")
