"""Vendor names: the alias cascade and the per-vendor rules, fed from tables.

The matching logic is v1's, unchanged. What changed is where the answers come
from: the aliases and rules are read from `aim.vendor_aliases` and
`aim.vendor_rules` by the worker and passed in as plain dicts, so this module
touches no file and no database. An alias the AI smart match learns is
returned to the caller, which writes it to the table.
"""
import json
import os

from thefuzz import fuzz, process


class Match:
    """The outcome of normalising one extracted vendor name."""

    def __init__(self, normalized=None, known=False, learned=None):
        self.normalized = normalized
        self.known = known
        # (extracted, normalized, note) when the AI smart match decided a
        # near miss was the same company, for the caller to record.
        self.learned = learned


def normalize_vendor_name(extracted_name, aliases, ask_model=None):
    """v1's cascade: exact, fuzzy at 95, then the model for a near miss at 75.

    `aliases` maps an extracted spelling to the official name. `ask_model`
    takes a prompt and returns the model's text; None skips the third step.
    """
    if not extracted_name:
        return Match()

    # 1. Direct match, case insensitive.
    wanted = extracted_name.lower().strip()
    for raw, normalized in aliases.items():
        if wanted == raw.lower().strip():
            return Match(normalized, True)

    if not aliases:
        return Match()

    # 2. Fuzzy match at 95%+.
    known_raws = list(aliases.keys())
    best_match, score = process.extractOne(extracted_name, known_raws, scorer=fuzz.token_sort_ratio)
    if score >= 95:
        return Match(aliases[best_match], True)

    # 3. The model decides a near miss (75%+): a typo, a branch number, a
    # legal suffix. A yes is learned as a new alias.
    if score >= 75 and ask_model is not None:
        candidate = aliases[best_match]
        prompt = (
            f"Is the extracted vendor name '{extracted_name}' just a typo, branch number, or legal suffix variation "
            f"of the known company '{candidate}'? "
            "Reply strictly with YES or NO."
        )
        try:
            answer = (ask_model(prompt) or "").strip().upper()
        except Exception:
            answer = ""
        if "YES" in answer:
            return Match(candidate, True, learned=(extracted_name, candidate, "AI Smart Match Typos/Suffixes"))

    # 4. Unknown vendor: a person decides.
    return Match()


def rules_for(vendor_name, rules):
    """The rule text for a vendor, or ''. `rules` maps official name to text."""
    if not vendor_name:
        return ""
    return (rules.get(vendor_name) or "").strip()


def field_alias_text(path):
    """The global prompt hint built from field_aliases.json, or ''."""
    if not path or not os.path.exists(path):
        return ""
    try:
        with open(path, "r", encoding="utf-8") as handle:
            aliases = json.load(handle)
        instructions = []
        for field, phrases in aliases.items():
            if phrases:
                formatted = ", ".join(f"'{p}'" for p in phrases)
                instructions.append(f"{formatted} all map to {field}")
        if instructions:
            return f"(Note: {'. '.join(instructions)})."
    except Exception as e:
        print(f"    [!] Failed to read field aliases: {e}")
    return ""
