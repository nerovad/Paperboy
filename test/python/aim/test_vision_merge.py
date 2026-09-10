"""A vision pass that spots handwritten financials must be believed.

Every merge loop copied a field only when the running answer still held None,
and `contains_handwritten_financials` defaults to False. So the vision model's
answer was discarded every time and the routing check that sends the invoice
to Low Confidence Review had never fired. Plan step 1.5.
"""
import pytest


@pytest.fixture
def ai_worker(import_worker):
    return import_worker("01_AI_Extraction_Worker")


@pytest.fixture
def invoice(pipeline):
    return pipeline.InvoiceData


def test_the_handwriting_flag_survives_the_merge(ai_worker, invoice):
    master = invoice()
    vision = invoice(contains_handwritten_financials=True)

    ai_worker.merge_vision_fields(master, vision)

    assert master.contains_handwritten_financials is True


def test_the_flag_latches_across_passes(ai_worker, invoice):
    """Page 4 saying yes is not cancelled by page 1 saying no."""
    master = invoice()

    ai_worker.merge_vision_fields(master, invoice(contains_handwritten_financials=False))
    assert master.contains_handwritten_financials is False

    ai_worker.merge_vision_fields(master, invoice(contains_handwritten_financials=True))
    assert master.contains_handwritten_financials is True

    ai_worker.merge_vision_fields(master, invoice(contains_handwritten_financials=False))
    assert master.contains_handwritten_financials is True, (
        "a raised risk flag must not be lowered by a later pass"
    )


def test_a_blank_field_is_filled_from_vision(ai_worker, invoice):
    master = invoice(vendor_name="AIRGAS USA, LLC")
    vision = invoice(invoice_number="INV-10", invoice_total="1234.56")

    ai_worker.merge_vision_fields(master, vision)

    assert master.invoice_number == "INV-10"
    assert master.invoice_total == "1234.56"


def test_an_answer_already_found_is_not_overwritten(ai_worker, invoice):
    """The text pass read it; a later vision guess must not replace it."""
    master = invoice(invoice_number="INV-10")
    vision = invoice(invoice_number="WRONG-99")

    ai_worker.merge_vision_fields(master, vision)

    assert master.invoice_number == "INV-10"


def test_the_flag_is_what_routes_to_low_confidence_review(ai_worker, invoice):
    """The routing check reads the merged flag, so the merge is the whole bug."""
    master = invoice()
    ai_worker.merge_vision_fields(master, invoice(contains_handwritten_financials=True))

    assert getattr(master, "contains_handwritten_financials", False), (
        "this is the expression 01_AI_Extraction_Worker uses to route the "
        "invoice to LOW_CONFIDENCE_REVIEW_DIR"
    )
