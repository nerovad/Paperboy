"""bin/deploy-aim-workers ships code and config together, and safely.

The share copy of .env used to be maintained by hand, which is how it came to
be missing AIM_AI_QUEUE_DIR while the repo copy had it. Plan step 0.7.
"""
import hashlib
import os
import subprocess

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
        return subprocess.run(
            [SCRIPT, "--lockbox", str(lockbox), "--env-file", str(env_file),
             "--target", str(target), *extra],
            capture_output=True, text=True,
        )

    run.lockbox = lockbox
    run.env_file = env_file
    run.target = target
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
