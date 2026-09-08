import os
import sys
import subprocess
import csv
import json
import re
import xml.etree.ElementTree as ET
from xml.dom import minidom
from datetime import datetime

# -----------------------------------------------------------------------------
# AUTOMATIC DEPENDENCY INSTALLER
# -----------------------------------------------------------------------------
# Dependencies are installed by deployment (requirements.txt), never on
# import. Importing a module must not reach the network or mutate the
# machine -- that is what made every Python step here untestable.
import fitz  
import pyodbc
from dotenv import load_dotenv
from thefuzz import fuzz, process
from PIL import Image, ImageDraw
from pydantic import BaseModel, field_validator
from typing import Optional
from dateutil import parser as dateparser

# -----------------------------------------------------------------------------
# ENVIRONMENT & DIRECTORIES
# -----------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

def env_file_candidates():
    explicit_env_file = os.getenv('AIM_ENV_FILE')
    candidates = []
    if explicit_env_file:
        candidates.append(explicit_env_file)

    # Only the script's own directory. Walking parents and the working
    # directory meant a worker could silently pick up a stranger's .env
    # depending on where it was started from. See Guardrails exception 2.
    candidates.append(os.path.join(SCRIPT_DIR, '.env'))

    seen = set()
    for candidate in candidates:
        normalized = os.path.abspath(candidate)
        if normalized in seen:
            continue
        seen.add(normalized)
        yield normalized

def load_aim_environment():
    for candidate in env_file_candidates():
        if os.path.exists(candidate):
            load_dotenv(candidate)
            return candidate

    checked_paths = "\n  ".join(env_file_candidates())
    sys.exit(f"CRITICAL ERROR: AIM .env file was not found. Checked:\n  {checked_paths}")

ENV_FILE = load_aim_environment()

def env(name):
    """Read an AIM environment variable, or exit naming it.

    There is deliberately no fallback parameter. A fallback is a hardcoded
    location living in the code, and a wrong guess puts invoices in a folder
    nobody is watching. Everything AIM needs is defined in LockBox; if a
    variable is missing, the worker refuses to start rather than inventing a
    path. See the plan's Guardrails.
    """
    value = os.getenv(name)
    if value is None or value == '':
        sys.exit(f"CRITICAL ERROR: environment variable {name} is missing")
    return value

BASE_DIR = env('AIM_BASE_DIR')
PROCESSED_DIR = env('AIM_PROCESSED_DIR')
PENDING_VISION_DIR = env('AIM_PENDING_VISION_DIR')
ACTION_NEEDED_DIR = env('AIM_ACTION_NEEDED_DIR')
LOG_DIR = env('AIM_LOG_DIR')
SQL_FAILED_DIR = env('AIM_SQL_FAILED_DIR')
SQL_QUEUE_DIR = env('AIM_SQL_QUEUE_DIR')
BATCH_SPLIT_DIR = env('AIM_BATCH_SPLIT_DIR')
READY_TO_SPLIT_DIR = env('AIM_READY_TO_SPLIT_DIR')
VENDOR_REVIEW_DIR = env('AIM_VENDOR_REVIEW_DIR')
READY_TO_LEARN_DIR = env('AIM_READY_TO_LEARN_DIR')
LOW_CONFIDENCE_REVIEW_DIR = env('AIM_LOW_CONFIDENCE_REVIEW_DIR')
REPROCESS_QUEUE_DIR = env('AIM_REPROCESS_QUEUE_DIR')
TEMP_DIR = env('AIM_TEMP_DIR')
ARCHIVE_DIR = env('AIM_ARCHIVE_DIR')
READY_TO_DELETE_DIR = env('AIM_READY_TO_DELETE_DIR')
DELETED_DIR = env('AIM_DELETED_DIR')

# New AI Queue Dir (for Watcher -> Worker spooling)
AI_QUEUE_DIR = env('AIM_AI_QUEUE_DIR')
ERROR_QUEUE_DIR = env('AIM_ERROR_QUEUE_DIR')

