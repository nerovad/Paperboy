# AIM TODO

This list tracks Automated Invoice Management work now that AIM is being
integrated into Paperboy. Standalone AIM should not receive new feature work
unless explicitly needed for migration or production support.

## Planned Branch Sequence

- [ ] **`AIM_VendorReview`:** Finish the current Vendor Review workflow. Staff
  should be able to match an extracted vendor to an existing official SQL vendor
  name, type a new official vendor name, handle bad AI vendor matches, and see a
  clear error if the alias cannot be saved.

- [ ] **`AIM_QueueLabels`:** Improve queue clarity before adding more queues.
  Action Needed, Low Confidence Review, Vendor Review, Batch Split, and backend
  queues should show useful reasons such as missing fields, AI rejection,
  multiple lookup matches, or ready for SQL review instead of generic `Ready`.

- [ ] **`AIM_ManualProcessing`:** Add a controlled fallback path for invoices
  the AI cannot reliably process. This branch should add the Manual Processing
  queue, manual metadata entry form, lookup trigger, and actions that route
  invoices from other review queues into manual processing.

- [ ] **`AIM_DuplicateReview`:** Add duplicate invoice handling before final SQL
  submission. The system should check vendor, invoice number, BU, invoice date,
  and total against SQL, then route likely duplicates to a review queue where
  staff can compare the matching SQL record and either send anyway or reject.

- [ ] **`AIM_WorkerObservability`:** Make the pipeline workers record what they
  did, what failed, and why work was skipped. Today only
  `01_AI_Extraction_Worker.py` calls `write_log`; the ingestion watcher, SQL
  worker, batch splitter, and alias learner log nothing, and all worker output
  is `print()` to a console window that the `.bat` files never redirect to a
  file. This branch should land before `AIM_ErrorQueues`, because exposing
  `_ERROR_QUEUE` in Paperboy is actively misleading while most failures never
  become a ticket in the first place.

- [ ] **`AIM_ErrorQueues`:** Make technical pipeline failures visible in
  Paperboy. This should expose `_ERROR_QUEUE`, show reprocess failure tickets and
  marker files, and provide clear retry, manual processing, or archive paths.

- [ ] **`AIM_PipelineMaintenance`:** Clean up operational worker gaps. This
  branch should cover spool-state retention, spool-state visibility, queue path
  confirmation, processed-date output, and other small backend worker
  reliability fixes.

- [ ] **`AIM_SqlOutputMapping`:** Make final SQL output less hard-coded. This
  branch should design and implement configurable mapping for extracted invoice
  data, lookup data, duplicate/rejection decisions, approval data, and
  timestamps.

- [ ] **`AIM_Approvals`:** Build the user-facing invoice approval workflow in
  Paperboy. This is separate from staff backend queues: invoices ready for
  business approval should appear in Paperboy's inbox for assigned users or
  groups, with approval/rejection status saved in database-backed AIM records.

- [ ] **`AIM_VendorAdmin`:** Add longer-term vendor maintenance tools. This
  branch should support deleting bad aliases, renaming official vendors, and
  deciding whether the current alias table should become full official vendor
  records.

## Active In Paperboy

- [ ] **Vendor Review SQL Picker:** Finish the Paperboy vendor review flow so
  staff can select an existing official vendor from SQL or type a new official
  vendor name.

- [ ] **Bad Vendor Match Workflow:** Add a clear action for invoices where the
  AI recognized a vendor incorrectly and the extracted value should not be
  learned as an alias.

- [ ] **Manual Processing Queue:** Build a Manual Processing queue for invoices
  requiring full manual data entry before lookup and routing.

- [ ] **Manual Entry Form:** Let AIM staff manually enter invoice metadata,
  vendor, BU, invoice number, invoice date, total, and any fields required for
  lookup and SQL output.

- [ ] **Manual Lookup Trigger:** Add a staff action to run vendor/BU lookup after
  manual entry and show the lookup result or issue reason before routing onward.

- [ ] **Duplicate Invoice Review Queue:** Check extracted invoices against SQL
  before final routing using vendor, invoice number, BU, invoice date, and total.
  Route likely duplicates to a Duplicate Review queue that shows the matching
  SQL record details and allows staff to send anyway or reject.

- [ ] **Post-Vendor Processing Step:** Replace the temporary Vendor Review
  `continue_processing` handoff with the real post-vision pipeline:
  duplicate check, vendor/BU lookup, type-aware validation, and final SQL queue.

- [ ] **Vendor/BU Lookup Review Queue:** Add a SQL-backed lookup step after
  vendor normalization. One lookup match should enrich automatically; no matches
  or multiple matches should route to review with enough detail for staff to
  choose or manually enter the needed values.

- [ ] **Non-Invoice Document Types:** Plan credit, credit memo, coupon, and
  other applicable document-type handling with Fiscal before hard-coding invoice
  assumptions into validation or SQL output.

- [ ] **Manual Queue Routing Actions:** Add actions to send an invoice from
  Vendor Review, Action Needed, Low Confidence Review, or AI/error states into
  Manual Processing.

