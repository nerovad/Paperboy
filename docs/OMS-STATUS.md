# OMS Status

## Purpose

`OMS Status` is a Print 2 Mail sidebar link to the OMS upload status
screen. It is a read-only status view. The link does not start a Data Runner
refresh, upload files, or change an OMS record directly.

The user-facing name is `OMS Status`, while the implementation retains the
older `uploads` names for the controller, model, view directory, database
tables, and date-parameter scope. This avoids an unnecessary data migration:

| Concern | Current name |
| --- | --- |
| Sidebar label | `OMS Status` |
| Feature key | `p2m:oms_status` |
| Route helper | `p2m_oms_status_path` |
| URL | `/p2m/oms_status` |
| Controller action | `P2m::OmsUploadsController#index` |
| View | `p2m/oms_uploads/index` |
| Model | `P2m::OmsUpload` |
| Database table | `p2m_oms_uploads` |
| Date parameter scope | `oms_uploads` |

## Sidebar visibility

The sidebar renders the link only when:

```ruby
can_use_app_feature?('p2m', 'oms_status')
```

The feature is declared in `AppFeature::FEATURES['p2m']` with the label
`OMS Status`. Administrators manage it as an individual Print 2 Mail feature
in ACL. The default ACL data grants `p2m:oms_status` to the configured GSA
organization entry.

`can_use_app_feature?` returns true when the user is a system administrator or
when the user's effective feature permissions contain `p2m:oms_status`.
Effective permissions include the normal organization and group permission
cascade.

The sidebar check is not the security boundary by itself. The controller
performs the same feature check for every request, including a URL entered
manually. A user without the feature is redirected to `p2m_root_path` with an
`Access denied.` alert.

## Routing

The route is deliberately named for the user-facing screen but dispatches to
the existing uploads controller:

```ruby
get 'oms_status', to: 'oms_uploads#index', as: :oms_status
```

Inside the `p2m` namespace this produces `p2m_oms_status_path` and the
`/p2m/oms_status` URL. The old `resources :oms_uploads` index route is not
needed for the screen and should not be restored merely to support the
implementation class names.

## Request lifecycle

For an authorized `GET /p2m/oms_status` request:

1. `P2m::OmsUploadsController` checks `p2m:oms_status`.
2. The `P2m::DateRange` concern reads
   `params[:oms_uploads][:start_date]` and
   `params[:oms_uploads][:end_date]`.
3. ISO dates are parsed. Invalid date strings are ignored and replaced by the
   active billing period dates, or by the current date when no active period
   exists.
4. The controller rejects a range where the start date is after the end date.
   It renders the status page with HTTP `422` and the alert
   `Start date must be on or before end date.`
5. `P2m::OmsUploadLedger#reconcile_imported!` refreshes status fields for
   imports that are present in all three destination tables:
   `companions`, `daily_presorts`, and `move_results`.
6. The controller selects OMS records whose `mailer_date` is inside the
   inclusive selected range and whose status is not `removed`.
7. Records are eager-loaded with their associated files and findings, ordered
   newest first by `mailer_date` and then by OMS number, and paginated.
8. The `p2m/oms_uploads/index` view renders the resulting page.

The date form submits a `GET` request to `p2m_oms_status_path`, so the
selected range is represented in the URL and can be bookmarked or revisited.

## Reconciliation behavior

Reconciliation is a read-time consistency update. For each non-removed
`P2m::OmsUpload`, it checks whether the OMS number exists in all three
destination tables. If so, it sets `import_status` to `imported` and clears
any prior failure message.

If `02_Processed/<OMS number>` exists below the configured Data Runner
processed path, reconciliation also sets:

```text
status         = completed
archive_status = archived
archived_at    = archive directory modification time
```

Otherwise the record is marked `status = archiving`. Existing
`imported_at` and `archived_at` values are preserved. If the three destination
tables are unavailable, reconciliation makes no import-status determination.

## Displayed information

Each status row represents one OMS number and includes:

- OMS number, mailer date, and Budget job number
- Printed, mailed, and UAA record counts
- Overall, validation, import, and archive statuses
- Document profile, production workflow, AIMS job, and file count
- Validation findings, including observed values and messages
- Original filenames, file categories, and file sizes

The expand control reveals the detail row in the browser. Table sorting is a
client-side interaction; date filtering, reconciliation, and pagination are
server-side operations.

## Related controls

`OMS Status` is independent of the `Post Production` and `Upload Billing
Data` feature grants:

| Sidebar control | Feature key | Responsibility |
| --- | --- | --- |
| Post Production | `p2m:stage_data` | Stage and manage OMS source files |
| OMS Status | `p2m:oms_status` | View and reconcile OMS status |
| Upload Billing Data | `p2m:data_refresh` | Run the Print 2 Mail billing refresh |

Changing one grant must not implicitly expose the other controls. In
particular, `p2m:stage_data` is not a prerequisite for viewing OMS Status.

## Rename guidance

The following implementation names should remain unchanged unless the scope
includes a coordinated code and database migration:

- `P2m::OmsUploadsController`
- `P2m::OmsUpload`, `P2m::OmsUploadFile`, and `P2m::OmsUploadFinding`
- `P2m::OmsUploadLedger`
- `app/views/p2m/oms_uploads/`
- `p2m_oms_uploads`, `p2m_oms_upload_files`, and
  `p2m_oms_upload_findings`
- the `oms_uploads` date-parameter scope

Only the route helper, URL, ACL feature key, and visible label need the
`OMS Status` terminology for the current feature.

## Source references

- `config/routes.rb`
- `app/views/p2m/shared/_sidebar.html.erb`
- `app/controllers/p2m/oms_uploads_controller.rb`
- `app/controllers/concerns/p2m/date_range.rb`
- `app/services/p2m/oms_upload_ledger.rb`
- `app/views/p2m/oms_uploads/index.html.erb`
- `app/models/app_feature.rb`
- `db/acl.yml`

