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

The deployed product also includes `AdminTools`, `DigitalAssetManagement`,
and `Production` controller boundaries. `DigitalAssetManagement` controllers
use `Dam::*` domain models; this difference should be treated as a documented
compatibility name, not as permission to mix the two domains.

The intended dependency direction is:

```text
Applications ──> Pfa
Forms        ──> Pfa
Pfa          ──> Rails and shared infrastructure
```

PFA must not contain form-specific or AIM-specific workflow rules. Applications
publish capabilities through PFA contracts and retain ownership of their data,
authorization, state transitions, and business actions.

## Application portfolio

Paperboy is the host product and composition root for a portfolio of internal
applications. The host owns boot, routing, authentication, the application
switcher, framework registration, and deployment. Each application owns its
business vocabulary, records, policies, workflows, and page content.

| Application | Namespace and entry point | Responsibility | Current maturity |
| --- | --- | --- | --- |
| Admin Tools | `AdminTools`, `/admin_tools` | Administration launchpad for ACL, form management, impersonation, data validation, and lookup-table tools. Each tool retains its own feature grant. | Container around existing administration screens; several controllers remain top-level. |
| Billing | `Billing`, `/billing` | Fiscal-period setup, source refresh, billing enablement, monthly runs, reconciliation/audit, report generation, delivery, and archival. | Namespaced controllers, models, services, jobs, mailer, and views; uses the separate `BillingBase` connection. |
| Data Runner | `DataRunner`, `/data_runner` | Defines, imports, groups, executes, and inspects file/database transformation DSLs and their output artifacts. | Namespaced web layer and runtime services; configuration and executable workflow scripts remain filesystem-backed. |
| Digital Asset Management | `DigitalAssetManagement` controllers with `Dam` domain objects, `/digital_asset_management` | Ingests and searches assets; manages metadata, collections, favorites, jobs, workflows, shares, storage locations, and upload destinations. | Full application slice with feature-level access; controller/domain namespace naming is inconsistent. |
| Production | `Production`, `/production` | Entry point for print-production operations and future production work queues. | ACL-protected shell and dashboard only; production domain services and records are not yet implemented. |

These descriptions state current ownership. They do not make application code
part of PFA merely because multiple applications happen to use similar screens
or operations.

## Filesystem and environment namespace conventions

Application ownership must remain visible outside Ruby constants and Rails
routes. Use the application's canonical key for repository paths and its
uppercase form for environment variables. For example, Billing uses `billing`
in paths and `BILLING` in environment variable names.

| Location | Convention | Example |
| --- | --- | --- |
| `config/` | Put application-owned configuration below `config/<app_key>/`. | `config/billing/report_formats.yml` |
| `output/` | Put generated or runtime artifacts below `output/<app_key>/`. | `output/billing/monthly_reports/` |
| `script/` | Group scripts first by runtime, when applicable, and then by application key. | `script/ruby/data_runner/`, `script/python/aim/` |
| `.env` | Prefix application-owned variables with `<APP_KEY>_`. | `BILLING_ARCHIVE_ROOT`, `AIM_LINUX_QUEUE_BASE_PATH` |

Application keys use lowercase snake case in paths, such as `data_runner`.
Environment prefixes use uppercase snake case without removing word
boundaries, such as `DATA_RUNNER_`, unless a documented compatibility prefix
already exists. Data Runner currently uses `DATARUNNER_`; preserve that prefix
until a coordinated migration is made rather than introducing both spellings
for new settings.

The namespace identifies the component that owns and interprets a setting, not
merely the external system mentioned in its value. An AIM worker setting for a
Billing database therefore remains under `AIM_`, for example
`AIM_SQL_BILLING_DATABASE`. A setting read and owned by Billing begins with
`BILLING_`.

New application-specific files must not be placed directly in `config/`,
`output/`, or a runtime directory under `script/`. New application-specific
environment variables must not use an unqualified name. Existing files and
variables may keep compatibility names until their callers, deployment files,
and secrets are migrated together; document the replacement and avoid creating
a second source of truth during that transition.

Host-wide settings use the `PAPERBOY_` prefix when Paperboy defines them.
Framework settings use `PFA_` only when PFA, rather than an application or the
host, owns the contract. Standard variables defined by Rails, Bundler, Puma, or
another external runtime retain their established names, including
`RAILS_ENV`, `BUNDLE_GEMFILE`, `WEB_CONCURRENCY`, and `PORT`. Shared
infrastructure variables may retain the provider or service namespace, such as
`REDIS_URL`, when they configure one deployment-wide integration.

Do not commit `.env` or application output. Commit a placeholder such as
`.keep` only when an otherwise empty namespaced output directory is required.
If example environment files are added, they must contain names and safe
placeholders only, never credentials or production values.

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

## Application boundaries

### Admin Tools

Admin Tools is an application-level navigation and authorization boundary, not
a framework administration namespace. It owns the catalog and presentation of
administrative capabilities. ACL aggregation, authentication, and generic
feature checks belong in PFA or the host; the rules for editing groups, forms,
lookup data, and impersonation remain with their respective domains.

