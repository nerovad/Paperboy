# AIM TODO

This list tracks Automated Invoice Management work now that AIM is being
integrated into Paperboy. Standalone AIM should not receive new feature work
unless explicitly needed for migration or production support.

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
