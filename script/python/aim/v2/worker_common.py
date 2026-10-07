"""Helpers every AIM worker needs, kept in one place.

v2 owns these. v1's pipeline_common imports them from here rather than
carrying copies of its own (v1 is stopped and awaiting retirement -- see
`## Next`, item h, on the AIM Plan wiki page,
http://10.135.204.125:3000/BSS/Paperboy/wiki/AIM-Plan). So this module imports no other
v2 module and reads nothing at import: v1 can load it without pulling in the
v2 worker.

Same discipline as ever for configuration: there is no fallback for any
variable. A fallback is a hardcoded location living in the code, and a wrong
guess puts invoices somewhere nobody is watching.
"""
import os
import sys
import time

import fitz
from dotenv import load_dotenv

# Wait time to ensure a file is fully copied over the network.
STABLE_WAIT_TIME = 2


def env_file_candidates(script_dir):
    """AIM_ENV_FILE when set, then the .env in the worker's own folder."""
    explicit = os.getenv("AIM_ENV_FILE")
    candidates = []
    if explicit:
        candidates.append(explicit)
    # Only the worker's own folder. Walking parents or the working directory
    # meant a worker could pick up a stranger's .env depending on where it
    # was started from.
    candidates.append(os.path.join(script_dir, ".env"))
    seen = set()
    for candidate in candidates:
        normalized = os.path.abspath(candidate)
        if normalized in seen:
            continue
        seen.add(normalized)
        yield normalized


def load_environment(script_dir):
    """Load the first .env found for the worker in `script_dir`, or exit."""
    for candidate in env_file_candidates(script_dir):
        if os.path.exists(candidate):
            load_dotenv(candidate)
            return candidate
    checked = "\n  ".join(env_file_candidates(script_dir))
    sys.exit(f"CRITICAL ERROR: AIM .env file was not found. Checked:\n  {checked}")


def env(name):
    """Read one AIM variable, or exit naming it."""
    value = os.getenv(name)
    if value is None or value == "":
        sys.exit(f"CRITICAL ERROR: environment variable {name} is missing")
    return value


def is_file_stable(filepath, wait_time=STABLE_WAIT_TIME):
    """A file still being copied changes size; one that is done does not."""
    try:
        initial_size = os.path.getsize(filepath)
        time.sleep(wait_time)
        return os.path.getsize(filepath) == initial_size and initial_size > 0
    except OSError:
        return False


def pdf_page_to_image(pdf_path, page_num, output_path):
    """Render one 0-based page at 1.5x, the resolution the vision model reads."""
    doc = fitz.open(pdf_path)
    try:
        pix = doc[page_num].get_pixmap(matrix=fitz.Matrix(1.5, 1.5))
        pix.save(output_path)
    finally:
        doc.close()
