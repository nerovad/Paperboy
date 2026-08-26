// app/javascript/choices_setup.js
//
// Shared configuration for every Choices.js dropdown in the app.
//
// Choices 10.2.0 reads an <option>'s label with `option.innerHTML`, which hands
// it the escaped HTML source — "OXNARD-2420 CELSIUS AVE, UNIT A &amp; B". With
// `allowHTML: false` it then writes that label back out with `innerText`, which
// renders the entity literally, so the dropdown shows "A &amp; B". Anything
// containing &, <, > or " is affected.
//
// Turning allowHTML on would line the two halves up, and that is what the
// library defaults to, but it is not safe here: the labels reaching Choices are
// not uniformly escaped. Server-rendered <option>s arrive escaped, while the
// controllers that call setChoices() (coa_billing_lookup, contractor_selects,
// coa_account_fields) pass plain decoded strings straight out of JSON. Writing
// those as HTML would be an injection hole.
//
// So keep allowHTML: false — every label is written as text and never parsed —
// and decode the entities the DOM path leaves behind, immediately before render.
// Labels with no "&" in them are returned untouched, which is every label from
// the setChoices path in practice.
//
// Fixed properly in Choices 11, which reads `option.label` (already decoded) and
// escapes on write. Upgrading renames the CSS classes that _choices.scss targets,
// so that is a bigger change than this bug warrants.

// Entity-decode via a textarea: its content is RCDATA, so the parser resolves
// entities but never builds elements or runs script from the string.
export function decodeEntities(value) {
  if (typeof value !== "string" || !value.includes("&")) return value;

  const decoder = document.createElement("textarea");
  decoder.innerHTML = value;
  return decoder.value;
}

function withDecodedLabel(data) {
  if (!data || typeof data.label !== "string") return data;

  return { ...data, label: decodeEntities(data.label) };
}

// Wraps the stock `item` (the selected chip) and `choice` (the dropdown row)
// templates, the only two that render a label. Optgroup headings are read from
// the element's `label` attribute rather than its innerHTML, so they arrive
// decoded already and need no wrapping.
function decodeLabelsInTemplates() {
  const base = window.Choices.defaults.templates;

  return {
    item(config, data, removeItemButton) {
      return base.item.call(this, config, withDecodedLabel(data), removeItemButton);
    },
    choice(config, data, selectText) {
      return base.choice.call(this, config, withDecodedLabel(data), selectText);
    }
  };
}

// Build the options for `new Choices(el, ...)`. Always go through this rather
// than passing a bare object, so a new dropdown cannot miss the fix.
export function choicesOptions(overrides = {}) {
  return {
    ...overrides,
    // After the spread, not before: neither of these is a caller's to change.
    // allowHTML: true would render the plain strings the setChoices() callers
    // pass as markup, and dropping the callback brings the doubled entity back.
    allowHTML: false,
    callbackOnCreateTemplates: decodeLabelsInTemplates
  };
}
