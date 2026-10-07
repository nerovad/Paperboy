# AI Instructions
## Ruby

- Generated Ruby conforms to `.rubocop.yml`.

## CI Pipeline
- run unit test and examine errors; f
  ```bash
     bin/unit-tests
  * Use 10.135.204.161 when GSASQL16 cannot be resolved
- Tests use SQL Server, not SQLite. `config/database.yml` accepts
  `PAPERBOY_TEST_DATABASE` when the default `Paperboy_Test` database is
  unavailable; for example:
  `PAPERBOY_TEST_DATABASE=Paperboy_Test bundle exec rake test`
- The configured test database is a scratch base. Rails test setup creates
  schema-loaded, per-worker databases with a run identifier and worker suffix
  for parallel tests, then drops them after the run. The test login therefore
  needs permission to create and drop databases and load the schema.
- Never point tests at `Paperboy_Dev`, staging, or production data. If
  `GSASQL16` cannot be resolved, use `10.135.204.161` for `GSABSS_HOST`.
## Software Changes
- Always use Workflow commands unless instructed otherwise
- Propose git commit message.
  * Prose limited to 72 characters
  * Prepend `#<issue-number>` to the issue title so Gitea links the commit
    to its issue
  * Blank Line
  * Description lines limited to 80 characters
  * Do not indent proposed commit
- Git
  * use git mv when moving files
## Workflow commands
The Paperboy repository uses issue-linked branches and worktrees for
implementation work. The commands below use the Gitea API and read `GITEA_TOKEN` from the
environment or the ignored `.env.local` file. `.env` is a LockBox copy and
keeps that token empty; `.env.local` is loaded second and wins. A linked
worktree without its own copy reads the shared checkout's files. Never
commit the token.

The local Gitea service is reached by IP from the sandbox. The ignored
`.env.local` should contain:

```dotenv
GITEA_URL=http://10.135.204.125:3000
GITEA_TOKEN=<local token value>
```

Keep the actual token value only in `.env.local` or the process environment;
do not replace the placeholder above in tracked documentation.

Create an issue before creating its branch. The body follows the issue
template for that type (`.gitea/issue_template/`). `--answers-file` is JSON
whose keys are the section ids from `bin/new-issue --type feature --fields`.
Prompt sections are objects. `--body-file` still works when the markdown
contains those sections. An empty template is refused.

```bash
bin/new-issue --type feature \
  --title "Short imperative title" \
  --answers-file /path/to/answers.json
```

Open a pull request from the same template source. The body follows
`.gitea/pull_request_template.md`. `--answers-file` is JSON keyed by the
section ids from `bin/create-pull-request --fields`. `verification` is an
object with `checks` and `checks_run`. The issue section is `Closes #<number>`.
An empty template is refused. `--issue` fills that section when the body
still says `Closes #`.

```bash
bin/create-pull-request \
  --title "Short imperative description (#123)" \
  --head issue/123-short-description \
  --answers-file /path/to/answers.json
```

The command supports `bug`, `feature`, `chore`, and `infrastructure` issue
types. Missing required options are prompted on a terminal. Use
`--no-milestone` to skip the optional milestone prompt.

Create or locate the issue worktree with its issue number:

```bash
cd "$(bin/wt 123)"
```

For interactive shells, source `bin/shell-init` once and use `wt 123` to
navigate directly:

```bash
source /path/to/Paperboy/bin/shell-init
wt 123
```

The short command resolves the local `issue/123-*` branch, uses the shared
checkout's `worktrees/123` directory even when invoked from a linked worktree,
and copies the main checkout's `.env` and `.env.local` when the worktree
does not already have them. An existing file is left unchanged. Use
`bin/wt list` to see worktrees and `bin/wt clean 123` to clean up a
merged issue. The full `bin/worktree` branch-name commands remain available
for scripts.

At the start of every coding session, run `bin/wt context` and verify that the
reported current worktree and branch match the requested issue. Work only in
that worktree; do not switch another shell's worktree or edit the shared
checkout unless the task explicitly targets it. Multiple sessions are safe
when each starts in its own linked worktree.

The branch must match `issue/<number>-<lowercase-slug>`. After the pull
request merges, update `master` and clean up the local worktree and branch:

```bash
git switch master
git pull --ff-only
bin/wt clean 123
```

