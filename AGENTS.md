# AI Instructions

- Generated Ruby conforms to `.rubocop.yml`.
- CI Pipeline requirements does not report errors:
  * bundle exec rubocop
  * bundle exec brakeman
  * bundle exec bundle-audit check
  * bundle exec rake test
  * Use 10.135.204.161 when GSASQL16 cannot be resolved
- Tests use SQL Server, not SQLite. `config/database.yml` accepts
  `PAPERBOY_TEST_DATABASE` when the default `Paperboy_Test` database is
  unavailable; for example:
  `PAPERBOY_TEST_DATABASE=Paperboy_Test0 bundle exec rake test`
- The configured test database is a scratch base. Rails test setup creates
  schema-loaded, per-worker databases with a run identifier and worker suffix
  for parallel tests, then drops them after the run. The test login therefore
  needs permission to create and drop databases and load the schema.
- Never point tests at `Paperboy_Dev`, staging, or production data. If
  `GSASQL16` cannot be resolved, use `10.135.204.161` for `GSABSS_HOST`.
- Propose git commit message.
  * Prose limited to 72 characters
  * Blank Line
  * Description lines limited to 80 characters
  * Do not indent proposed commit
- Git
  * use git mv when moving files

## Stylesheets

SCSS is compiled by **Dart Sass** (`dartsass-rails` + `sass-embedded`).
Sprockets only serves and digests the result. Source lives in
`app/assets/stylesheets/`, entrypoint `application.scss`; the compiled
output lands in `app/assets/builds/application.css`, which is generated
and gitignored — never edit or commit it.

Modern CSS is fully supported. Write it directly:

```scss
max-height: min(30.6rem, calc(100vh - 32rem));
height: clamp(18rem, 50vh, 36rem);
width: max(20rem, 50%);
inset: 0;
gap: 1rem;
```

Rules:

- **Never reintroduce `sass-rails`, `sassc-rails` or `sassc`.** They pull
  in libsass, which has been end-of-life since 2020. libsass parses
  `min()` and `max()` as Sass numeric functions, so
  `min(30.6rem, calc(100vh - 32rem))` fails to compile. That took staging
  down on 2026-08-24.
- **Never wrap CSS in `unquote()`** to sneak it past the compiler. That
  was a libsass workaround. Dart Sass emits modern CSS verbatim.
- **Never use global built-in Sass functions** — `darken()`, `lighten()`,
  `saturate()`, `transparentize()`, `unquote()` and friends are removed
  in Dart Sass 3.0. Load the module instead:

  ```scss
  @use "sass:color";
  border-color: color.adjust($border-color, $lightness: -10%);
  ```

- **Never use `@import`.** It is deprecated and is removed in Dart Sass
  3.0. Load what a partial needs with the module system:

  ```scss
  @use "base/tokens" as *;   // design tokens, unnamespaced
  ```

  Every partial that references a `$token` must `@use` it itself --
  `@use` is file-scoped, so nothing leaks in from `application.scss` the
  way `@import` used to.
- New stylesheets are partials `@use`d by `application.scss`. A second
  top-level entrypoint needs a `config.dartsass.builds` entry or it is
  never compiled.

`test/lib/stylesheet_conventions_test.rb` enforces all of the above, so a
regression fails `bundle exec rake test` rather than a deploy. A clean
build prints no deprecation warnings at all -- if you see one, something
in the list above came back.

### Working on CSS locally

Run `bin/dev` — it starts `dartsass:watch` alongside the server, so a
saved `.scss` rebuilds in about 100ms and a browser refresh shows it.

Keep `public/assets` empty on your workstation. sprockets-rails resolves
`[:manifest, :environment]` -- manifest first -- so a precompiled manifest
takes priority over live compilation and freezes your CSS until
`assets:clobber` runs. With nothing precompiled, resolution falls through
to live compilation and the watcher's output is served immediately. If you
ever precompile locally, `bin/rails assets:clobber` undoes it.

The deploy scripts are a different story: `bin/deploy-dev`,
`bin/deploy-stage` and `bin/deploy` all clobber and precompile, and must.
nginx on those boxes serves `/assets/` straight from disk
(`try_files $uri =404`, see `config/nginx/`) and never falls back to
Rails, so the digested files have to exist or every asset 404s and the app
renders as unstyled HTML.

For the same reason, never set `config.assets.debug = true` in
`development.rb` -- the dev server runs that environment behind nginx, and
debug mode emits `/assets/application.debug-<digest>.css`, a filename
`assets:precompile` never writes.

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
- There is no `.button` class. Billing and Data Runner used to define
  their own `.button` / `.button.primary` / `.button.danger` families;
  both are gone. Use `.btn`.

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

## Submission history

Every submission keeps two histories, both rendered by
`SubmissionHistoriesController` as fragments the shared `history-modal`
Stimulus controller fetches on demand:

| History | Table | Written by | Shown to |
|---------|-------|------------|----------|
| Status  | `status_changes` | `TrackableStatus` | anyone whose form template enables the `status_history` inbox button |
| Edit    | `record_edits`   | `AuditableEdits`  | anyone who may edit the submission |

**Edit History is not a configurable button.** It rides along with the Edit
button everywhere Edit appears — `inbox/_dynamic_buttons.html.erb`, the CIR
row in `inbox/queue.html.erb`, and `shared/_readonly_record.html.erb` — so a
form is auditable without anyone switching it on. Do not add `edit_history`
to `Forms::Template::INBOX_BUTTON_TYPES`; that would make it opt-in again.

Visibility follows the edit right, not view access: `SubmissionPolicy`
`action: 'edit'` gates the endpoint, the inbox button and the detail-page
section alike. A trail names who changed what, so whoever may rewrite a
submission may see who already has.

Rules:

- **Every new form model includes `AuditableEdits`**, directly or through
  `TrackableStatus` (which includes it). `FormGenerator` and
  `lib/generators/paperboy_form` both emit it; a hand-written model has to
  say so itself. `test/models/auditable_edits_test.rb` fails the build if a
  form under `app/controllers/forms/` has a model that doesn't.
- `AuditableEdits` writes one `RecordEdit` per column from an `after_update`.
  A write that skips callbacks (`update_column`, as
  `Reassignable#reassign_to!` does) leaves no trace, so such a caller must
  ask for the audit explicitly with `record_out_of_band_edit`.
- Anything happening after an edit is captured belongs in
  `#after_edits_captured`, not in a second `after_update`. `TrackableStatus`
  overrides it to mail edit subscribers, naming the exact rows the save wrote.
- A save that skips the audit needs a column in `AuditableEdits::IGNORED_COLUMNS`,
  not a conditional at the call site.
- Raw stored values are unreadable in a trail (`agency: 12 → 15`), so
  `Forms::AuditValue` resolves org and employee ids to names. Add a column to
  its `LOOKUPS` / `MULTI_VALUE` tables rather than formatting in a view. Every
  lookup crosses to GSABSS and falls back to the raw value, so it must stay
  best-effort.
