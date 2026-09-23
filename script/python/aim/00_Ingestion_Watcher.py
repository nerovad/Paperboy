import os
import time
import shutil
import json
import hashlib
from datetime import datetime
from PIL import Image
from pipeline_common import (BASE_DIR, AI_QUEUE_DIR, ERROR_QUEUE_DIR, is_file_stable, bootstrap, env,
                             SPOOL_STATE_DIR as pipeline_spool_state_dir)
from state_store import record_state, invoice_facts

ACTOR = "00_ingestion_watcher"

# Wait time to ensure file is fully copied over network
STABLE_WAIT_TIME = 2
SPOOL_RETRY_SECONDS = 900
SPOOL_STATE_DIR = pipeline_spool_state_dir

# The subfolder of a Budget Unit that feeds its shared queue, which anyone with
# that BU can see. Named by configuration, and it must not begin with "_": the
# walk below skips such folders. Plan step 8b.0.
SHARED_FOLDER_NAME = env('AIM_SHARED_FOLDER_NAME')

# What each Budget Unit folder says about itself. Shipped beside the workers
# and copied into a BU folder that has none; never over one that exists, so a
# README someone has edited is theirs.
BU_README_NAME = "README - How to submit invoices.txt"
BU_README_TEMPLATE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "BU_FOLDER_README.txt")


def route_for(relative_path):
    """Who a file in the watch tree belongs to, or None when it belongs to nobody.

        <BU>/<Name>/...     that person's queue      (the default)
        <BU>/SHARED/...     the BU's shared queue
        <BU>/<file>         nobody -- loose files at the BU root are ignored

    Decided with Joshua 2026-09-23. There is no HIGH PRIORITY folder any more,
    and no urgency: a folder of that name would simply be someone's name.
    """
    if relative_path in ("", "."):
        return None

    parts = relative_path.split(os.sep)
    if len(parts) < 2:
        return None

    bu_number, folder = parts[0], parts[1]
    if folder.casefold() == SHARED_FOLDER_NAME.casefold():
        return {"bu_number": bu_number, "owner": None, "queue": "shared"}
    return {"bu_number": bu_number, "owner": folder, "queue": "person"}


def place_bu_readmes():
    """Give every Budget Unit folder the README that explains its layout."""
    if not os.path.isfile(BU_README_TEMPLATE):
        return
    try:
        entries = os.listdir(BASE_DIR)
    except OSError as e:
        print(f"  [!] Could not list {BASE_DIR} to place READMEs: {e}")
        return

    for name in entries:
        folder = os.path.join(BASE_DIR, name)
        if name.startswith(("_", ".")) or not os.path.isdir(folder):
            continue
        readme = os.path.join(folder, BU_README_NAME)
        if os.path.exists(readme):
            continue
        try:
            shutil.copyfile(BU_README_TEMPLATE, readme)
        except OSError as e:
            print(f"  [!] Could not place a README in {folder}: {e}")

def safe_folder_name(value):
    return "".join(c for c in value if c.isalnum() or c in (" ", "-", "_", ".", "#", "$", "(", ")")).strip()[:140]

def write_ingestion_error_ticket(error_id, title, source_path, details, dest_folder=None):
    error_folder = os.path.join(ERROR_QUEUE_DIR, safe_folder_name(error_id))
    os.makedirs(error_folder, exist_ok=True)

    ticket_path = os.path.join(error_folder, f"{safe_folder_name(error_id)}.ticket")
    with open(ticket_path, "w", encoding="utf-8") as f:
        f.write(f"--- INGESTION ERROR ({title}) ---\n")
        f.write(f"Source file: {source_path}\n")
        if dest_folder:
            f.write(f"AI Queue folder: {dest_folder}\n")
        f.write(f"\nDetails: {details}\n")
        f.write("\nThis is a technical pipeline cleanup item, not an invoice review item.\n")

    with open(os.path.join(error_folder, "error.json"), "w", encoding="utf-8") as f:
        json.dump({
            "title": title,
            "source_path": source_path,
            "dest_folder": dest_folder,
            "details": str(details),
            "timestamp": datetime.now().isoformat()
        }, f, indent=4)

