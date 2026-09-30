"""v1 keeps no copies of what v2 owns.

v2 is the live worker; v1 is stopped and awaiting retirement. The helpers the
two have in common live once, in v2, and v1 imports them (see "SHARED WITH
v2" in pipeline_common). Two things cannot be imported, and these tests hold
them equal instead:

* DOCUMENT_TYPES is written out in pipeline_common because
  test/lib/aim/document_types_test.rb reads it from that file.
* field_aliases.json and _prepare_aim_environment.bat must sit in each
  deployed folder: bin/deploy-aim-workers ships v1 and v2 as separate flat
  folders, v1's field aliases are found through AIM_FIELD_ALIASES_FILE
  against AIM_PROGRAM_DIR, and every .bat launcher calls the one beside it.
"""
import filecmp
import os

import pytest

REPO_ROOT = os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
)
WORKER_DIR = os.path.join(REPO_ROOT, "script", "python", "aim")
V2_DIR = os.path.join(WORKER_DIR, "v2")


def test_v1_uses_the_v2_helpers_themselves(pipeline):
    import cleaning
    import invoice_models
    import worker_common

    assert pipeline.InvoiceData is invoice_models.InvoiceData
    assert pipeline.DocumentManifest is invoice_models.DocumentManifest
    assert pipeline.normalize_document_type is invoice_models.normalize_document_type
    assert pipeline.sanitize_data is cleaning.sanitize_data
    assert pipeline._clean_money is cleaning.clean_money
    assert pipeline.is_file_stable is worker_common.is_file_stable
    assert pipeline.pdf_page_to_image is worker_common.pdf_page_to_image


def test_the_document_types_written_out_for_rails_match_v2(pipeline):
    import invoice_models

    assert pipeline.DOCUMENT_TYPES == invoice_models.DOCUMENT_TYPES
    assert pipeline.UNKNOWN_DOCUMENT_TYPE == invoice_models.UNKNOWN_DOCUMENT_TYPE


@pytest.mark.parametrize("name", ["field_aliases.json", "_prepare_aim_environment.bat"])
def test_files_each_deployed_folder_needs_are_the_same_in_both(name):
    assert filecmp.cmp(os.path.join(WORKER_DIR, name), os.path.join(V2_DIR, name), shallow=False), (
        f"{name} differs between v1 and v2. Both folders ship their own copy; change them together."
    )


def test_the_watcher_places_v2s_bu_readme(import_worker):
    watcher = import_worker("00_Ingestion_Watcher")

    assert watcher.BU_README_TEMPLATE == os.path.join(V2_DIR, "BU_FOLDER_README.txt")
    assert os.path.isfile(watcher.BU_README_TEMPLATE)