# The worker install folder on the AIM share. Bare filenames in the
# configuration resolve against this, not against wherever this file happens
# to sit on disk.
PROGRAM_DIR = env('AIM_PROGRAM_DIR')

SPLIT_FOLDER_NAME = env('AIM_SPLIT_FOLDER_NAME')

# We also set the Tesseract command globally
import pytesseract
TESSERACT_CMD = env('AIM_TESSERACT_CMD')

TEMP_IMAGE = os.path.join(TEMP_DIR, "_temp_page_render_vision.png")
log_filename_cfg = env('AIM_LOG_FILE_NAME')
LOG_FILE = os.path.join(LOG_DIR, log_filename_cfg)

# Resolve Alias DB File
alias_db_cfg = env('AIM_ALIAS_DB_FILE')
ALIAS_DB_FILE = alias_db_cfg if os.path.isabs(alias_db_cfg) else os.path.join(PROGRAM_DIR, alias_db_cfg)

# Resolve Vendor Rules File
vendor_rules_cfg = env('AIM_VENDOR_RULES_FILE')
VENDOR_RULES_FILE = vendor_rules_cfg if os.path.isabs(vendor_rules_cfg) else os.path.join(PROGRAM_DIR, vendor_rules_cfg)

# Resolve Field Aliases File
field_aliases_cfg = env('AIM_FIELD_ALIASES_FILE')
FIELD_ALIASES_FILE = field_aliases_cfg if os.path.isabs(field_aliases_cfg) else os.path.join(PROGRAM_DIR, field_aliases_cfg)

def create_windows_shortcut(target_path, shortcut_path):
    """Create a Windows .lnk shortcut to a folder/file."""
    try:
        from win32com.client import Dispatch
        shell = Dispatch('WScript.Shell')
        shortcut = shell.CreateShortCut(shortcut_path)
        shortcut.TargetPath = target_path
        shortcut.save()
    except Exception as e:
        print(f"    [!] Failed to create shortcut: {e}")

# Create convenience shortcuts for the human review processes
def setup_shortcuts():
    shortcuts = [
        # Batch Split
        (READY_TO_SPLIT_DIR, os.path.join(BATCH_SPLIT_DIR, "MOVE_FOLDERS_HERE_TO_SPLIT.lnk")),
        # Vendor Review
        (READY_TO_LEARN_DIR, os.path.join(VENDOR_REVIEW_DIR, "MOVE_FOLDERS_HERE_TO_LEARN_ALIAS.lnk")),
        (READY_TO_DELETE_DIR, os.path.join(VENDOR_REVIEW_DIR, "MOVE_FOLDERS_HERE_TO_DELETE.lnk")),
        # Action Needed
        (SQL_QUEUE_DIR, os.path.join(ACTION_NEEDED_DIR, "MOVE_FOLDERS_HERE_TO_SEND_TO_SQL.lnk")),
        (READY_TO_DELETE_DIR, os.path.join(ACTION_NEEDED_DIR, "MOVE_FOLDERS_HERE_TO_DELETE.lnk")),
        # Low Confidence Review
        (SQL_QUEUE_DIR, os.path.join(LOW_CONFIDENCE_REVIEW_DIR, "MOVE_FOLDERS_HERE_TO_SEND_TO_SQL.lnk")),
        (READY_TO_DELETE_DIR, os.path.join(LOW_CONFIDENCE_REVIEW_DIR, "MOVE_FOLDERS_HERE_TO_DELETE.lnk")),
    ]
    for target, path in shortcuts:
        if not os.path.exists(path):
            create_windows_shortcut(target, path)

