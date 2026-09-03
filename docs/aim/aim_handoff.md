# AIM Handoff

Date: 2026-08-05

## Repository

- Repo: `/home/gannon/gitea/Paperboy`
- Branch: `AIM_VendorReview`
- Primary TODO: `docs/aim/aim_todo.md`
- Current focus: Vendor Review workflow only.

Do not continue AIM feature work in the old standalone repo unless Joshua
explicitly asks. AIM is now being developed inside Paperboy.

## Important Constraint

Joshua's rule for this branch:

- Do not alter Paperboy folder structure, namespaces, or unrelated behavior.
- Keep changes AIM-specific.
- Config changes are allowed only when they are required for AIM and handled
  carefully.
- If a needed change affects non-AIM application behavior beyond config, stop
  and ask first.

## Current State

The branch currently has uncommitted work. Before changing anything, run:

```bash
git status --short
```

Known modified/new files at handoff:

- `app/assets/stylesheets/pages/_aim_invoices.scss`
- `app/controllers/aim/invoices_controller.rb`
- `app/controllers/concerns/aim/invoice_file_support.rb`
- `app/controllers/concerns/aim/invoice_queue_support.rb`
- `app/javascript/controllers/index.js`
- `app/views/aim/invoices/show.html.erb`
- `config/initializers/content_security_policy.rb`
- `docs/aim/aim_todo.md`
- `script/python/aim/01_AI_Extraction_Worker.py`
- `script/python/aim/04_alias_learner.py`
- `test/controllers/aim/invoices_controller_test.rb`
- `app/javascript/controllers/aim_ocr_controller.js`
- `app/services/aim/vendor_review_payload_service.rb`

Latest pushed commit before this in-progress work:

```text
3d84be1 Improve AIM vendor review workflow
```

## Dev Server

Paperboy dev server was restarted and is currently expected at:

```text
http://127.0.0.1:3001
```

Start command used:

```bash
set -a; source .env; set +a
mise exec -- bundle exec dotenv -f "$AIM_ROOT/_PROGRAM/.env" -- bundle exec puma -C config/puma/development.rb
```

The server was serving the updated CSP after restart. Header check showed:

```text
connect-src 'self' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com
worker-src 'self' blob: https://cdn.jsdelivr.net https://cdnjs.cloudflare.com
```

This matters because AIM OCR uses PDF.js and Tesseract workers.

## Vendor Review Work Done

The branch is moving Vendor Review from a plain text alias field toward a
controlled review action:

- Vendor Review now shows the AI-extracted vendor name as read-only.
- That extracted value should not be editable and should not have OCR.
- Staff can select an existing official vendor or type a new official vendor.
- Vendor Review has two real submit actions:
  - `Learn & Continue`
  - `Learn & Retry AI`
- Placeholder buttons exist for planned steps and use `*` suffix:
  - `Check Duplicates *`
  - `Run Vendor/BU Lookup *`
  - `Send to Manual Processing *`

The intended behavior:

- `Learn & Retry AI`: save the alias, then send the batch back through AI vision.
- `Learn & Continue`: save the alias, then use the metadata already extracted
  by vision and route onward without paying the vision cost again.

The `continue` path is still temporary. The real future path is in
`docs/aim/aim_todo.md` as `Post-Vendor Processing Step`.

## Python Pipeline Work Done

`01_AI_Extraction_Worker.py`:

- Unknown vendor routing now preserves the full metadata payload for Vendor
  Review instead of only BU/submitter.
- This is so Vendor Review can continue without rerunning vision when the user
  chooses `Learn & Continue`.

`04_alias_learner.py`:

- Reads `_LEARN.json["next_action"]`.
- Supports:
  - `continue_processing`
  - `retry_ai`
- Missing or unknown `next_action` falls back to retry AI for legacy safety.
- Writes/saves the alias, then routes based on the selected action.

Important: the live AIM learner still updates SQL. Earlier testing showed a
permission error writing `E:\AIM\_PROGRAM\vendor_aliases.json`, but SQL alias
write succeeded. Joshua adjusted permissions on the JSON file after that.

## OCR State

