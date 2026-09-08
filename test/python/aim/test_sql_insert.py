"""A SQL insert that maps to nothing must fail, not report success.

`insert_sql_record` used to `return` when no mapping key matched the payload.
The SQL worker took that as a successful insert, archived the batch and
deleted the folder -- so the invoice left the queue and never reached the
database. Plan step 1.1.
"""
import json
import os

import pytest


def write_mapping(pipeline, filename, mapping):
    """Drop a mapping file where insert_sql_record resolves bare names."""
    os.makedirs(pipeline.PROGRAM_DIR, exist_ok=True)
    path = os.path.join(pipeline.PROGRAM_DIR, filename)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(mapping, handle)
    return path


@pytest.fixture
def billing_section(pipeline, monkeypatch):
    """Configure one SQL section and capture what would be executed."""
    monkeypatch.setenv("AIM_SQL_BILLING_MAPPING_FILE", "billing_mapping.json")
    monkeypatch.setenv("AIM_SQL_BILLING_TABLE", "Aim_Invoices")

    executed = []

    class Cursor:
        def execute(self, query, values):
            executed.append((query, values))

    class Connection:
        def cursor(self):
            return Cursor()

        def commit(self):
            executed.append(("COMMIT", None))

        def close(self):
            pass

    monkeypatch.setattr(pipeline, "get_sql_connection", lambda section: Connection())
    return executed


def test_payload_matching_no_column_raises(pipeline, billing_section):
    write_mapping(pipeline, "billing_mapping.json", {"VendorName": "VendorName"})

    with pytest.raises(pipeline.SqlMappingError) as raised:
        pipeline.insert_sql_record("SQL_BILLING", {"NothingWeMap": "x"})

    assert "Aim_Invoices" in str(raised.value)
    assert billing_section == [], "no SQL should be executed when nothing maps"


def test_valid_payload_still_inserts(pipeline, billing_section):
    write_mapping(
        pipeline,
        "billing_mapping.json",
        {"VendorName": "VendorName", "InvoiceNumber": "InvoiceNumber"},
    )

    pipeline.insert_sql_record(
        "SQL_BILLING", {"VendorName": "Acme", "InvoiceNumber": "1234"}
    )

    query, values = billing_section[0]
    assert query.startswith("INSERT INTO Aim_Invoices (")
    assert "VendorName" in query and "InvoiceNumber" in query
    assert values == ["Acme", "1234"]
    assert ("COMMIT", None) in billing_section


def test_computed_column_alone_is_not_an_insert(pipeline, billing_section):
    """InvoiceConcatID is computed, so a payload of only that maps to nothing."""
    write_mapping(
        pipeline, "billing_mapping.json", {"InvoiceConcatID": "InvoiceConcatID"}
    )

    with pytest.raises(pipeline.SqlMappingError):
        pipeline.insert_sql_record("SQL_BILLING", {"InvoiceConcatID": "abc"})


def test_missing_mapping_variable_exits(pipeline, monkeypatch):
    """env() has no fallback: an unconfigured section stops the worker."""
    monkeypatch.delenv("AIM_SQL_BILLING_MAPPING_FILE", raising=False)

    with pytest.raises(SystemExit) as raised:
        pipeline.insert_sql_record("SQL_BILLING", {"VendorName": "Acme"})

    assert "AIM_SQL_BILLING_MAPPING_FILE" in str(raised.value)