def source_signature(file_path):
    stat = os.stat(file_path)
    rel_path = os.path.relpath(file_path, BASE_DIR).replace(os.sep, "/")
    raw_key = f"{rel_path}|{stat.st_size}"
    digest = hashlib.sha256(raw_key.encode("utf-8")).hexdigest()
    return {
        "id": digest,
        "relative_path": rel_path,
        "size": stat.st_size,
        "mtime_ns": stat.st_mtime_ns
    }

def state_path(signature, suffix):
    return os.path.join(SPOOL_STATE_DIR, f"{signature['id']}.{suffix}.json")

def already_spooled(signature):
    return os.path.exists(state_path(signature, "spooled"))

def should_retry_failed_spool(signature):
    path = state_path(signature, "failed")
    if not os.path.exists(path):
        return True
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return time.time() >= data.get("next_retry_at", 0)
    except Exception:
        return True

def mark_spooled(signature, source_path, dest_folder, source_delete_error=None):
    data = {
        **signature,
        "source_path": source_path,
        "dest_folder": dest_folder,
        "source_delete_error": str(source_delete_error) if source_delete_error else None,
        "timestamp": datetime.now().isoformat()
    }
    with open(state_path(signature, "spooled"), "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4)

    failed_path = state_path(signature, "failed")
    if os.path.exists(failed_path):
        try:
            os.remove(failed_path)
        except Exception:
            pass

    if source_delete_error:
        write_ingestion_error_ticket(
            f"INGESTION_SOURCE_LEFT_BEHIND_{signature['id']}",
            "SOURCE FILE LEFT BEHIND",
            source_path,
            source_delete_error,
            dest_folder
        )

def mark_failed_spool(signature, source_path, error):
    data = {
        **signature,
        "source_path": source_path,
        "error": str(error),
        "timestamp": datetime.now().isoformat(),
        "next_retry_at": time.time() + SPOOL_RETRY_SECONDS
    }
    with open(state_path(signature, "failed"), "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4)

    write_ingestion_error_ticket(
        f"INGESTION_SPOOL_FAILED_{signature['id']}",
        "SPOOL FAILED",
        source_path,
        error
    )

def same_size(source_path, dest_path):
    try:
        return os.path.getsize(source_path) == os.path.getsize(dest_path)
    except OSError:
        return False

def move_or_copy_pdf_to_queue(source_path, dest_path):
    try:
        shutil.move(source_path, dest_path)
        return None
    except Exception as move_error:
        if os.path.exists(dest_path) and same_size(source_path, dest_path):
            return move_error

        try:
            shutil.copy2(source_path, dest_path)
        except Exception:
            raise move_error

        try:
            os.remove(source_path)
            return None
        except Exception as delete_error:
            return delete_error

def convert_image_to_pdf(img_path, pdf_path):
    try:
        image = Image.open(img_path)
        images = []
        try:
            while True:
                img_copy = image.copy()
                if img_copy.mode in ("RGBA", "P"):
                    img_copy = img_copy.convert("RGB")
                images.append(img_copy)
                image.seek(image.tell() + 1)
        except EOFError:
            pass
            
        if images:
            images[0].save(pdf_path, "PDF", resolution=100.0, save_all=True, append_images=images[1:])
        return True
    except Exception as e:
        print(f"    [!] Error converting {img_path} to PDF: {e}")
        return False

def scan_and_spool():
    place_bu_readmes()

    for root, dirs, files in os.walk(BASE_DIR):
        # Ignore hidden or internal folders
        dirs[:] = [d for d in dirs if not (d.startswith('_') or d.startswith('.'))]

        # Decide whose the folder is before looking at a single file in it.
        # A loose file at a BU's root -- the README included -- belongs to
        # nobody, and must be skipped before the unsupported-file rename
        # below, or the README is renamed the first time the watcher runs.
        route = route_for(os.path.relpath(root, BASE_DIR))
        if route is None:
            continue

        for file in files:
            file_lower = file.lower()
            file_path = os.path.join(root, file)
            
            # Skip files that are already marked as unsupported
            if file.startswith("UNSUPPORTED_FILETYPE_"):
                continue
                
            # If it's a PDF, we process it normally
            is_pdf = file_lower.endswith(".pdf")
            is_image = file_lower.endswith((".jpg", ".jpeg", ".png", ".bmp", ".tiff", ".tif"))
            
            if not is_pdf and not is_image:
                # Unsupported file type
                new_name = f"UNSUPPORTED_FILETYPE_{file}"
                new_path = os.path.join(root, new_name)
                try:
                    os.rename(file_path, new_path)
                    print(f"  [X] Unsupported file rejected: {file} -> {new_name}")
                except Exception as e:
                    print(f"  [!] Failed to rename unsupported file {file}: {e}")
                continue
                
            # Wait for file to be completely copied
            if not is_file_stable(file_path, STABLE_WAIT_TIME):
                continue

            try:
                signature = source_signature(file_path)
            except OSError as e:
                print(f"  [!] Failed to inspect {file}: {e}")
                continue

            if already_spooled(signature):
                continue

            if not should_retry_failed_spool(signature):
                continue
                
            bu_number = route["bu_number"]
            # Downstream still calls the folder name the submitter; for the
            # shared queue it is the shared folder's own name.
            submitter_name = route["owner"] or SHARED_FOLDER_NAME

            name_only, _ = os.path.splitext(file)
            processing_id = f"{bu_number}.{datetime.now().strftime('%Y%m%d_%H%M%S')}.{name_only}"
            
            dest_folder = os.path.join(AI_QUEUE_DIR, processing_id)
            os.makedirs(dest_folder, exist_ok=True)
            
            # Handle images. The PDF is named after the batch id, not the
            # source file: the id is minted here, once, and everything
            # downstream reads it back off the name. Plan step 3.1.
            if is_image:
                dest_pdf_path = os.path.join(dest_folder, f"{processing_id}.pdf")
                print(f"  [*] Converting image to PDF: {file}")
                if convert_image_to_pdf(file_path, dest_pdf_path):
                    try:
                        os.remove(file_path) # Clean up original image
                    except:
                        pass
                else:
                    # Conversion failed, clean up destination folder and skip
                    shutil.rmtree(dest_folder)
                    continue
            else:
                # Handle PDF
                dest_pdf_path = os.path.join(dest_folder, f"{processing_id}.pdf")
                try:
                    source_delete_error = move_or_copy_pdf_to_queue(file_path, dest_pdf_path)
                except Exception as e:
                    print(f"  [!] Failed to move {file} to queue: {e}")
                    mark_failed_spool(signature, file_path, e)
                    try:
                        if os.path.exists(dest_folder) and not os.listdir(dest_folder):
                            os.rmdir(dest_folder)
                    except Exception:
                        pass
                    continue
            
            # Write Job Ticket
            ticket_path = os.path.join(dest_folder, "job_ticket.json")
            ticket_data = {
                "processing_id": processing_id,
                # What the submitter called the file. The PDF no longer carries
                # it, and it is the only handle a reviewer has on the document
                # they sent, so the ticket keeps it.
                "original_filename": file,
                "bu_number": bu_number,
                "submitter_name": submitter_name,
                # Who owns the invoice, decided by the folder it arrived in:
                # a named person, or None for the BU's shared queue.
                "queue": route["queue"],
                "owner": route["owner"],
                "assignment_source": "folder",
                "timestamp": datetime.now().isoformat()
            }
            with open(ticket_path, "w", encoding="utf-8") as f:
                json.dump(ticket_data, f, indent=4)

            mark_spooled(signature, file_path, dest_folder, source_delete_error if is_pdf else None)

            # The invoice exists from here on, so this is the first thing its
            # history says: spooled into the AI queue, by the watcher.
            record_state(processing_id, "ai_queue", ACTOR, f"spooled from {file}",
                         fields=invoice_facts(
                             budget_unit=bu_number,
                             submitter=submitter_name,
                             # The folder's name, until 8b maps names to people.
                             assigned_to=route["owner"],
                             assignment_source="folder" if route["owner"] else None,
                         ))
                
            if is_pdf and source_delete_error:
                print(f"  [>] Spooled {file} -> {processing_id} (copied; original could not be deleted)")
            else:
                print(f"  [>] Spooled {file} -> {processing_id}")

if __name__ == "__main__":
    # Prepare the machine before any work: directories, shortcuts, alias
    # sync. Import alone does none of it.
    bootstrap()

    print("======================================================================")
    print("             AI INVOICE PIPELINE: INGESTION WATCHER")
    print("======================================================================")
    print(f"Monitoring '{BASE_DIR}' for new incoming files...")
    
    try:
        while True:
            scan_and_spool()
            time.sleep(60) # 60 second polling interval
    except KeyboardInterrupt:
        print("\nWatcher stopped.")