Cleanup refuses the default branch, an unmerged branch, the current worktree,
or a dirty worktree. It never force-removes work.

Use the read-only status report to review issues, pull requests, milestones,
missing labels, missing milestones, stale work, and unlinked pull requests:

```bash
bin/status-report
```

Use `bin/update-issue` only for an explicit, approved issue update. It is
dry-run by default. `--title` replaces the title. `--type` with
`--answers-file` or `--body` replaces the body through the same issue
template and sets that type label, removing the other type labels. Load
issue shows the current labels, milestone, project, and column. The same
title, body, milestone, project, column, or type label is left unchanged.
The command does not close the issue.

```bash
bin/update-issue --issue 123 --add-label priority:normal
bin/update-issue --issue 123 --title "Short imperative title" \
  --type feature --answers-file /path/to/answers.json
bin/update-issue --issue 123 --add-label priority:normal --apply
```

See the [Gitea Workflow](http://10.135.204.125:3000/BSS/Paperboy/wiki/Gitea-Workflow)
wiki page for the complete workflow and project conventions.

## Wiki

Design notes live on the Gitea wiki, not under `docs/`:

`http://10.135.204.125:3000/BSS/Paperboy/wiki/`

`config/wiki_pages.yml` maps a repository path to a page slug. The page
address is that base URL plus the slug. A `keep: true` page is still read
from the checkout. A `keep: false` page is read from the wiki.

Before creating or changing a feature, read the wiki pages for that area.
Use Architecture for framework work. Use AIM Plan, AIM Handoff, and AIM Todo
for AIM. Use the OMS pages for OMS. Use Authentication Gem for
authentication. Use the map for any other area.

Fetch the Markdown with the wiki API. `content_base64` is the page body.
Read `GITEA_TOKEN` from the environment or `.env.local`. Do not print the token.

```bash
curl --fail-with-body --silent \
  -H "Authorization: token ${GITEA_TOKEN}" \
  -H 'Accept: application/json' \
  "${GITEA_URL%/}/api/v1/repos/BSS/Paperboy/wiki/page/Architecture"
```

A restart prompt names those wiki URLs and tells the next session to read
`AGENTS.md` from the checkout. It does not name a `docs/*.md` path, and it
is not saved as a new file under `docs/`.

`bin/wiki-publish` refreshes the wiki from the Markdown that stays in git.
It prints a plan unless `--apply` is given. Pages that moved out of `docs/`
are edited on the wiki. The rules in this file stay here. The Agents wiki
page is refreshed from this file.

## Environment files

`.env` is a verbatim copy of `LockBox/Paperboy.env`, written by
`bin/env-pull` and by every deploy. Never edit it: the next pull replaces
it, and `bin/deploy-aim-workers` refuses one that differs from LockBox. A
variable everyone needs is added to `LockBox/Paperboy.env`; one that belongs
to a single machine or person goes in `.env.local`, which wins over `.env`
and is never overwritten. `.env.local.example` lists the usual ones.

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

Run `bin/dev` — it starts `dartsass:watch` alongside the server and Solid
Queue, so a saved `.scss` rebuilds in about 100ms and a browser refresh
shows it. `bin/dev-local` is the same script under its own name.

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

## Submission comments

Every submission has one comment thread (`SubmissionComment`, table
`submission_comments`, polymorphic). A comment is text, attachments, or both.
`SubmissionCommentsController` renders the thread as one fragment,
`submission_comments/_thread`, which carries its own form; the
`comment-thread` Stimulus controller posts it and swaps in the answer.

**Comments is not a configurable button.** `inbox/_comments_button` sits in
every inbox action panel, copies included, and `shared/_readonly_record`
shows the thread on every submission page. Do not add `comments` to
`Forms::Template::INBOX_BUTTON_TYPES`.

Rules:

- **Visibility follows view access.** Reading, posting and downloading all
  ask `Forms::SubmissionAccess` (`can_view_submission?`). There are no
  internal-only comments: whatever is posted, the submitter can read.
- **Never link a comment's file with `url_for` or `rails_blob_path`.** Use
  `submission_comment_attachment_path`, which checks the viewer and streams
  the file as a download.
- A comment is not an edit. It writes nothing to `record_edits` or
  `status_changes` and must not touch the submission.
- An author may delete their own comment and a system admin any; nobody
  edits one.
- A new comment is the `comment_added` form subscription event. Immediate
  subscribers are mailed from `SubmissionComment`'s `after_create_commit`;
  digest subscribers are found by `Forms::SubscriptionDigest#comments`. The
  author is never mailed about their own comment.
- Allowed file types and limits live in `SubmissionComment::FILE_TYPES`,
  `MAX_FILES` and `MAX_FILE_SIZE`, not in the view.

## Publishing

An asset leaves the library through a **publish target** — one account on one
service (`Dam::PublishTarget`) — and every sending is a row
(`Dam::Publication`) that is kept whatever the outcome.

Six providers ship: YouTube, Vimeo, Instagram, Facebook, TikTok, and a custom
HTTP endpoint with headers typed into the form. Each is an adapter class under
`app/services/dam/publishing/`, registered in `Dam::Publishing::ADAPTERS`.

Rules:

- **A seventh service is a new adapter and one line in `ADAPTERS`.** Nothing
  else branches on the provider name: the form, the picker on an asset and the
  runner all ask the adapter what it takes (`media_types`), what the target
  form should ask for (`account_prompt`), what visibility choices it offers
  (`privacy_options`) and whether it signs in with OAuth (`oauth?`).
- **An adapter never sets a publication's status.** It returns a
  `Base::Result` or raises `Dam::Publishing::DeliveryFailed`;
  `Dam::Publishing::Runner` owns the row, the log and the Jobs feed entry.
- **Nothing publishes inside a request.** `PublicationsController#create`
  queues `Dam::PublishJob` and returns. The job has no `retry_on`: a retry
  would put the video up twice, so failures stop and the screen offers a
  retry that makes a *new* row.
- **Tokens are encrypted on the target; the client id and secret are not
  stored at all.** They belong to the installation, so they are per host in
  `.env` — `PUBLISH_YOUTUBE_CLIENT_ID`, `PUBLISH_VIMEO_CLIENT_ID`,
  `PUBLISH_META_CLIENT_ID` (Facebook and Instagram share one Meta app),
  `PUBLISH_TIKTOK_CLIENT_KEY`, each with its `_SECRET`. Every provider comes
  back to one address,
  `/digital_asset_management/publish_connections/callback`, which has to be
  registered with each of them by hand.
- **Instagram fetches rather than receives**, so it needs
  `PAPERBOY_PUBLIC_BASE_URL` set to an address this server answers on from
  outside. A publication in flight mints a single-use token that
  `DamMediaController` serves that one asset from, and only while the publish
  is running plus an hour.
- Publishing an asset is the `publish` feature grant; setting up and
  connecting targets is `publish_targets`, deliberately separate.

## DAM access rules

Feature grants decide which DAM *screens* someone reaches. Which *assets*
they see, and what they may do with each, is decided by access rules
(ACL > DAM Access Rules): `Dam::AccessRule` names a slice of the library
(an org window on the asset's `agency_id`…`unit_id`, plus metadata
conditions) and its grantees (groups, employees, org levels), with
Download / Share / Publish / Edit flags on top of View. An asset no active
rule matches is open to everyone; one a rule matches is open only to the
people a matching rule names. Uploaders and system admins are never
restricted.

Rules:

- **Every asset lookup in a DAM controller goes through `dam_access`.**
  Lists use `dam_access.viewable(scope)` or `permitted(scope, :download)`;
  a single asset uses `find_viewable_asset(id)`, never `Dam::Asset.find`.
  A capability the page did not offer is refused with
  `require_asset_capability(asset, :share)`, and views ask `dam_can?`.
- **Never link an asset's bytes with `url_for(asset.file)`** (or `.proxy`,
  `.thumbnail`). Stock Active Storage URLs never expire and check nobody.
  Use `dam_file_path(asset, :thumbnail)` / `dam_thumbnail_url` /
  `dam_preview_url` / `dam_original_url`, which mint a per-user token
  (`Dam::FileToken`) served by `DigitalAssetManagement::FilesController`.
- Feature grants still apply on top: a rule allowing Publish does not open
  the Publish screen to someone without the `publish` grant.
- Imported assets are filed under an org from their ResourceSpace text by
  `Dam::OrgFromMetadata`; `rake dam:file_assets_by_org` backfills.
