# Paperboy Framework Architecture

## Purpose

Paperboy is being organized as a modular monolith. The application remains one
Rails deployment, but reusable architecture and application-specific behavior
have explicit namespace boundaries.

The primary namespaces are:

- `Pfa`: Paperboy Framework Architecture. Reusable capabilities that may be
  consumed by Forms, Automated Invoice Management (AIM), and future apps.
- `Forms`: Traditional and dynamically generated form behavior.
- `Coa`: Chart of Accounts data and account-hierarchy behavior.
- Application namespaces such as `Aim`, `Billing`, `Dam`, and `DataRunner`.

The intended dependency direction is:

```text
Applications ──> Pfa
Forms        ──> Pfa
Pfa          ──> Rails and shared infrastructure
```

PFA must not contain form-specific or AIM-specific workflow rules. Applications
publish capabilities through PFA contracts and retain ownership of their data,
authorization, state transitions, and business actions.

## PFA capabilities

### Access control

`Pfa::Access::PermissionSet` aggregates application permissions from global,
organization, and group grants. `ApplicationController` delegates permission
loading to this service instead of implementing aggregation itself.

The service currently supports the existing permission types, including:

- Application access
- Application features
- Form access
- Dropdown access
- Record viewing and editing

Application-specific policy remains in the owning application. PFA provides the
shared permission aggregation mechanism.

### Notifications

`Pfa::Notifications::TeamsClient` provides reusable Microsoft Teams JSON
delivery, HTTPS handling, timeouts, and failure logging.

`TeamsNotifier` retains Critical Information Reporting card construction and
delegates transport to the PFA client. This keeps presentation and business
content in Forms while making Teams delivery reusable.

### Workflow

`Pfa::Workflow::Reassignable` owns reusable reassignment behavior. A temporary
top-level `Reassignable` compatibility constant allows existing submission
models and stored polymorphic names to continue working during migration.

Status history, task reassignment, assignment persistence, and action dispatch
are candidates for additional `Pfa::Workflow` extraction. They should not be
moved until their form-specific assumptions have been removed.

### Work management

Inbox and Submissions are PFA concepts. They represent actionable work and
visible work records across multiple Paperboy applications.

The shared work contract consists of:

- `Pfa::Work::Item`: immutable, application-neutral work representation.
- `Pfa::Work::Provider`: interface implemented by publishing applications.
- `Pfa::Work::Registry`: registry of application providers.
- `Pfa::Work::InboxQuery`: aggregates actionable work from providers.
- `Pfa::Work::RecordQuery`: aggregates visible work records from providers.

A work item provides a stable key and normalized fields such as application,
source identity, reference, title, owner, assignee, status, status category,
timestamps, path, actions, metadata, and the optional source object.

Stable keys include the application and source identity:

```text
forms:SafetyReport:42
aim:invoice:action_needed:INV-123
```

Provider failures are isolated and logged so one unavailable application does
not prevent other applications from publishing work.

## Forms boundary

### Controllers and views

Traditional form controllers inherit from `Forms::BaseController` and live in
`app/controllers/forms`. Their views live in `app/views/forms`.

Existing URLs and route helper names are preserved. Routes select namespaced
controllers explicitly instead of adding a `/forms` URL prefix.

The form generator and form-template regeneration paths create future
controllers and views under the Forms namespace.

### Form metadata

Form-builder metadata is owned by Forms:

| Current class | Responsibility |
| --- | --- |
| `Forms::Template` | Form definition and generation metadata |
| `Forms::Field` | Field definitions and lookup configuration |
| `Forms::TemplateStatus` | Configured workflow statuses |
| `Forms::TemplateRoutingStep` | Approval routing configuration |
| `Forms::TemplateEmailStep` | Workflow email configuration |
| `Forms::TemplateCopyRecipient` | Submission-copy configuration |
| `Forms::VisibilityGrant` | Form-wide submission visibility |
| `Forms::SubmissionCopy` | Delivered submission copies |
| `Forms::BackedTable` | Form-backed Records table adapter |
| `Forms::Reference` | Human-readable submission references |

These Active Record classes retain their legacy table names. They also retain
their legacy Active Model route and parameter identities, so forms continue to
submit `form_template` parameters and use `/form_templates` routes.

Temporary root constants such as `FormTemplate` and `FormField` alias the new
classes. New application code should use `Forms::*` directly.

### Submission models