Existing top-level admin controllers should migrate behind `AdminTools::*` or
another explicit owning namespace over time. Routes may remain stable during
that migration. `AdminTools::BaseController` should remain the mandatory app
gate, with each tool continuing to enforce its feature permission.

### Billing

Billing owns all fiscal calendars, billing types, stored-procedure adapters,
monthly-run orchestration, audit rules, report formats, recipient lists, email
subjects, delivery decisions, and archive locations. `BillingBase` is an
infrastructure adapter used by Billing; it is not a general-purpose framework
database API.

Generic artifact storage, job execution, email transport, and tabular export
interfaces may be extracted only after Billing supplies an adapter and a
second application demonstrates the same contract. Billing report names,
period rules, TC60 concepts, and database schemas must not move into PFA.

### Data Runner

Data Runner owns the DSL schema, catalog, group management, task catalog,
execution pipeline, run output, backup-output browsing, and safe filesystem
rules. Dataset definitions under `config/data_runner` and scripts under
`script/ruby/data_runner` are application configuration and implementation.

A reusable execution framework may eventually expose contracts such as
`Definition`, `Run`, `Artifact`, and `Runner`. It must not know Data Runner DSL
keys, directory stages, rake task names, or billing datasets. Durable run and
artifact records are recommended before another application depends on its
execution state.

### Digital Asset Management

DAM owns asset identity and metadata, ingestion, search facets, collections,
favorites, recent views, workflows, jobs, shares, storage locations, and upload
selection. Binary storage access can sit behind a framework storage contract,
but DAM retains lifecycle rules, metadata schemas, visibility, and sharing
policy.

Standardize new domain code on `Dam::*`. Keep
`DigitalAssetManagement::*Controller` as the web namespace until a deliberate
route and constant migration is justified; document this mapping in tests and
avoid introducing a third abbreviation.

### Production

Production currently owns only an ACL-protected application shell. Future
production models should live in `Production::*` and publish work through
`Pfa::Work::Provider` rather than placing print-job rules in PFA. Likely domain
concepts include jobs, batches, devices, schedules, materials, exceptions, and
completion events, but these should be introduced only with implemented use
cases. Billing datasets and Data Runner scripts are integrations, not the
Production domain model.

## Framework and application separation recommendations

Use the following dependency rule for every extraction:

```text
Paperboy host (composition and routes)
        │
        ├──> Pfa contracts and shared infrastructure
        │
        └──> Applications ──> Pfa contracts

Pfa ──X──> AdminTools, Aim, Billing, Dam, DataRunner, Forms, Production
Application A ──X──> Application B domain internals
```

Recommended actions, in priority order:

1. Move application registration out of `Pfa::Work::Registry.default` and into
   a Rails initializer or host-level registry. PFA should define the provider
   interface but never instantiate application providers.
2. Introduce one host application catalog for keys, labels, routes, feature
   catalogs, and namespace metadata. Replace duplicated lists in
   `ApplicationHelper`, `AclController`, and related navigation code.
3. Give every application a base controller that performs the app-access gate,
   and require feature gates at the action boundary. Keep authorization policy
   out of helpers used only to render navigation.
4. Prevent cross-application model access through adapters or published
   services. Shared database tables alone do not establish a framework API.
5. Extract a capability only when it is application-neutral, has an explicit
   input/output contract, and has at least two consumers. Prefer duplication
   over a shared abstraction containing billing, forms, DAM, or production
   conditionals.
6. Add architecture tests that reject application constants under `app/pfa`,
   direct PFA references to application namespaces, and unregistered app keys.
7. Keep compatibility aliases and legacy routes at the host edge. New domain
   code must use the owning namespace even while persisted names are migrated.

## User interface architecture

The shared UI is a framework capability only at the component and shell level.
PFA or the host owns design tokens, global layout, the application switcher,
responsive navigation behavior, accessibility conventions, and reusable
components. Applications own page composition, domain labels, specialized
visualizations, and content-specific layout.

Current shared standards are:

- Use the application layout and `shared/app_switcher`; application sidebars
  may add domain navigation but must preserve the common shell behavior.
- Use tokens from `base/_tokens.scss`. Do not introduce page-local copies of
  brand colors, spacing, typography, borders, or shadows.
- Use `.btn` with no more than one semantic color variant and one size modifier.
  Button colors and metrics belong only in `components/_buttons.scss`.
- Use the `pb-modal*` shell and `pbConfirm`/`pbAlert`. Never use native browser
  dialogs or define modal shells in page stylesheets.
- Prefer shared table, badge, form, toast, slideshow, and advanced-search
  components before creating application variants. Page SCSS may arrange
  components and style domain content, but must not redefine their appearance.
- Every interactive control must support keyboard use, visible focus, an
  accessible name, and appropriate ARIA state. Mobile behavior is part of the
  component contract, not a page-level enhancement.

To make these rules enforceable, create a component catalog with canonical ERB
examples and accessibility states, add view/component tests for shared markup,
and add a stylesheet lint or CI search that rejects page-level `.btn` colors,
modal-shell declarations, and raw design values where tokens exist. Migrate the
remaining inline-styled controls and legacy `.button` markup to the shared
system as application pages are touched.

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
