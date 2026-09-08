"""The harness itself: prove it isolates tests from the real machine."""
import os


def test_the_real_environment_is_not_visible():
    assert not [n for n in os.environ if n.startswith("AIM_")], (
        "an AIM_* variable leaked from the real environment into a test"
    )


def test_fake_environment_points_everything_at_a_temp_directory(fake_environment):
    for name, value in os.environ.items():
        if name.startswith("AIM_") and os.path.isabs(value):
            assert str(fake_environment) in value or "aim.env" in value, (
                f"{name} points outside the temp tree: {value}"
            )


def test_fake_environment_creates_nothing_on_disk(fake_environment):
    assert not fake_environment.exists()


def test_queue_tree_builds_every_managed_directory(queue_tree, pipeline):
    for directory in pipeline.MANAGED_DIRECTORIES:
        assert os.path.isdir(directory)


def test_queue_tree_can_stage_an_invoice(queue_tree):
    folder = queue_tree.add_invoice(
        "AIM_AI_QUEUE_DIR", "0000_Smith_123", payload={"vendor_name": "ACME"}
    )

    assert os.path.isfile(os.path.join(folder, "0000_Smith_123.json"))
    assert os.path.isfile(os.path.join(folder, "0000_Smith_123.pdf"))
