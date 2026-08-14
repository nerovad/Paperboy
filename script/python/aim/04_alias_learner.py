import os
import time
import shutil
import json

# Import shared core FIRST so it auto-installs missing dependencies
from pipeline_common import (
    READY_TO_LEARN_DIR,
    VENDOR_REVIEW_DIR,
    ERROR_QUEUE_DIR,
    REPROCESS_QUEUE_DIR,
    SQL_QUEUE_DIR,
    save_new_vendor_alias,
)

NEXT_ACTION_CONTINUE = "continue_processing"
NEXT_ACTION_RETRY_AI = "retry_ai"


def move_folder(folder_path, destination_dir, folder_name):
    target_folder = os.path.join(destination_dir, folder_name)
    if os.path.exists(target_folder):
        shutil.rmtree(target_folder)

    shutil.move(folder_path, target_folder)
    return target_folder


def route_back_to_vendor_review(folder_path, folder_name, message):
    error_path = os.path.join(folder_path, "ERROR_VENDOR_REVIEW_CONTINUE.txt")
    try:
        with open(error_path, "w", encoding="utf-8") as ef:
            ef.write(message)
    except Exception:
        pass

    dest_back = move_folder(folder_path, VENDOR_REVIEW_DIR, folder_name)
    print(f"    [!] Routed folder back to _VENDOR_REVIEW for correction: {dest_back}")

def run_alias_learner():
    if not os.path.exists(READY_TO_LEARN_DIR):
        return

    for folder_name in os.listdir(READY_TO_LEARN_DIR):
        folder_path = os.path.join(READY_TO_LEARN_DIR, folder_name)
        if os.path.isdir(folder_path):
            learn_files = [f for f in os.listdir(folder_path) if f.endswith("_LEARN.json")]
            if not learn_files:
                # Clean up empty folder
                try:
                    shutil.rmtree(folder_path)
                except Exception:
                    pass
                continue
                
            learn_file = learn_files[0]
            learn_path = os.path.join(folder_path, learn_file)
            base_name = folder_name
            pdf_name = f"{base_name}.pdf"
            
            pdf_path = os.path.join(folder_path, pdf_name)
            if not os.path.exists(pdf_path):
                print(f"[!] Original PDF {pdf_name} not found in folder {folder_name}. Cannot route back to pipeline.")
                continue

            try:
                with open(learn_path, 'r', encoding='utf-8') as f:
                    learning_data = json.load(f)
            except Exception as e:
                print(f"[!] Error reading learn file {learn_file}: {e}")
                
                # Write syntax error details inside the folder
                err_file_path = os.path.join(folder_path, "ERROR_LEARN_SYNTAX.txt")
                try:
                    with open(err_file_path, "w", encoding="utf-8") as ef:
                        ef.write(f"JSON Syntax Error in learn file:\n\n{str(e)}\n\n")
                        ef.write("Please correct the JSON syntax in the _LEARN.json file and move this folder back to learn queue.\n")
                except Exception:
                    pass
                
                # Route folder back to VENDOR_REVIEW_DIR for correction
                dest_back = os.path.join(VENDOR_REVIEW_DIR, folder_name)
                try:
                    if os.path.exists(dest_back):
                        shutil.rmtree(dest_back)
                    shutil.move(folder_path, dest_back)
                    print(f"    [!] Routed folder back to _VENDOR_REVIEW for manual correction: {dest_back}")
                except Exception as ex:
                    print(f"    [!] Failed to route folder back: {ex}")
                continue
                
            extracted = learning_data.get("extracted_name")
            normalized = learning_data.get("suggested_normalized_name")
            next_action = learning_data.get("next_action", NEXT_ACTION_RETRY_AI)
            
            if not extracted or not normalized:
                print(f"    [!] Skipping {folder_name}: Must provide a suggested_normalized_name.")
                continue

            try:
                print(f"\n[ALIAS LEARNER] Learning new alias: '{extracted}' -> '{normalized}'")
                
                # 1. Update SQL & local cache
                save_new_vendor_alias(extracted, normalized, "Learned from manual vendor review")
                    
                if next_action == NEXT_ACTION_CONTINUE:
                    ready_payloads = [f for f in os.listdir(folder_path) if f.lower().endswith("_ready_for_sql.json")]
                    if not ready_payloads:
                        route_back_to_vendor_review(
                            folder_path,
                            folder_name,
                            "Learn & Continue requires a *_READY_FOR_SQL.json payload. "
                            "Open the invoice in Paperboy Vendor Review and submit it again."
                        )
                        continue
                    destination_dir = SQL_QUEUE_DIR
                    destination_label = "SQL queue"
                elif next_action == NEXT_ACTION_RETRY_AI:
                    destination_dir = REPROCESS_QUEUE_DIR
                    destination_label = "hidden AI reprocess queue"
                else:
                    print(f"    [!] Unknown next_action '{next_action}' for {folder_name}; defaulting to AI reprocess.")
                    destination_dir = REPROCESS_QUEUE_DIR
                    destination_label = "hidden AI reprocess queue"
                
                # Remove the _LEARN.json file from the folder before moving so it doesn't clutter
                os.remove(learn_path)

                move_folder(folder_path, destination_dir, folder_name)
                print(f"    [✓] Alias saved. Batch folder routed to {destination_label}.")
                
            except Exception as e:
                print(f"    [!] Error learning {base_name}: {e}")
                
                # Move folder to the technical error queue.
                error_dest = os.path.join(ERROR_QUEUE_DIR, f"ERROR_{folder_name}")
                try:
                    if os.path.exists(error_dest):
                        shutil.rmtree(error_dest)
                    shutil.move(folder_path, error_dest)
                    print(f"    [!] Routed crashed vendor review batch to: {error_dest}")
                except Exception as ex:
                    print(f"    [!] Failed to route crashed batch: {ex}")

if __name__ == "__main__":
    print(f"Monitoring '{READY_TO_LEARN_DIR}' (ALIAS LEARNER) for approved vendor aliases...")
    try:
        while True:
            run_alias_learner()
            time.sleep(5)
    except KeyboardInterrupt:
        print("\nAlias Learner stopped.")
