# AI Instructions

- Generated Ruby conforms to `.rubocop.yml`.
- CI Pipeline requirements:
  * bundle exec rubocop
  * bundle exec brakeman
  * bundle exec bundle-audit check
  * bundle exec rake test
- Propose git commit message.
  * Prose limited to 72 characters
  * Blank Line
  * Description lines limited to 80 characters
- Git
  * use git mv when moving files

## Buttons

All action buttons use one shared system, defined in
`app/assets/stylesheets/components/_buttons.scss`. That file is the only
place button colours and sizes are declared.

Markup is always `.btn`, plus at most one colour variant and at most one
size modifier:

```erb
<%= link_to "View PDF", path, class: "btn pdf" %>
<%= button_to "Approve", path, method: :patch, class: "btn approve" %>
<button type="button" class="btn deny compact">Remove</button>
```

The inbox queue action row (`app/views/inbox/_dynamic_buttons.html.erb`)
is the reference implementation — new buttons should look like they
belong next to those.

Colour variants:

| Variant           | Use for                                   |
|-------------------|-------------------------------------------|
| *(none)*          | neutral secondary action (slate)          |
| `approve`         | confirm, save, submit, primary affirmative |
| `deny`            | reject, delete, destructive               |
| `pdf`, `secondary`| navigation / view actions (navy)          |
| `edit`, `warning` | edit, amend, caution (amber)              |
| `reassign`        | reassignment (blue)                       |
| `take-back`       | reclaim (teal)                            |
| `status-history`  | history / audit views (slate)             |
| `info`            | informational (cyan)                      |
| `close-panel`, `clear-filters` | quiet dismissals             |
| `ghost`           | lightest weight; light fill, dark text    |
| `active`          | selected item in a filter/toggle group    |

Size modifier: `compact` (also accepted: `btn-sm`).

Rules:

- Never invent a new `.btn` colour in a page stylesheet. Add the variant
  to `_buttons.scss` so it works app-wide, or reuse an existing one.
- Never write a bare `.btn` expecting a page rule to colour it. A `.btn`
  with no variant is already a complete, visible slate button.
- Page stylesheets may only adjust a button's *layout* (margin,
  alignment, grid placement) — never its background, text colour,
  height, padding, radius, or font.
- `btn-primary` / `btn-secondary` / `btn-danger` / `btn-info` are legacy
  aliases kept so old markup renders. Do not use them in new code.

Not part of this system, and deliberately styled on their own — leave
them alone:

- `.form-btn` / `.form-btn--*`: submit, next and back controls inside a
  form body.
- Profile dropdown entries (`.dropdown-content a`, `.logout-btn`): plain
  links styled by `layout/_header.scss`. Do not add `.btn` to them.
- Sidebar and nav links, `.information-trigger`, `.cc-trigger`,
  `.hamburger-btn`, and other one-off UI affordances.

## Modals

All dialogs use one shared shell, defined in
`app/assets/stylesheets/components/_modals.scss`. That file is the only
place a modal shell is declared.

```erb
<div class="pb-modal-backdrop" hidden>
  <div class="pb-modal" role="dialog" aria-modal="true" aria-labelledby="x-title">
    <div class="pb-modal__header">
      <h3 id="x-title">Title</h3>
      <button type="button" class="pb-modal__close" aria-label="Close">✕</button>
    </div>
    <div class="pb-modal__body">…</div>
    <div class="pb-modal__actions">
      <button type="button" class="btn">Cancel</button>
      <button type="button" class="btn approve">Confirm</button>
    </div>
  </div>
</div>
```

`app/views/shared/_deny_modal.html.erb` is the reference implementation.

Parts: `pb-modal-backdrop`, `pb-modal`, `pb-modal__header`,
`pb-modal__close`, `pb-modal__body`, `pb-modal__message`,
`pb-modal__actions`. Size modifiers: `pb-modal--lg` (600px),
`pb-modal--xl` (720px); the default is 520px.

Put `pb-modal__actions` inside `pb-modal__body` when the buttons must sit
inside a `<form>`; put it as a direct child of `pb-modal` when it should
be a footer pinned below a scrolling body. Both are styled.

### Never use a native browser dialog

`window.alert`, `window.confirm` and `window.prompt` render as browser
chrome ("localhost says…") and must not appear anywhere in the app. Use
the helpers in `app/javascript/pb_modal.js`, which build the markup
above:

```js
import { pbConfirm, pbAlert } from "pb_modal"

if (await pbConfirm({ title: "Delete group", message: "…",
                      confirmLabel: "Delete", confirmVariant: "deny" })) { … }
await pbAlert({ title: "Not saved", message: "…" })
```

In views, `data: { turbo_confirm: "…" }` is correct and preferred —
`application.js` points `Turbo.config.forms.confirm` at `pbConfirm`, so
it renders the shared modal. Add `data: { confirm_title: "…" }` to set
the heading and `data: { confirm_label: "…" }` to set the button text;
the button turns red automatically when the control that triggered it
carries `deny`, `btn-danger` or `danger`.

Do not use `data: { confirm: "…" }` — that is Rails UJS syntax, which
Turbo ignores, so the action proceeds with no confirmation at all.

Rules:

- Never build a new modal shell in a page stylesheet. Add a modifier to
  `_modals.scss` instead.
- A page stylesheet may style a dialog's *contents* (the column
  customizer's chip lists, the status timeline) but not its shell.
- Every modal needs `role="dialog"`, `aria-modal="true"`, a label
  (`aria-labelledby` or `aria-label`) and a `pb-modal__close` button.

Not part of this system, and deliberately left alone: the form builder's
`.modal` / `.modal-content` / `.form-builder-modal` shell in
`pages/_form_templates.scss`, which is entangled with
`form_templates/edit.html.erb`.
