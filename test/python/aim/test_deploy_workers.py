"""bin/deploy-aim-workers ships code and config together, and safely.

The share copy of .env used to be maintained by hand, which is how it came to
be missing AIM_AI_QUEUE_DIR while the repo copy had it. Plan step 0.7.
"""
import hashlib
import os
import subprocess
import sys

import pytest

REPO_ROOT = os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
)
SCRIPT = os.path.join(REPO_ROOT, "bin", "deploy-aim-workers")
WORKER_DIR = os.path.join(REPO_ROOT, "script", "python", "aim")
STATE_FILES = {"vendor_aliases.json"}

ENV_BODY = """# a fake Paperboy environment
AIM_PROGRAM_DIR='E:\\AIM\\_PROGRAM'
AIM_WINDOWS_QUEUE_BASE_PATH='E:\\AIM'
AIM_LINUX_QUEUE_BASE_PATH=/mnt/fake-aim-share
AIM_AI_QUEUE_DIR='E:\\AIM\\_BACK_END\\_AI_QUEUE'
ENTRA_ID_CLIENT_SECRET=super-secret
POSTGRES_PASSWORD=another-secret
P2M_PRINTERS=99_Printers
"""


@pytest.fixture
def deployment(tmp_path):
    lockbox = tmp_path / "LockBox"
    lockbox.mkdir()
    (lockbox / "Paperboy.env").write_text(ENV_BODY)
    env_file = tmp_path / ".env"
    env_file.write_text(ENV_BODY)
    target = tmp_path / "_PROGRAM"
    target.mkdir()

    def run(*extra):
        # The script verifies the rendered .env with python-dotenv. Hand it the
        # interpreter running these tests, which has it; a bare python3 on PATH
        # generally does not, and the script refuses rather than skip the check.
        return subprocess.run(
            [SCRIPT, "--lockbox", str(lockbox), "--env-file", str(env_file),
             "--target", str(target), *extra],
            capture_output=True, text=True,
            env={**os.environ, "AIM_DEPLOY_PYTHON": sys.executable},
        )

    def plant(body):
        """Rewrite both copies, so provenance passes and the parse guard runs."""
        (lockbox / "Paperboy.env").write_text(body)
        env_file.write_text(body)

    run.lockbox = lockbox
    run.env_file = env_file
    run.target = target
    run.plant = plant
    return run


def test_dry_run_writes_nothing(deployment):
    result = deployment()

    assert result.returncode == 0, result.stderr
    assert "Dry run" in result.stdout
    assert os.listdir(deployment.target) == []


def test_dry_run_lists_what_it_would_copy(deployment):
    result = deployment()

    assert "pipeline_common.py" in result.stdout
    assert "requirements.txt" in result.stdout


def test_apply_copies_every_worker_file_intact(deployment):
    result = deployment("--apply")
    assert result.returncode == 0, result.stderr

    for name in os.listdir(WORKER_DIR):
        source = os.path.join(WORKER_DIR, name)
        if not os.path.isfile(source):
            continue
        if not name.endswith((".py", ".bat", ".json", ".txt", ".md")):
            continue
        if name in STATE_FILES:  # owned by the share, never shipped
            continue
        copied = os.path.join(deployment.target, name)
        assert os.path.isfile(copied), f"{name} was not deployed"
        assert (hashlib.md5(open(source, "rb").read()).hexdigest()
                == hashlib.md5(open(copied, "rb").read()).hexdigest()), name


def test_the_rendered_env_carries_every_aim_variable(deployment):
    deployment("--apply")
    rendered = (deployment.target / ".env").read_text()

    for name in ["AIM_PROGRAM_DIR", "AIM_WINDOWS_QUEUE_BASE_PATH",
                 "AIM_LINUX_QUEUE_BASE_PATH", "AIM_AI_QUEUE_DIR"]:
        assert f"{name}=" in rendered, f"{name} did not reach the share"


def test_the_rendered_env_carries_no_other_secrets(deployment):
    deployment("--apply")
    rendered = (deployment.target / ".env").read_text()

    assert "ENTRA_ID_CLIENT_SECRET" not in rendered
    assert "POSTGRES_PASSWORD" not in rendered
    assert "P2M_PRINTERS" not in rendered
    assert "super-secret" not in rendered


def test_a_repo_env_that_drifted_from_lockbox_is_refused(deployment):
    deployment.env_file.write_text(ENV_BODY + "AIM_SNEAKY_DIR=E:\\nowhere\n")

    result = deployment("--apply")

    assert result.returncode != 0
    assert "does not match" in result.stderr
    assert os.listdir(deployment.target) == [], "nothing should have been written"


def test_deploying_without_lockbox_is_refused(tmp_path):
    env_file = tmp_path / ".env"
    env_file.write_text(ENV_BODY)
    target = tmp_path / "_PROGRAM"
    target.mkdir()

    result = subprocess.run(
        [SCRIPT, "--env-file", str(env_file), "--target", str(target), "--apply"],
        capture_output=True, text=True, env={**os.environ, "LOCKBOX_DIR": ""},
    )

    assert result.returncode != 0
    assert "LockBox" in result.stderr
    assert os.listdir(target) == []


def test_skip_provenance_warns_loudly(deployment):
    result = deployment("--skip-provenance")

    assert result.returncode == 0
    assert "WARNING" in result.stdout