MANAGED_DIRECTORIES = [
    PROCESSED_DIR, PENDING_VISION_DIR, ACTION_NEEDED_DIR, LOG_DIR,
    SQL_FAILED_DIR, SQL_QUEUE_DIR, BATCH_SPLIT_DIR, READY_TO_SPLIT_DIR,
    VENDOR_REVIEW_DIR, READY_TO_LEARN_DIR, LOW_CONFIDENCE_REVIEW_DIR,
    REPROCESS_QUEUE_DIR, TEMP_DIR, ARCHIVE_DIR, READY_TO_DELETE_DIR,
    DELETED_DIR, AI_QUEUE_DIR, ERROR_QUEUE_DIR,
]


def bootstrap():
    """Prepare the machine to run a worker.

    Every side effect the pipeline needs lives here, and nothing calls it on
    import. Each worker calls it from its own __main__. Keeping import pure
    is what makes the pipeline testable: a test can import this module
    against a temp environment without creating a directory, planting a
    shortcut, or touching the network.
    """
    for folder in MANAGED_DIRECTORIES:
        os.makedirs(folder, exist_ok=True)

    pytesseract.pytesseract.tesseract_cmd = TESSERACT_CMD
    setup_shortcuts()

    # Bi-directional vendor alias sync against SQL. This opens a database
    # connection, so it must never happen merely because someone imported
    # the module.
    get_vendor_aliases()

class InvoiceData(BaseModel):
    is_urgent: Optional[bool] = False
    contains_multiple_invoices: Optional[bool] = False
    contains_handwritten_financials: Optional[bool] = False
    document_type: Optional[str] = None
    extracted_vendor_name: Optional[str] = None
    vendor_name: Optional[str] = None # Normalized Vendor
    invoice_date: Optional[str] = None
    invoice_number: Optional[str] = None
    invoice_number_label: Optional[str] = None
    invoice_total: Optional[str] = None
    order_number: Optional[str] = None
    customer_number: Optional[str] = None

    @field_validator("customer_number", "invoice_number", "order_number", "invoice_total", mode="before")
    @classmethod
    def reject_hallucinated_long_strings(cls, v):
        if isinstance(v, str) and len(v) > 50:
            return None
        return v

class ManifestItem(BaseModel):
    vendor_name: Optional[str] = "Unknown"
    invoice_number: Optional[str] = "Unknown"
    pages: list[int]

class DocumentManifest(BaseModel):
    invoices: list[ManifestItem]

# -----------------------------------------------------------------------------
# HELPER FUNCTIONS
# -----------------------------------------------------------------------------
def get_sql_connection(section):
    prefix = f"AIM_{section}_"
    server = env(f"{prefix}SERVER")
    database = env(f"{prefix}DATABASE").replace('[', '').replace(']', '')
    user = env(f"{prefix}USER")
    password = env(f"{prefix}PASSWORD")
    
    # Driver and encryption are properties of the server being talked to,
    # not of AIM, and both are expected to differ on SQL Server 2022.
    driver = env('AIM_ODBC_DRIVER')
    encrypt = env('AIM_ODBC_ENCRYPT')
    conn_str = (
        f"DRIVER={{{driver}}};SERVER={server};DATABASE={database};"
        f"UID={user};PWD={password};Encrypt={encrypt};"
    )
    return pyodbc.connect(conn_str)

class SqlMappingError(Exception):
    """A SQL payload could not be mapped onto any column of its table.

    Silently returning here is how invoices disappeared: the worker printed a
    success line, archived the batch and deleted the folder while the database
    never received a row. Raising sends the batch to the failed queue instead.
    """

