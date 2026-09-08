"""Every path, connection property and model name comes from configuration.

No fallbacks, no guesses, no literals. A missing variable stops the worker
rather than inventing a folder -- a wrong guess is how invoices end up
somewhere nobody is watching. Plan step 0.6.
"""
import os
import sys

import pytest

REQUIRED = [
    "AIM_AI_QUEUE_DIR", "AIM_ERROR_QUEUE_DIR", "AIM_SQL_FAILED_DIR",
    "AIM_PROGRAM_DIR", "AIM_SPLIT_FOLDER_NAME", "AIM_LOG_FILE_NAME",
    "AIM_ALIAS_DB_FILE", "AIM_VENDOR_RULES_FILE", "AIM_FIELD_ALIASES_FILE",
]


@pytest.mark.parametrize("variable", REQUIRED)
def test_a_missing_variable_stops_the_worker_and_names_it(
    fake_environment, monkeypatch, variable
):
    monkeypatch.delenv(variable, raising=False)

    with pytest.raises(SystemExit) as exit_info:
        import pipeline_common  # noqa: F401

    assert variable in str(exit_info.value), (
        f"the error should name {variable} so an operator knows what to set"
    )


def test_env_has_no_fallback_parameter(pipeline):
    """The parameter is what made every hardcoded fallback possible."""
    import inspect

    parameters = list(inspect.signature(pipeline.env).parameters)
    assert parameters == ["name"], (
        f"env() should take only a name, got {parameters}; a fallback is a "
        "hardcoded location living in the code"
    )


def test_the_ai_queue_is_configured_not_derived(pipeline):
    """It used to be dirname(SQL_QUEUE_DIR) + '_AI_QUEUE'.

    Rails read AIM_AI_QUEUE_DIR while the workers ignored it, so the two
    could point at different folders with nothing to reveal the split.
    """
    assert pipeline.AI_QUEUE_DIR == os.environ["AIM_AI_QUEUE_DIR"]
    assert "_AI_QUEUE" not in pipeline.AI_QUEUE_DIR


def test_every_queue_path_comes_from_the_fake_environment(pipeline, fake_environment):
    for directory in pipeline.MANAGED_DIRECTORIES:
        assert str(fake_environment) in directory, (
            f"{directory} is not driven by the test environment"
        )


def test_bare_filenames_resolve_against_the_program_folder(
    fake_environment, monkeypatch
):
    monkeypatch.setenv("AIM_ALIAS_DB_FILE", "vendor_aliases.json")
    for module in [m for m in list(sys.modules) if m.startswith("pipeline_common")]:
        del sys.modules[module]

    import pipeline_common

    assert pipeline_common.ALIAS_DB_FILE == os.path.join(
        os.environ["AIM_PROGRAM_DIR"], "vendor_aliases.json"
    )


def test_the_odbc_driver_and_encryption_are_configured(pipeline, monkeypatch):
    captured = {}

    def fake_connect(conn_str):
        captured["conn_str"] = conn_str

    monkeypatch.setattr(pipeline.pyodbc, "connect", fake_connect)
    for name in ["SERVER", "DATABASE", "USER", "PASSWORD"]:
        monkeypatch.setenv(f"AIM_SQL_TEST_{name}", "x")
    monkeypatch.setenv("AIM_ODBC_DRIVER", "Driver 99")
    monkeypatch.setenv("AIM_ODBC_ENCRYPT", "yes")

    pipeline.get_sql_connection("SQL_TEST")

    assert "DRIVER={Driver 99}" in captured["conn_str"]
    assert "Encrypt=yes" in captured["conn_str"]
    assert "ODBC Driver 17" not in captured["conn_str"]


def test_the_laserfiche_folder_is_configured(pipeline, monkeypatch):
    monkeypatch.setenv("AIM_LASERFICHE_INBOX_PATH", r"\TEST\INBOX")
    source = pipeline.generate_laserfiche_xml.__code__.co_consts

    assert not any(
        isinstance(const, str) and "00 INBOX" in const for const in source
    ), "the Laserfiche inbox path is still a literal in the code"


def test_the_env_file_search_does_not_walk_parents_or_cwd(pipeline):
    candidates = list(pipeline.env_file_candidates())

    assert len(candidates) <= 2, (
        f"the .env seed should be AIM_ENV_FILE plus the script directory, got {candidates}"
    )
    assert not any(os.path.abspath(os.getcwd()) == os.path.dirname(c) for c in candidates), (
        "the working directory is not a safe place to look for configuration"
    )