- [ ] **Action Needed Issue Reasons:** Show clear queue issue labels instead of
  generic `Ready`, such as `AI Rejected: UNKNOWN`, `Missing Required Fields`,
  `Multiple Lookup Matches`, `Ready for SQL Review`, or `Needs Review`.

- [ ] **Reject Workflow Notes:** Require a rejection comment, write it into
  metadata, expose rejected queue counts, allow rescue/reopen, and support final
  archive.

## Pipeline Integration

- [ ] **Python Worker Migration:** Move active AIM Python workers into Paperboy.
  This is being handled in a separate Codex session; avoid touching those files
  here unless directed.

- [ ] **Spool State Retention Policy:** Fix the spool marker lifecycle. The
  signature is `sha256(relative_path|size)`, written on every spool and never
  expired, so one successful run permanently blacklists that filename at that
  size in that folder. Confirmed 2026-08-05: all 23 files then sitting in
  `Invoices\` were silently skipped against 2026-08-04 markers. On a clean spool
  the file is moved out of the watch tree, so its absence is already the dedupe
  and the marker should be deleted immediately; retain a marker only when
  `source_delete_error` is set and the original is stranded, and add a TTL to
  those. Note that adding mtime to the signature does not solve re-import,
  because an Explorer drag-copy preserves the source mtime.

- [ ] **Spool State Visibility:** Document what `_SPOOL_STATE` means and add an
  admin-safe way to inspect or clear old spool markers when an invoice needs to
  be intentionally re-imported.

- [ ] **Watcher Silent Skip Logging:** Log every ingestion watcher skip. The
  already-spooled check, the failed-spool backoff, the file-stability gate, and
  the root-level-file skip all `continue` with no output at all, so a file being
  ignored looks identical to a watcher with nothing to do.

- [ ] **Image Conversion Failure Marker:** A `convert_image_to_pdf` failure
  prints, removes the destination folder, and continues without writing a
  failed-spool marker or an error ticket, so a corrupt image is retried every
  60 seconds indefinitely.

- [ ] **Worker Log Coverage:** Extend `write_log` or an equivalent helper to the
  ingestion watcher, SQL worker, batch splitter, and alias learner. Only
  `01_AI_Extraction_Worker.py` writes to `_Logs` today, so the CSV describes
  extraction only and says nothing about ingestion or routing.

- [ ] **Worker Console Capture:** Redirect each `*_Run_*.bat` launcher to a
  timestamped file under `_Logs`. Worker output is console-only today and is
  lost when the window scrolls or closes, and the crash handler only `pause`s.

- [ ] **Ingestion Source Delete Permission:** Grant the watcher service account
  NTFS delete rights on the BU subfolders under `Invoices\`. Spool markers from
  2026-08-04 record `[WinError 5] Access is denied`, so the watcher copies the
  PDF to `_AI_QUEUE`, cannot remove the original, and leaves it in the watch
  tree looking like an unprocessed invoice.

- [ ] **Error Queue Visibility:** Add `_ERROR_QUEUE` to the Paperboy AIM backend
  dashboard/list so technical pipeline failures are visible outside the server
  filesystem. This needs both a `BACKEND_QUEUES` entry and a `PATH_ENV` entry in
  `Aim::InvoiceDirectoryService`; neither exists today, so `path_for` returns
  `nil` and the folder cannot be reached from the UI at all.

- [ ] **Reprocess Failure Review:** Surface reprocess failures marked by
  `.ai_reprocess_error.json` and their `_ERROR_QUEUE/REPROCESS_ERROR_*` tickets,
  with instructions or actions for retrying, manual processing, or archiving.

- [ ] **Queue Path Confirmation:** Confirm every queue path points to `E:\AIM` /
  `\\gsa-scan02\aim` and is configurable from Paperboy environment variables.

- [ ] **Manual Processing Queue Folder:** Confirm the deployed queue folder name
  and env var for Manual Processing. Current Paperboy default is
  `_BACK_END/_MANUAL_PROCESSING` with `AIM_MANUAL_PROCESSING_DIR` override.

- [ ] **SQL Alias Source Of Truth:** Use SQL as the live source for vendor
  aliases. JSON should be treated only as a temporary worker fallback if it
  remains during migration.

- [ ] **SQL Alias Failure Handling:** Keep invoices in Vendor Review when SQL
  alias writes fail, and show a clear error.

- [ ] **Processed Date Fix:** Ensure SQL output populates `[processed date]` as
  well as `[processed timestamp]`.

- [ ] **SQL Output Mapping Design:** Draft configurable mapping for extracted
  invoice data, lookup data, approval data, rejection data, and timestamps.

## Later

- [ ] **Vendor Alias Admin Page:** Consider a Paperboy admin page for deleting bad
  aliases, renaming official vendors, and bulk cleanup. Short term, use SQL
  client for blunt maintenance.

- [ ] **Official Vendor Model:** If the blunt alias table becomes too limited,
  evaluate moving to `VendorID` plus official vendor records.

- [ ] **Paperboy Inbox Integration:** Make user-facing AIM approvals appear in
  Paperboy's existing work/inbox flow.

- [ ] **DB-Backed Approval Records:** Create Paperboy-owned AIM approval records
  with status, assignee/group, vendor, BU, total, selected lookup result,
  approval/rejection timestamps, and comments.