def insert_sql_record(section, data_dict):
    prefix = f"AIM_{section}_"
    mapping_filename = env(f"{prefix}MAPPING_FILE")

    if os.path.isabs(mapping_filename):
        mapping_file_path = mapping_filename
    else:
        mapping_file_path = os.path.join(PROGRAM_DIR, mapping_filename)
    
    if not os.path.exists(mapping_file_path):
        print(f"    [!] Mapping file {mapping_filename} not found. Skipping SQL insert for {section}.")
        return

    with open(mapping_file_path, 'r') as f:
        mapping = json.load(f)
        
    table = env(f"{prefix}TABLE")
    columns = []
    values = []
    placeholders = []

    for script_key, sql_column in mapping.items():
        if script_key in data_dict:
            # Skip InvoiceConcatID since it is a computed column in the database
            if sql_column == "InvoiceConcatID":
                continue
            columns.append(sql_column)
            values.append(data_dict[script_key])
            placeholders.append("?")

    if not columns:
        raise SqlMappingError(
            f"{section}: no column of {table} matched the payload. "
            f"Mapping {mapping_filename} expects "
            f"{sorted(mapping.keys())}; the payload carries "
            f"{sorted(data_dict.keys())}."
        )

    query = f"INSERT INTO {table} ({', '.join(columns)}) VALUES ({', '.join(placeholders)})"
    
    conn = get_sql_connection(section)
    cursor = conn.cursor()
    cursor.execute(query, values)
    conn.commit()
    conn.close()

