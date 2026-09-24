"""Intake: a file dropped in the watch tree becomes a row and a stored PDF.

The drop tree is unchanged from v1:

    <BU>/<Name>/...     that person's queue      (the default)
    <BU>/SHARED/...     the BU's shared queue
    <BU>/<file>         nobody -- loose files at the BU root are ignored

The PDF is moved to `_STORE/<batch_id>/<batch_id>.pdf`, where it stays for
its whole life, and one row is inserted: `received`, with `command =
extract`. There is no spool state on disk: the row is the record that the
file was taken, and a file that could only be copied (Windows would not
release the original) is recognised by its hash and path next time round.
"""
import hashlib
import os
import random
import shutil
import string
from datetime import datetime

import fitz
from PIL import Image

from store import ACTOR

# Wait time to ensure a file is fully copied over the network.
STABLE_WAIT_TIME = 2
SUPPORTED_IMAGES = (".jpg", ".jpeg", ".png", ".bmp", ".tiff", ".tif")

# What each Budget Unit folder says about itself. Shipped beside the worker
# and copied into a BU folder that has none; never over one that exists.
BU_README_NAME = "README - How to submit invoices.txt"
BU_README_TEMPLATE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "BU_FOLDER_README.txt")


def route_for(relative_path, shared_folder_name):
    """Who a file in the watch tree belongs to, or None when it belongs to nobody."""
    if relative_path in ("", "."):
        return None
    parts = relative_path.split(os.sep)
    if len(parts) < 2:
        return None
    bu_number, folder = parts[0], parts[1]
    if folder.casefold() == shared_folder_name.casefold():
        return {"bu_number": bu_number, "owner": None, "queue": "shared"}
    return {"bu_number": bu_number, "owner": folder, "queue": "person"}


def is_file_stable(filepath, wait_time=STABLE_WAIT_TIME):
    """A file still being copied changes size; one that is done does not."""
    try:
        initial_size = os.path.getsize(filepath)
        import time
        time.sleep(wait_time)
        return os.path.getsize(filepath) == initial_size and initial_size > 0
    except OSError:
        return False


def mint_batch_id(bu_number, filename):
    """`{BU}.{YYYYMMDD_HHMMSS}.{name}-[HASH]`, minted once, here."""
    name_only, _ = os.path.splitext(filename)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    tag = "".join(random.choices(string.ascii_uppercase + string.digits, k=4))
    return f"{bu_number}.{stamp}.{name_only}-[{tag}]"


def content_hash(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def convert_image_to_pdf(img_path, pdf_path):
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
    if not images:
        raise ValueError(f"no image frames in {img_path}")
    images[0].save(pdf_path, "PDF", resolution=100.0, save_all=True, append_images=images[1:])


def pdf_page_count(path):
    doc = fitz.open(path)
    try:
        return len(doc)
    except Exception:
        return None
    finally:
        doc.close()


def place_bu_readmes(base_dir):
    """Give every Budget Unit folder the README that explains its layout."""
    if not os.path.isfile(BU_README_TEMPLATE):
        return
    try:
        entries = os.listdir(base_dir)
    except OSError as e:
        print(f"  [!] Could not list {base_dir} to place READMEs: {e}")
        return
    for name in entries:
        folder = os.path.join(base_dir, name)
        if name.startswith(("_", ".")) or not os.path.isdir(folder):
            continue
        readme = os.path.join(folder, BU_README_NAME)
        if os.path.exists(readme):
            continue
        try:
            shutil.copyfile(BU_README_TEMPLATE, readme)
        except OSError as e:
            print(f"  [!] Could not place a README in {folder}: {e}")


class Intake:
    def __init__(self, settings, db, stable=is_file_stable):
        self.settings = settings
        self.db = db
        self.stable = stable

    def scan(self):
        """One pass over the drop tree. Returns the batch ids taken in."""
        base_dir = self.settings.base_dir
        place_bu_readmes(base_dir)
        taken = []
        for root, dirs, files in os.walk(base_dir):
            dirs[:] = [d for d in dirs if not (d.startswith("_") or d.startswith("."))]
            route = route_for(os.path.relpath(root, base_dir), self.settings.shared_folder_name)
            if route is None:
                continue
            for file in sorted(files):
                batch_id = self.take(os.path.join(root, file), route)
                if batch_id:
                    taken.append(batch_id)
        return taken

    def take(self, file_path, route):
        file = os.path.basename(file_path)
        lower = file.lower()
        if file.startswith("UNSUPPORTED_FILETYPE_"):
            return None
        is_pdf = lower.endswith(".pdf")
        is_image = lower.endswith(SUPPORTED_IMAGES)
        if not is_pdf and not is_image:
            new_path = os.path.join(os.path.dirname(file_path), f"UNSUPPORTED_FILETYPE_{file}")
            try:
                os.rename(file_path, new_path)
                print(f"  [X] Unsupported file rejected: {file}")
            except OSError as e:
                print(f"  [!] Failed to rename unsupported file {file}: {e}")
            return None
        if not self.stable(file_path):
            return None

        try:
            digest = content_hash(file_path)
        except OSError as e:
            print(f"  [!] Failed to read {file}: {e}")
            return None
        # A file left behind because Windows would not release it after the
        # copy is the same file, not a second invoice.
        for existing in self.db.find_by_hash(digest):
            if existing.get("source_path") == file_path:
                return None

        bu_number = route["bu_number"]
        submitter = route["owner"] or self.settings.shared_folder_name
        batch_id = mint_batch_id(bu_number, file)
        folder = self.settings.store_folder(batch_id)
        os.makedirs(folder, exist_ok=True)
        pdf_path = self.settings.pdf_path(batch_id)

        try:
            if is_image:
                print(f"  [*] Converting image to PDF: {file}")
                convert_image_to_pdf(file_path, pdf_path)
            else:
                shutil.copy2(file_path, pdf_path)
        except Exception as e:
            print(f"  [!] Failed to take {file} into the store: {e}")
            shutil.rmtree(folder, ignore_errors=True)
            return None

        fields = {
            "budget_unit": bu_number,
            "submitter": submitter,
            "assigned_to": route["owner"],
            "assignment_source": "folder" if route["owner"] else None,
            "source_filename": file,
            "source_path": file_path,
            "content_hash": digest,
            "page_count": pdf_page_count(pdf_path),
            "split_check": True,
            "attempt": 0,
        }
        self.db.insert_invoice(batch_id, "received", "extract", fields, note=f"received from {file}")

        # The row exists, so the original may go. If Windows will not let it,
        # it is left; the hash and path above stop it being taken twice.
        try:
            os.remove(file_path)
        except OSError as e:
            print(f"  [!] Could not remove the original {file} after taking it in: {e}")
        print(f"  [>] Received {file} -> {batch_id}")
        return batch_id
