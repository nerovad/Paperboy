"""The worker mints batch ids by batch_id_spec.json, the same as Paperboy.

batch_id_cases.json is shared with test/services/aim/intake_test.rb: the
same filenames, the same moments, the same ids, on both sides. A rule that
changes on one side and not the other fails one of the two suites.
"""
import json
import os
import re
from datetime import datetime, timezone

import pytest

CASES_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "batch_id_cases.json")
CASES = json.load(open(CASES_FILE, encoding="utf-8"))


@pytest.fixture
def batch_ids(v2):
    return v2("batch_ids")


@pytest.mark.parametrize("case", CASES["names"], ids=lambda c: repr(c["filename"])[:40])
def test_the_name_part_follows_the_shared_cases(batch_ids, case):
    assert batch_ids.batch_name(case["filename"]) == case["name"]


@pytest.mark.parametrize("case", CASES["ids"], ids=lambda c: c["batch_id"])
def test_the_whole_id_follows_the_shared_cases(batch_ids, case):
    moment = datetime.fromisoformat(case["time"])

    minted = batch_ids.mint_batch_id(case["budget_unit"], case["filename"], now=moment, code=case["code"])

    assert minted == case["batch_id"]


def test_the_stamp_is_in_the_spec_time_zone_not_the_machine_clock(batch_ids):
    winter = datetime(2026, 1, 15, 20, 30, 5, tzinfo=timezone.utc)

    assert batch_ids.stamp(winter) == "20260115_123005"


def test_a_fresh_code_is_drawn_from_the_spec_alphabet(batch_ids):
    minted = batch_ids.mint_batch_id("4601", "Scan.pdf")

    assert re.match(r"^4601\.\d{8}_\d{6}\.Scan-\[[A-Z0-9]{4}\]$", minted)


def test_intake_mints_with_the_shared_rules(v2):
    assert v2("intake").mint_batch_id is v2("batch_ids").mint_batch_id