def write_log(filename, stage, status, details, bu_number, submitter_name, processing_id, data=None):
    # Local CSV Logging
    file_exists = os.path.isfile(LOG_FILE)
    try:
        with open(LOG_FILE, mode='a', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            if not file_exists:
                writer.writerow(['Timestamp', 'Processing_ID', 'Filename', 'Stage', 'Status', 'Details'])
            writer.writerow([datetime.now().strftime("%Y-%m-%d %H:%M:%S"), processing_id, filename, stage, status, details])
    except Exception as e:
        print(f"    [!] Failed to write to local CSV: {e}")
        
    # Exact mapping to match the SQL Schema
    sql_payload = {
        "FileName": filename,
        "Submitter": submitter_name,
        "BU": bu_number,
        "VendorName": data.vendor_name if data else None,
        "InvoiceNumber": data.invoice_number if data else None,
        "InvoiceTotal": data.invoice_total if data else None,
        "InvoiceDate": data.invoice_date if data else None,
        "OrderNumber": data.order_number if data else None,
        "CustomerNumber": data.customer_number if data else None,
        "ExtractedMetadata": data.model_dump_json() if data else None,
        "Status": status,
        "ErrorMessage": details if details else None,
        "ProcessedTimestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "InvoiceConcatID": processing_id
    }
    
    if status == "SUCCESS":
        folder_path = os.path.join(SQL_QUEUE_DIR, processing_id)
        os.makedirs(folder_path, exist_ok=True)
        queue_path = os.path.join(folder_path, f"{processing_id}.json")
        try:
            with open(queue_path, 'w', encoding='utf-8') as f:
                json.dump(sql_payload, f, indent=4)
        except Exception as e:
            print(f"    [!] Failed to write to SQL Queue: {e}")
    elif status == "ACTION_NEEDED":
        folder_path = os.path.join(ACTION_NEEDED_DIR, processing_id)
        os.makedirs(folder_path, exist_ok=True)
        manual_fix_path = os.path.join(folder_path, f"{processing_id}_READY_FOR_SQL.json")
        try:
            with open(manual_fix_path, 'w', encoding='utf-8') as f:
                json.dump(sql_payload, f, indent=4)
        except Exception as e:
            print(f"    [!] Failed to write ACTION_NEEDED JSON for {processing_id}: {e}")

def archive_batch(processing_id, bu_number, submitter_name, source_dir):
    """
    Copies the entire contents of a processing_id batch directory to the Archive.
    Archive structure: ARCHIVE_DIR / BU / Submitter / Date (YYYY-MM-DD) / ID /
    """
    try:
        import shutil
        # Clean folder names for path safety
        date_str = datetime.now().strftime("%Y-%m-%d")
        bu_clean = "".join(c for c in str(bu_number) if c.isalnum() or c in (' ', '-', '_')).strip()
        submitter_clean = "".join(c for c in str(submitter_name) if c.isalnum() or c in (' ', '-', '_')).strip()
        if not bu_clean: bu_clean = "UnknownBU"
        if not submitter_clean: submitter_clean = "UnknownUser"
        
        target_archive_dir = os.path.join(ARCHIVE_DIR, bu_clean, submitter_clean, date_str, processing_id)
        os.makedirs(target_archive_dir, exist_ok=True)
        
        if os.path.exists(source_dir) and os.path.isdir(source_dir):
            for file in os.listdir(source_dir):
                src_file = os.path.join(source_dir, file)
                if os.path.isfile(src_file):
                    shutil.copy2(src_file, os.path.join(target_archive_dir, file))
            print(f"    [✓] Batch archived to: {target_archive_dir}")
            return True
    except Exception as e:
        print(f"    [!] Archiving failed for {processing_id}: {e}")
    return False


def is_file_stable(filepath, wait_time=2):
    """Check if a file is currently being copied by comparing its size over time."""
    try:
        initial_size = os.path.getsize(filepath)
        import time
        time.sleep(wait_time)
        current_size = os.path.getsize(filepath)
        return initial_size == current_size and initial_size > 0
    except OSError:
        return False

def pdf_page_to_image(pdf_path, page_num, output_path):
    doc = fitz.open(pdf_path)
    page = doc[page_num]
    matrix = fitz.Matrix(1.5, 1.5)
    pix = page.get_pixmap(matrix=matrix)
    pix.save(output_path)
    doc.close()

def check_missing_fields(data: InvoiceData) -> list:
    missing = []
    if not data.vendor_name and not data.extracted_vendor_name: missing.append("Vendor Name")
    if not data.invoice_date: missing.append("Invoice Date")
    if not data.invoice_number: missing.append("Invoice Number")
    if not data.invoice_total: missing.append("Invoice Total")
    return missing

def _clean_money(v):
    if not v:
        return None
    digits = re.sub(r'[^0-9.\-]', '', str(v))
    if digits in ('', '-', '.', '-.', '--'):
        return None
    try:
        return f"{float(digits):.2f}"
    except ValueError:
        return None

def _clean_date(v):
    if not v or not str(v).strip():
        return None
    try:
        return dateparser.parse(str(v), dayfirst=False).strftime("%Y-%m-%d")
    except (ValueError, OverflowError):
        return None

def apply_invoice_number_rules(data, document_text=None):
    if document_text:
        m = re.search(r'INVOICE\s+(\d+)\s+TOTAL', document_text, re.IGNORECASE)
        if m:
            data.invoice_number = m.group(1)
        if not data.order_number:
            mp = re.search(r'\bLAR\s*PO[:#\s]*([0-9]+)', document_text, re.IGNORECASE)
            if mp:
                data.order_number = mp.group(1)
    return data

def get_vendor_aliases():
    """
    Retrieves vendor aliases from SQL table Aim_Vendor_Aliases.
    Performs a bi-directional sync with the local JSON cache (ALIAS_DB_FILE).
    Falls back to local JSON cache if SQL is offline.
    """
    local_aliases = {}
    
    # 1. Read local JSON cache
    if os.path.exists(ALIAS_DB_FILE):
        try:
            with open(ALIAS_DB_FILE, 'r', encoding='utf-8') as f:
                local_aliases = json.load(f)
        except Exception as e:
            print(f"    [!] Failed to read local alias cache: {e}")
            
    # 2. Attempt SQL Connection and read SQL aliases
    db_aliases = {}
    conn = None
    cursor = None
    try:
        conn = get_sql_connection("SQL_BILLING")
        cursor = conn.cursor()
        
        # Check if table exists (best effort safety check)
        cursor.execute("""
            IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Aim_Vendor_Aliases]') AND type in (N'U'))
                SELECT 1
            ELSE
                SELECT 0
        """)
        table_exists = cursor.fetchone()[0]
        
        if not table_exists:
            # Table doesn't exist yet, we will create it!
            print("    [i] SQL table Aim_Vendor_Aliases not found. Creating it...")
            cursor.execute("""
                CREATE TABLE Aim_Vendor_Aliases (
                    ExtractedName VARCHAR(255) PRIMARY KEY,
                    NormalizedName VARCHAR(255) NOT NULL,
                    DateLearned DATETIME DEFAULT GETDATE(),
                    Notes VARCHAR(MAX) NULL
                )
            """)
            conn.commit()
            
        cursor.execute("SELECT ExtractedName, NormalizedName FROM Aim_Vendor_Aliases")
        rows = cursor.fetchall()
        for row in rows:
            db_aliases[row[0]] = row[1]
            
        # 3. Bi-directional Sync
        sync_needed = False
        
        # Sync Cache -> SQL
        for key, val in local_aliases.items():
            if key not in db_aliases:
                try:
                    cursor.execute(
                        "INSERT INTO Aim_Vendor_Aliases (ExtractedName, NormalizedName, DateLearned, Notes) VALUES (?, ?, ?, ?)",
                        (key, val, datetime.now(), "Synced from local cache")
                    )
                    db_aliases[key] = val
                    sync_needed = True
                except Exception as ex:
                    print(f"    [!] Failed to sync key '{key}' to SQL: {ex}")
                    
        if sync_needed:
            conn.commit()
            print("    [✓] Synced missing aliases from local cache to SQL.")
            
        # Sync SQL -> Cache
        cache_update_needed = False
        for key, val in db_aliases.items():
            if key not in local_aliases or local_aliases[key] != val:
                local_aliases[key] = val
                cache_update_needed = True
                
        if cache_update_needed:
            try:
                with open(ALIAS_DB_FILE, 'w', encoding='utf-8') as f:
                    json.dump(local_aliases, f, indent=4)
                print("    [✓] Synced missing aliases from SQL to local JSON cache.")
            except Exception as ex:
                print(f"    [!] Failed to save updated local JSON cache: {ex}")
                
        return local_aliases
        
    except Exception as e:
        print(f"    [!] SQL Alias Database connection failed: {e}. Falling back to local JSON cache.")
        return local_aliases
    finally:
        if cursor:
            try:
                cursor.close()
            except Exception:
                pass
        if conn:
            try:
                conn.close()
            except Exception:
                pass

def save_new_vendor_alias(extracted_name, normalized_name, notes="Learned alias"):
    """
    Saves a new alias to both MS SQL and the local JSON cache.
    """
    # 1. Update local JSON cache first
    local_aliases = {}
    if os.path.exists(ALIAS_DB_FILE):
        try:
            with open(ALIAS_DB_FILE, 'r', encoding='utf-8') as f:
                local_aliases = json.load(f)
        except Exception:
            pass
            
    local_aliases[extracted_name] = normalized_name
    try:
        with open(ALIAS_DB_FILE, 'w', encoding='utf-8') as f:
            json.dump(local_aliases, f, indent=4)
    except Exception as e:
        print(f"    [!] Failed to update local cache: {e}")

    # 2. Attempt SQL write
    conn = None
    cursor = None
    try:
        conn = get_sql_connection("SQL_BILLING")
        cursor = conn.cursor()
        
        # Check if exists
        cursor.execute("SELECT COUNT(*) FROM Aim_Vendor_Aliases WHERE ExtractedName = ?", (extracted_name,))
        exists = cursor.fetchone()[0]
        
        if exists:
            cursor.execute(
                "UPDATE Aim_Vendor_Aliases SET NormalizedName = ?, DateLearned = ?, Notes = ? WHERE ExtractedName = ?",
                (normalized_name, datetime.now(), notes, extracted_name)
            )
        else:
            cursor.execute(
                "INSERT INTO Aim_Vendor_Aliases (ExtractedName, NormalizedName, DateLearned, Notes) VALUES (?, ?, ?, ?)",
                (extracted_name, normalized_name, datetime.now(), notes)
            )
        conn.commit()
        print(f"    [✓] Alias saved to SQL: '{extracted_name}' -> '{normalized_name}'")
        return True
    except Exception as e:
        print(f"    [!] SQL Alias save failed: {e}. Mapping was cached locally only.")
        return False
    finally:
        if cursor:
            try:
                cursor.close()
            except Exception:
                pass
        if conn:
            try:
                conn.close()
            except Exception:
                pass

def get_rules_for_vendor(normalized_name):
    if not os.path.exists(VENDOR_RULES_FILE):
        return ""
    try:
        with open(VENDOR_RULES_FILE, 'r', encoding='utf-8') as f:
            rules = json.load(f)
        vendor_rules = rules.get(normalized_name, [])
        if vendor_rules:
            return "\n".join(vendor_rules)
    except Exception as e:
        print(f"    [!] Failed to read vendor rules: {e}")
    return ""

def get_global_field_aliases():
    if not os.path.exists(FIELD_ALIASES_FILE):
        return ""
    try:
        with open(FIELD_ALIASES_FILE, 'r', encoding='utf-8') as f:
            aliases = json.load(f)
            
        instructions = []
        for field, phrases in aliases.items():
            if phrases:
                formatted_phrases = ", ".join(f"'{p}'" for p in phrases)
                instructions.append(f"{formatted_phrases} all map to {field}")
                
        if instructions:
            return f"(Note: {'. '.join(instructions)})."
    except Exception as e:
        print(f"    [!] Failed to read field aliases: {e}")
    return ""

def save_vendor_rule(normalized_name, rule_text):
    if not rule_text or not rule_text.strip():
        return False
    rules = {}
    if os.path.exists(VENDOR_RULES_FILE):
        try:
            with open(VENDOR_RULES_FILE, 'r', encoding='utf-8') as f:
                rules = json.load(f)
        except Exception:
            pass
    
    if normalized_name not in rules:
        rules[normalized_name] = []
    
    # Avoid duplicates
    if rule_text not in rules[normalized_name]:
        rules[normalized_name].append(rule_text)
        try:
            with open(VENDOR_RULES_FILE, 'w', encoding='utf-8') as f:
                json.dump(rules, f, indent=4)
            return True
        except Exception as e:
            print(f"    [!] Failed to save vendor rule: {e}")
    return False

def normalize_vendor_name(extracted_name):
    if not extracted_name:
        return None, False

    aliases = get_vendor_aliases()
            
    # 1. Direct Match (Case Insensitive)
    for raw, normalized in aliases.items():
        if extracted_name.lower().strip() == raw.lower().strip():
            return normalized, True
            
    # 2. Fuzzy Match (95%+ similarity)
    if aliases:
        known_raws = list(aliases.keys())
        best_match, score = process.extractOne(extracted_name, known_raws, scorer=fuzz.token_sort_ratio)
        if score >= 95:
            return aliases[best_match], True
            
        # 3. AI Smart Match (if fuzzy is close but not certain, > 75%)
        if score >= 75:
            normalized_candidate = aliases[best_match]
            prompt = (
                f"Is the extracted vendor name '{extracted_name}' just a typo, branch number, or legal suffix variation "
                f"of the known company '{normalized_candidate}'? "
                "Reply strictly with YES or NO."
            )
            try:
                import ollama
                response = ollama.chat(model=env('AIM_TEXT_MODEL'), messages=[{'role': 'user', 'content': prompt}], options={'temperature': 0})
                answer = response['message']['content'].strip().upper()
                if "YES" in answer:
                    save_new_vendor_alias(extracted_name, normalized_candidate, "AI Smart Match Typos/Suffixes")
                    return normalized_candidate, True
            except Exception:
                pass
                
    # 4. Unknown Vendor (Route to Human Review)
    return None, False

def _clean_text_field(v):
    if not v:
        return None
    cleaned = re.sub(r'[^a-zA-Z0-9_\- ]', '', str(v))
    return cleaned.strip() if cleaned.strip() else None

def sanitize_data(data: InvoiceData):
    if data.vendor_name:
        data.vendor_name = data.vendor_name.strip().replace("&", "and") or None
    data.invoice_total = _clean_money(data.invoice_total)
    data.invoice_date = _clean_date(data.invoice_date)
    data.invoice_number = _clean_text_field(data.invoice_number)
    data.order_number = _clean_text_field(data.order_number)
    return data

def draw_bounding_boxes(pdf_path, page_num, data, output_path):
    temp_draw_path = os.path.join(TEMP_DIR, f"_temp_draw_{page_num}.png")
    try:
        pdf_page_to_image(pdf_path, page_num, temp_draw_path)
        img = Image.open(temp_draw_path)
        draw = ImageDraw.Draw(img)
        width, height = img.size

        boxes = [
            data.vendor_name_box, data.invoice_date_box, data.invoice_number_box,
            data.invoice_total_box, data.order_number_box, data.customer_number_box
        ]

        box_found = False
        for box in boxes:
            if box and len(box) == 4:
                box_found = True
                xmin, ymin, xmax, ymax = box
                actual_xmin = (xmin / 1000.0) * width
                actual_ymin = (ymin / 1000.0) * height
                actual_xmax = (xmax / 1000.0) * width
                actual_ymax = (ymax / 1000.0) * height
                
                draw.rectangle([actual_xmin, actual_ymin, actual_xmax, actual_ymax], outline="green", width=4)
                
        if box_found:
            img.save(output_path, "JPEG")
            
        img.close()
    except Exception as e:
        print(f"    [!] Error drawing boxes on page {page_num + 1}: {e}")
    finally:
        if os.path.exists(temp_draw_path):
            os.remove(temp_draw_path)

def generate_laserfiche_xml(data, bu_number, submitter_name, xml_path, processing_id):
    root = ET.Element("ImportSession")
    doc = ET.SubElement(root, "Doc")
    
    # DocFile: the PDF filename that LFIA should associate with this metadata
    ET.SubElement(doc, "DocFile").text = f"{processing_id}.pdf"
    
    # TemplateName: the Laserfiche template to apply (title-cased, not all-caps)
    doc_type = data.document_type if data.document_type else "UNKNOWN"
    ET.SubElement(doc, "TemplateName").text = doc_type.title()
    
    # FolderPath: the destination folder in the Laserfiche repository
    # Routes documents into BU-specific subfolders under the configured inbox
    inbox = env('AIM_LASERFICHE_INBOX_PATH')
    folder_path = f"{inbox}\\{bu_number}" if bu_number else f"{inbox}\\_UNSORTED"
    ET.SubElement(doc, "FolderPath").text = folder_path
    
    # FieldData: all metadata fields
    field_data = ET.SubElement(doc, "FieldData")
    
    def add_field(name, value):
        f = ET.SubElement(field_data, "Field", Name=name)
        if value:  
            f.text = str(value)
        else:
            f.text = ""
    add_field("Budget Unit Number", bu_number)
    add_field("Submitted by", submitter_name)
    add_field("Processing ID", processing_id)
    add_field("Vendor Name", data.vendor_name)
    add_field("Invoice Date", data.invoice_date)
    add_field("Invoice Number", data.invoice_number)
    add_field("Invoice Total", data.invoice_total)
    add_field("Order Number", data.order_number)
    add_field("Customer Number", data.customer_number)
    
    xml_str = minidom.parseString(ET.tostring(root, encoding='utf-8')).toprettyxml(indent="  ")
    with open(xml_path, "w", encoding="utf-8") as f:
        f.write(xml_str)