def test_live_vendor_aliases_are_never_overwritten(deployment):
    """The workers learn aliases into this file on the share.

    On 2026-09-08 the share had 907 keys and the repo copy 904; deploying it
    would have deleted three aliases learned in production.
    """
    live = deployment.target / "vendor_aliases.json"
    live.write_text('{"LEARNED ON THE SERVER": "Learned On The Server"}')

    result = deployment("--apply")

    assert result.returncode == 0, result.stderr
    assert "LEARNED ON THE SERVER" in live.read_text(), (
        "deployment clobbered the live vendor alias store"
    )
    assert "runtime state" in result.stdout


def test_replaced_files_are_kept_on_the_server(deployment):
    """Established scripts are moved aside, not overwritten.

    They run unattended on GSA-SCAN02, so the version that was working has to
    be one copy away on the server itself.
    """
    victim = deployment.target / "pipeline_common.py"
    victim.write_text("# the version that was running\n")

    result = deployment("--apply")
    assert result.returncode == 0, result.stderr

    import datetime
    dated = (deployment.target / "_PREVIOUS_SCRIPTS"
             / datetime.date.today().isoformat() / "pipeline_common.py")
    assert dated.is_file(), "the replaced script was not kept"
    assert dated.read_text() == "# the version that was running\n"
    assert victim.read_text() != "# the version that was running\n", "not replaced"


def test_a_second_deploy_does_not_clobber_the_first_backup(deployment):
    (deployment.target / "pipeline_common.py").write_text("# morning version\n")
    deployment("--apply")
    deployment("--apply")

    import datetime
    root = deployment.target / "_PREVIOUS_SCRIPTS"
    dated = root / datetime.date.today().isoformat() / "pipeline_common.py"
    assert dated.read_text() == "# morning version\n", "the first backup was overwritten"
    assert len(list(root.iterdir())) == 2, "the second deploy should make its own folder"


def test_the_deploy_says_the_rendered_env_parses_for_the_workers(deployment):
    result = deployment()

    assert "parses for the workers" in result.stdout, result.stdout


def test_a_value_the_workers_cannot_read_stops_the_deploy(deployment):
    """A value ending in a backslash. Ruby reads it, python-dotenv does not.

    LockBox carried AIM_WINDOWS_ROOT='E:\\' on 2026-09-21. python-dotenv took
    the closing quote as escaped, ran into the next line, and discarded both
    variables. pipeline_common will not start without AIM_BASE_DIR, so the file
    would have stopped every worker while Rails looked perfectly healthy.
    """
    deployment.plant(ENV_BODY + "AIM_WINDOWS_ROOT='E:\\'\nAIM_BASE_DIR='E:\\AIM'\n")

    result = deployment("--apply")

    assert result.returncode != 0, result.stdout
    assert "AIM_WINDOWS_ROOT" in result.stderr
    assert "AIM_BASE_DIR" in result.stderr
    assert not (deployment.target / ".env").exists()


def test_an_aim_value_built_from_a_stripped_variable_stops_the_deploy(deployment):
    """Only AIM_* ships. An AIM_* value built from anything else arrives empty.

    It reads correctly in the repo, where the whole environment is present, and
    resolves to nothing on the share. Nothing warns.
    """
    deployment.plant(ENV_BODY + "AIM_DERIVED=${GSABSS_ROOT}/invoices\n")

    result = deployment("--apply")

    assert result.returncode != 0, result.stdout
    assert "GSABSS_ROOT" in result.stderr
    assert not (deployment.target / ".env").exists()


# ---------------------------------------------------------------------------
# Resolving the target. Every test above passes --target, which is how the
# deploy came to aim at a directory literally named '${AIM_ROOT}' on
# 2026-09-22: LockBox's ROOT consolidation made AIM_LINUX_QUEUE_BASE_PATH
# read ${AIM_ROOT}/AIM, and the script read its values with grep, which hands
# back the reference unresolved. The workers read the same file with
# python-dotenv, which resolves it, so the deploy now does too.
# ---------------------------------------------------------------------------

INTERPOLATED_ENV_BODY = """# a fake Paperboy environment, ROOT-consolidated
AIM_ROOT={root}
AIM_PROGRAM_DIR='E:\\AIM\\_PROGRAM'
AIM_WINDOWS_QUEUE_BASE_PATH='E:\\AIM'
AIM_LINUX_QUEUE_BASE_PATH=${{AIM_ROOT}}/AIM
AIM_AI_QUEUE_DIR='E:\\AIM\\_BACK_END\\_AI_QUEUE'
"""


@pytest.fixture
def interpolated_deployment(tmp_path):
    """A deployment whose target must be resolved from an interpolated value."""
    root = tmp_path / "share"
    target = root / "AIM" / "_PROGRAM"
    target.mkdir(parents=True)

    body = INTERPOLATED_ENV_BODY.format(root=root)
    lockbox = tmp_path / "LockBox"
    lockbox.mkdir()
    (lockbox / "Paperboy.env").write_text(body)
    env_file = tmp_path / ".env"
    env_file.write_text(body)

    def run(*extra):
        return subprocess.run(
            [SCRIPT, "--lockbox", str(lockbox), "--env-file", str(env_file), *extra],
            capture_output=True, text=True,
            env={**os.environ, "AIM_DEPLOY_PYTHON": sys.executable},
        )

    run.target = target
    return run


def test_the_target_resolves_an_interpolated_base_path(interpolated_deployment):
    result = interpolated_deployment()

    assert result.returncode == 0, result.stderr
    assert f"==> Target: {interpolated_deployment.target}" in result.stdout
    assert "${AIM_ROOT}" not in result.stdout


def test_an_interpolated_target_is_deployed_to(interpolated_deployment):
    result = interpolated_deployment("--apply")

    assert result.returncode == 0, result.stderr
    assert (interpolated_deployment.target / "pipeline_common.py").is_file()
    assert (interpolated_deployment.target / ".env").is_file()
