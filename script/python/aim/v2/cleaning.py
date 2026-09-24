"""One spelling for every key field. Copied from v1's pipeline_common.

The vendor name, invoice number, total and date make up the business key,
so each has exactly one stored form. See the v1 docstrings for the cases
each rule was written for; they are kept here unchanged.
"""
import re
import unicodedata

from dateutil import parser as dateparser

from invoice_models import InvoiceData


def clean_text_field(v):
    """Tidy a key field's whitespace without editing what the vendor printed.

    Only what cannot survive a round trip is removed: control codes, and the
    invisible formatting codes such as a zero-width space that would make two
    identical-looking numbers compare unequal. Runs of whitespace collapse to
    one space. INV-2024/001 stays INV-2024/001.
    """
    if not v:
        return None
    kept = ''.join(
        c for c in str(v)
        if c.isspace() or unicodedata.category(c) not in ('Cc', 'Cf')
    )
    cleaned = re.sub(r'\s+', ' ', kept).strip()
    return cleaned if cleaned else None


def clean_money(v):
    """One spelling for an amount: an optional sign and exactly two decimals.

    "(100.00)" and "100.00-" are credits and keep their sign; "-0.00" folds to
    "0.00"; a comma used as the decimal separator is refused rather than
    guessed at, so the invoice goes to review instead of storing 1.23.
    """
    if not v:
        return None

    text = str(v).strip()

    negative = False
    bracketed = re.match(r'^\((.*)\)$', text)
    if bracketed:
        negative, text = True, bracketed.group(1).strip()
    if text.endswith('-'):
        negative, text = True, text[:-1].strip()

    if re.search(r',\d{1,2}$', text):
        return None

    digits = re.sub(r'[^0-9.\-]', '', text)
    if digits in ('', '-', '.', '-.', '--'):
        return None
    try:
        amount = float(digits)
    except ValueError:
        return None

    if negative:
        amount = -abs(amount)
    if amount == 0:
        amount = 0.0
    return f"{amount:.2f}"


def clean_date(v):
    if not v or not str(v).strip():
        return None
    try:
        return dateparser.parse(str(v), dayfirst=False).strftime("%Y-%m-%d")
    except (ValueError, OverflowError):
        return None


def sanitize_data(data: InvoiceData):
    if data.vendor_name:
        # A business key field, stored and exported as typed. Rewriting "&"
        # to "and" once changed it for 58 of the ~900 official vendors.
        data.vendor_name = data.vendor_name.strip() or None
    data.invoice_total = clean_money(data.invoice_total)
    data.invoice_date = clean_date(data.invoice_date)
    data.invoice_number = clean_text_field(data.invoice_number)
    data.order_number = clean_text_field(data.order_number)
    return data


def check_missing_fields(data: InvoiceData) -> list:
    missing = []
    if not data.vendor_name and not data.extracted_vendor_name:
        missing.append("Vendor Name")
    if not data.invoice_date:
        missing.append("Invoice Date")
    if not data.invoice_number:
        missing.append("Invoice Number")
    if not data.invoice_total:
        missing.append("Invoice Total")
    return missing


def apply_invoice_number_rules(data, document_text=None):
    if document_text:
        m = re.search(r'INVOICE\s+(\d+)\s+TOTAL', document_text, re.IGNORECASE)
        if m:
            data.invoice_number = m.group(1)
        if not data.order_number:
            mp = re.search(r'\bLAR\s*PO[:#\s]*([0-9]+)', document_text, re.IGNORECASE)
            if mp:
                data.order_number = mp.group(1)
    return data
