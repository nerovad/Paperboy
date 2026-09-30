"""Batch ids: `{BU}.{YYYYMMDD_HHMMSS}.{name}-[HASH]`, minted once, at intake.

The rules are not written here. They are in batch_id_spec.json beside this
file, which Paperboy's Aim::Intake reads too, so a file dropped on the share
and a file uploaded in Paperboy get an id -- and a store folder -- made the
same way. test/python/aim_v2/batch_id_cases.json holds the cases both test
suites check.

The spec is read at import, and its time zone resolved then too: a worker
that cannot tell the time the way Paperboy does stops at start, not halfway
through taking in a file. On Windows the zone database comes from the
`tzdata` package (requirements.txt).
"""
import json
import os
import posixpath
import re
import secrets
from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

SPEC_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "batch_id_spec.json")


def load_spec(path=SPEC_FILE):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


SPEC = load_spec()
UNSAFE_IN_NAME = re.compile(SPEC["name"]["unsafe_pattern"])
try:
    TIME_ZONE = ZoneInfo(SPEC["stamp"]["time_zone"])
except ZoneInfoNotFoundError as e:
    raise SystemExit(
        f"CRITICAL ERROR: time zone {SPEC['stamp']['time_zone']!r} is unknown here. "
        "Install the worker requirements (pip install -r requirements.txt), which bring tzdata."
    ) from e


def batch_name(filename):
    """The name part: the file's stem, safe for a Windows folder name."""
    # posixpath, as Ruby's File.basename does: "/" separates folders, and a
    # backslash is just an unsafe character, on every machine.
    stem, _ = posixpath.splitext(posixpath.basename(str(filename or "")))
    name = UNSAFE_IN_NAME.sub("", stem)
    name = re.sub(r"\s+", " ", name).strip()
    name = name[:SPEC["name"]["max_length"]]
    return name or SPEC["name"]["fallback"]


def stamp(now=None):
    """The moment, as the spec writes it, in the spec's time zone.

    `now` must be timezone-aware; the default is this moment.
    """
    moment = (now or datetime.now(TIME_ZONE)).astimezone(TIME_ZONE)
    return moment.strftime(SPEC["stamp"]["format"])


def random_code():
    alphabet = SPEC["code"]["alphabet"]
    return "".join(secrets.choice(alphabet) for _ in range(SPEC["code"]["length"]))


def mint_batch_id(bu_number, filename, now=None, code=None):
    parts = {
        "budget_unit": bu_number,
        "stamp": stamp(now),
        "name": batch_name(filename),
        "code": code or random_code(),
    }
    return re.sub(r"\{(\w+)\}", lambda m: str(parts[m.group(1)]), SPEC["format"])