Traditional submission models remain top-level for now. Their class names are
stored in several places:

- `form_templates.class_name`
- `status_changes.trackable_type`
- `task_reassignments.task_type`
- `form_submission_copies.submission_type`
- `active_storage_attachments.record_type`

Moving these models requires a coordinated data migration and compatibility
period. A file move or Ruby alias alone is insufficient because new polymorphic
writes would store namespaced class names.

### Forms work provider

`Forms::InboxQuery` contains the existing form-specific inbox rules.
`Forms::WorkProvider` adapts form submissions to `Pfa::Work::Item` instances and
publishes both actionable items and visible records.

A temporary top-level `InboxQuery` alias is retained for compatibility. Shared
code must use `Pfa::Work::InboxQuery`; form-specific code must use
`Forms::InboxQuery`.

## Chart of Accounts boundary

The GSABSS organization hierarchy is owned by `Coa`:

- `Coa::Agency`
- `Coa::Division`
- `Coa::Department`
- `Coa::Unit`
- `Coa::SubUnit`

Agency-code normalization is implemented by `Coa::Agency.normalize_id`.
Employee unit and HCA sub-unit resolution is implemented by
`Coa::Unit.resolve_for_employee`.

Forms, ACL, lookups, validation, PDF generation, and Customer Lookup use these
domain-owned constants. Temporary root aliases preserve compatibility for any
legacy or externally stored references.

`Employee` is not a COA model. It is shared directory data and is a candidate
for a future `Pfa::Directory` boundary.

## AIM work integration

`Aim::WorkProvider` publishes invoice folders through the PFA work contract.
It currently supports these actionable queues:

- Action Needed
- Vendor Review
- Manual Processing
- Batch Split
- Low Confidence Review
- User Approval

The provider maps invoice identifiers, queue status, timestamps, review paths,
available actions, and `.claim.json` ownership into normalized work items. It
only publishes work to viewers whose application context includes AIM and hides
items claimed by another reviewer.

The filesystem remains the source of invoice PDFs and processing metadata.
Directory scanning and `.claim.json` are transitional workflow mechanisms, not
the final shared assignment store.

## Compatibility policy

Namespace migrations use compatibility shims when persisted data or external
callers may still reference old constants. Shims must contain no domain logic.
New code uses the owning namespace directly.

Compatibility includes:

- Existing URLs and route helpers
- Existing database table names
- Existing form parameter keys
- Existing persisted submission and polymorphic type names
- Temporary top-level Ruby constants

Shims may be removed only after code searches, data migrations, and production
data audits confirm that old names are no longer required.

## Remaining work

### Shared work presentation

The current Inbox and Submissions pages still render form-specific records.
They must be changed to render `Pfa::Work::Item` objects and provider-supplied
actions before AIM items can safely appear in the shared tables.

The presentation migration should preserve `/inboxqueue` and `/submissions`
while moving their controllers, queries, saved searches, table layouts, and
views under a PFA work boundary.

### Durable AIM work state

A future `pfa_work_items` projection should index application, source identity,
owner, assignee, status, category, source path, metadata, timestamps, completion,
and optimistic locking. A corresponding `pfa_work_events` table should record
claims, releases, assignments, status transitions, and actors.

This projection would not replace AIM files. It would provide reliable inbox
queries, atomic claims, assignment history, auditing, and counts without
scanning every queue directory on each request.

### Dependency inversion

Provider registration is currently assembled by `Pfa::Work::Registry.default`.
As additional applications adopt the contract, registration should move to the
Rails composition layer so PFA does not directly construct application classes.

### Additional candidates

Likely future PFA boundaries include:

- `Pfa::Directory` for employee, building, and contractor directory access.
- `Pfa::Logging` for structured application and audit logging.
- Additional `Pfa::Workflow` services for events and assignments.
- Shared email delivery and rendering infrastructure.

Application-specific payloads, policies, templates, and state machines remain
inside their owning application namespaces.

## Verification expectations

Framework changes must continue to preserve the repository CI requirements:

```text
bundle exec rubocop
bundle exec brakeman
bundle exec bundle-audit check
bundle exec rake test
```

Namespace changes should additionally run `bundle exec rails zeitwerk:check`,
route checks, compatibility-constant checks, table-name checks, association
checks, and `git diff --check`.

The local development environment may be unable to start tests when the
configured `GSASQL16` host cannot be resolved. That is an environment startup
failure and should be recorded separately from test assertion results.
