"""What the models are asked for, and what they answer with.

Copied from v1's pipeline_common and 01_AI_Extraction_Worker so v2 has no
import dependency on the v1 pipeline. The prompts and rules are unchanged.
"""
from typing import Optional

from pydantic import BaseModel, Field, field_validator, model_validator

# The kinds of document AIM handles. Every type flows through the same
# states; the type decides only what happens at the end. `Unknown` is not a
# verdict but a placeholder -- what the model says when it cannot tell -- and
# AIM staff replace it in review before the invoice reaches a user.
DOCUMENT_TYPES = ("Invoice", "Memo", "Credit", "Coupon", "Statement", "Unknown")
UNKNOWN_DOCUMENT_TYPE = "Unknown"

# How the models are told the types apart. Both the text pass and the vision
# pass read this one definition, so the two cannot drift.
DOCUMENT_TYPE_GUIDE = (
    "Classify the document_type as exactly one of: "
    + ", ".join(f"'{name}'" for name in DOCUMENT_TYPES) + ". "
    "Invoice: a bill for goods or services with an amount due. 'Member Statement' and "
    "'Customer Receipt' documents from stores such as Home Depot are Invoices. "
    "Statement: an account summary listing several invoices, payments or a running balance, "
    "rather than a bill for one purchase. "
    "Credit: a credit memo, credit note or refund that reduces what is owed. "
    "Memo: a memo or letter asking for or authorising a payment that is not a vendor's invoice, "
    "such as a debit memo or an internal payment memo. "
    "Coupon: a payment coupon or remittance slip sent with a payment, such as the tear-off stub "
    "of a utility or loan bill. "
    "Unknown: anything else, such as a letter or a notice, or when you cannot tell."
)


def normalize_document_type(value):
    """One spelling for a document type, and `Unknown` for anything else."""
    if isinstance(value, str):
        wanted = value.strip().strip("'\"").casefold()
        for name in DOCUMENT_TYPES:
            if name.casefold() == wanted:
                return name
    return UNKNOWN_DOCUMENT_TYPE


# The money fields whose being handwritten sends an invoice to a person.
# Anything else written by hand -- a signature, initials, "OK to pay", a date
# or a PO number in pen -- does not, because every amount AIM needs can still
# be read.
HANDWRITTEN_FINANCIAL_FIELDS = ("subtotal", "tax", "total")


class InvoiceData(BaseModel):
    contains_multiple_invoices: Optional[bool] = False
    contains_handwritten_financials: Optional[bool] = False
    # Which money fields are handwritten. None means the model was not asked;
    # an empty list means it looked and found none.
    handwritten_financial_fields: Optional[list[str]] = None
    document_type: Optional[str] = None
    extracted_vendor_name: Optional[str] = None
    vendor_name: Optional[str] = None  # Normalized vendor
    invoice_date: Optional[str] = None
    invoice_number: Optional[str] = None
    invoice_number_label: Optional[str] = None
    invoice_total: Optional[str] = None
    order_number: Optional[str] = None
    customer_number: Optional[str] = None

    @field_validator("customer_number", "invoice_number", "order_number", "invoice_total", mode="before")
    @classmethod
    def reject_hallucinated_long_strings(cls, v):
        if isinstance(v, str) and len(v) > 50:
            return None
        return v

    # Only a value actually given is spelled; a field left at its default
    # stays None, so merge_vision_fields can still tell "not yet answered"
    # from "answered Unknown".
    @field_validator("document_type", mode="before")
    @classmethod
    def spell_document_type(cls, v):
        return normalize_document_type(v)

    @field_validator("handwritten_financial_fields", mode="before")
    @classmethod
    def keep_only_money_fields(cls, v):
        if v is None:
            return None
        named = {str(field).strip().lower() for field in v if field is not None}
        return [field for field in HANDWRITTEN_FINANCIAL_FIELDS if field in named]

    # When the model has named the handwritten money fields, the flag follows
    # the list and nothing else. With no list at all, the flag is left as
    # given.
    @model_validator(mode="after")
    def flag_follows_the_fields(self):
        if self.handwritten_financial_fields is not None:
            self.contains_handwritten_financials = bool(self.handwritten_financial_fields)
        return self


class ManifestItem(BaseModel):
    vendor_name: Optional[str] = "Unknown"
    invoice_number: Optional[str] = "Unknown"
    pages: list[int]


class DocumentManifest(BaseModel):
    invoices: list[ManifestItem]


class Phase1Data(BaseModel):
    contains_multiple_invoices: bool
    is_high_confidence: bool
    # The enum constrains what the model may answer; the field itself stays a
    # plain string so an off-list answer is spelled by normalize_document_type
    # rather than failing validation as a hallucination.
    document_type: str = Field(json_schema_extra={"enum": list(DOCUMENT_TYPES)})
    extracted_vendor_name: Optional[str] = None


# The JSON the vision model must return.
VISION_SCHEMA = {
    "type": "object",
    "properties": {
        "document_type": {"type": "string", "enum": list(DOCUMENT_TYPES)},
        "extracted_vendor_name": {"type": "string"},
        "invoice_date": {"type": "string"},
        "invoice_number": {"type": "string"},
        "invoice_number_label": {"type": "string"},
        "invoice_total": {"type": "string"},
        "order_number": {"type": "string"},
        "customer_number": {"type": "string"},
        # Which money fields are handwritten, not whether there is any
        # handwriting at all.
        "handwritten_financial_fields": {
            "type": "array",
            "items": {"type": "string", "enum": list(HANDWRITTEN_FINANCIAL_FIELDS)}
        }
    },
    "required": [
        "document_type", "extracted_vendor_name", "invoice_date",
        "invoice_number", "invoice_number_label", "invoice_total",
        "order_number", "customer_number", "handwritten_financial_fields"
    ]
}

# A vision pass fills in what the text pass could not read. Two rules:
#   * A data field is filled only when it is still blank -- the first answer
#     wins, later passes do not overwrite it.
#   * A risk flag latches: any pass that raises it raises it for the invoice.
# The handwriting latch is per money field: the answer is the union of every
# pass, so a signature page cannot raise it and a handwritten total on page 4
# still does.
STICKY_TRUE_FIELDS = ("contains_handwritten_financials",)
UNION_FIELDS = ("handwritten_financial_fields",)


def merge_vision_fields(master_data, vision_data):
    """Merge one vision pass into the running answer."""
    for field in InvoiceData.model_fields:
        value = getattr(vision_data, field)

        if field in UNION_FIELDS:
            if value is not None:
                seen = set(getattr(master_data, field) or []) | set(value)
                setattr(master_data, field, [f for f in HANDWRITTEN_FINANCIAL_FIELDS if f in seen])
                master_data.contains_handwritten_financials = bool(seen) or bool(
                    master_data.contains_handwritten_financials)
            continue

        if field in STICKY_TRUE_FIELDS:
            if value:
                setattr(master_data, field, True)
            continue

        if getattr(master_data, field) is None and value is not None:
            setattr(master_data, field, value)
