"""bin/deploy-aim-workers --v2 ships the v2 worker to its own folder.

The v1 pipeline keeps deploying to AIM_PROGRAM_DIR exactly as before; --v2
takes script/python/aim/v2 to AIM_V2_PROGRAM_DIR, with the same provenance
check, rendered .env and backups.
"""
import os
import subprocess
import sys

import pytest

REPO_ROOT = os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
)
SCRIPT = os.path.join(REPO_ROOT, "bin", "deploy-aim-workers")
V2_DIR = os.path.join(REPO_ROOT, "script", "python", "aim", "v2")

ENV_BODY = """# a fake Paperboy environment
AIM_PROGRAM_DIR='E:\\AIM\\_PROGRAM'
AIM_V2_PROGRAM_DIR='E:\\AIM\\_PROGRAM2'
AIM_WINDOWS_QUEUE_BASE_PATH='E:\\AIM'
AIM_LINUX_QUEUE_BASE_PATH=/mnt/fake-aim-share
AIM_STORE_DIR='E:\\AIM\\_BACK_END\\_STORE'
ENTRA_ID_CLIENT_SECRET=super-secret
"""


@pytest.fixture
def deployment(tmp_path):
    lockbox = tmp_path / "LockBox"
    lockbox.mkdir()
    (lockbox / "Paperboy.env").write_text(ENV_BODY)
    env_file = tmp_path / ".env"
    env_file.write_text(ENV_BODY)
    target = tmp_path / "_PROGRAM2"
    target.mkdir()

    def run(*extra, target_dir=target):
        args = [SCRIPT, "--lockbox", str(lockbox), "--env-file", str(env_file)]
        if target_dir is not None:
            args += ["--target", str(target_dir)]
        return subprocess.run(args + list(extra), capture_output=True, text=True,
                              env={**os.environ, "AIM_DEPLOY_PYTHON": sys.executable})

    run.target = target
    return run


def test_v2_ships_the_v2_worker_and_not_the_v1_pipeline(deployment):
    result = deployment("--v2")

    assert result.returncode == 0, result.stderr
    assert f"Source: {V2_DIR}" in result.stdout
    for name in ("worker.py", "settings.py", "extraction.py", "store.py", "Run_AIM_Worker.bat",
                 "Aim_Invoices_MAPPING.json", "field_aliases.json", "BU_FOLDER_README.txt", "requirements.txt"):
        assert f"      {name}\n" in result.stdout, name
    assert "01_AI_Extraction_Worker.py" not in result.stdout
    assert "Dry run" in result.stdout


def test_v2_resolves_its_own_program_folder(deployment):
    result = deployment("--v2", target_dir=None)

    assert result.returncode == 0, result.stderr
    assert "Target: /mnt/fake-aim-share/_PROGRAM2" in result.stdout


def test_without_v2_the_v1_target_is_unchanged(deployment):
    result = deployment(target_dir=None)

    assert result.returncode == 0, result.stderr
    assert "Target: /mnt/fake-aim-share/_PROGRAM" in result.stdout
    assert "_PROGRAM2" not in result.stdout


def test_v2_apply_copies_every_file_and_the_env(deployment):
    result = deployment("--v2", "--apply")

    assert result.returncode == 0, result.stderr
    shipped = sorted(os.listdir(deployment.target))
    expected = sorted(name for name in os.listdir(V2_DIR)
                      if name.endswith((".py", ".bat", ".json", ".txt", ".md")))
    assert shipped == sorted(expected + [".env"])
    with open(deployment.target / ".env", encoding="utf-8") as handle:
        rendered = handle.read()
    assert "AIM_V2_PROGRAM_DIR" in rendered
    assert "ENTRA_ID_CLIENT_SECRET" not in rendered
