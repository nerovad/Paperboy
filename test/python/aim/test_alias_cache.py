"""The alias cache is written whole, and a brief Windows lock is ridden out.
Found 2026-09-23.

The alias learner reported "[Errno 13] Permission denied" saving
vendor_aliases.json -- Python's word for another process holding the file
open on Windows. The file was written in place with open(..., 'w'), which
also truncates it before the new text lands, so a worker reading it at that
moment saw an empty or partial file. It is now written to a temporary file
beside the target and swapped in, with a few retries before giving up.
"""
import json
import os

import pytest


def litter_beside(path):
    return [name for name in os.listdir(os.path.dirname(path)) if ".tmp-" in name]


def test_the_cache_is_swapped_in_whole_and_rides_out_a_brief_lock(pipeline, queue_tree, monkeypatch):
    path = pipeline.ALIAS_DB_FILE
    attempts = []
    real_replace = os.replace

    def locked_twice(source, target):
        attempts.append(target)
        if len(attempts) < 3:
            raise PermissionError(13, "Permission denied")
        return real_replace(source, target)

    monkeypatch.setattr(pipeline.os, "replace", locked_twice)
    monkeypatch.setattr(pipeline.time, "sleep", lambda seconds: None)

    pipeline.write_json_file(path, {"ACME INC": "ACME"})

    with open(path, encoding="utf-8") as handle:
        assert json.load(handle) == {"ACME INC": "ACME"}
    assert len(attempts) == 3
    assert litter_beside(path) == []


def test_a_lock_that_never_lifts_raises_and_leaves_no_litter(pipeline, queue_tree, monkeypatch):
    path = pipeline.ALIAS_DB_FILE

    def always_locked(source, target):
        raise PermissionError(13, "Permission denied")

    monkeypatch.setattr(pipeline.os, "replace", always_locked)
    monkeypatch.setattr(pipeline.time, "sleep", lambda seconds: None)

    with pytest.raises(PermissionError):
        pipeline.write_json_file(path, {"A": "B"}, attempts=2)

    assert not os.path.exists(path)
    assert litter_beside(path) == []


def test_a_learned_alias_reaches_the_cache_even_with_sql_away(pipeline, queue_tree, monkeypatch):
    """SQL Server is unreachable; the cache is still written, and written whole."""
    def unreachable(section):
        raise OSError("SQL Server is away")

    monkeypatch.setattr(pipeline, "get_sql_connection", unreachable)
    pipeline.save_new_vendor_alias("PLATINUM TOW AND TRANSPORT INC", "Platinum Tow and Transport Inc")

    with open(pipeline.ALIAS_DB_FILE, encoding="utf-8") as handle:
        aliases = json.load(handle)
    assert aliases["PLATINUM TOW AND TRANSPORT INC"] == "Platinum Tow and Transport Inc"
    assert litter_beside(pipeline.ALIAS_DB_FILE) == []