The inline OCR script was removed from the AIM invoice show view and replaced
with a Stimulus controller:

```text
app/javascript/controllers/aim_ocr_controller.js
```

It is registered in:

```text
app/javascript/controllers/index.js
```

The AIM review root has:

```erb
data-controller="aim-ocr"
data-aim-ocr-pdf-url-value="..."
```

Current expected OCR behavior:

1. Hard refresh the browser.
2. Click an `OCR` button.
3. Native PDF iframe hides.
4. Canvas OCR viewer appears.
5. Button changes to `Cancel`.
6. User drags a rectangle on the rendered page.
7. Tesseract writes recognized text into that field.

If setup fails, the page should now show:

```text
OCR could not start. Check the browser console for details.
```

Joshua reported before this fix that OCR did nothing in Chrome, Edge, and
Firefox. Retest OCR first.

The PDF iframe currently uses:

```text
#zoom=page-fit
```

Firefox honored this. Chrome/Edge did not. Joshua said this can be left alone
if it is browser behavior.

## Layout Work Done

The AIM invoice review page was tightened:

- Header spacing reduced so the document preview starts higher.
- Metadata action buttons use a compact shared AIM action strip.
- The compact button styling should apply across AIM queues, not only Vendor
  Review.
- The old `* Planned AIM workflow step` notice was removed because it was taking
  space.

Known current concern: confirm the compact button layout still looks acceptable
in Action Needed, Vendor Review, Low Confidence Review, and other AIM queues.

## Tests And Checks Already Run

Passed:

```bash
git diff --check
mise exec -- ruby -rerb -e "ERB.new(File.read('app/views/aim/invoices/show.html.erb')).src; puts 'erb ok'"
node --check app/javascript/controllers/aim_ocr_controller.js
mise exec -- bundle exec rubocop config/initializers/content_security_policy.rb app/controllers/aim/invoices_controller.rb app/controllers/concerns/aim/invoice_file_support.rb app/controllers/concerns/aim/invoice_queue_support.rb app/services/aim/vendor_review_payload_service.rb test/controllers/aim/invoices_controller_test.rb
set -a; source .env; set +a
mise exec -- bundle exec dotenv -f "$AIM_ROOT/_PROGRAM/.env" -- bundle exec rails runner "Rails.application.assets.find_asset('application.js'); Rails.application.assets.find_asset('application.css'); puts 'assets ok'"
```

Full Rails tests were not run successfully because the local `Paperboy_Test`
database is missing in this environment.

## Immediate Next Steps

1. Hard refresh the AIM page in the browser.
2. Retest OCR on at least one editable metadata field.
3. If OCR still appears dead, open browser dev tools and check console/network.
   The important questions are:
   - Is `aim_ocr_controller.js` loading?
   - Does the button change to `Cancel`?
   - Is PDF.js blocked?
   - Is Tesseract worker loading blocked?
4. Retest Vendor Review:
   - Existing official vendor selection.
   - New official vendor name.
   - `Learn & Continue`.
   - `Learn & Retry AI`.
5. Confirm `04_alias_learner.py` routes correctly for both actions.
6. Confirm SQL rows still land in:
   - `[GSA_Scan].[dbo].[Aim_Vendor_Aliases]`
   - `[GSA_Scan].[dbo].[Aim_Processing_Logs]`
   - `[GSA_Scan].[dbo].[Aim_Invoices]`

## Near-Term Design Direction

Keep this branch focused on Vendor Review. Other discussed items belong in the
TODO or placeholder UI unless Joshua explicitly broadens the branch.

Important future workflow:

```text
Vision extraction
  -> vendor recognition
  -> Vendor Review if unknown
  -> duplicate check
  -> vendor/BU lookup
  -> lookup review if multiple/no match
  -> final SQL queue
```

Vendor Review should eventually route to the post-vision pipeline rather than
directly to final SQL. The current `Learn & Continue` path is a temporary blunt
method so testing can continue.

## Proposed Commit Message For Current Work

```text
Improve AIM vendor review continuation

Preserve full vendor review metadata, add continue/retry alias actions,
compact AIM review actions, and move OCR behavior into a Stimulus controller.
```
