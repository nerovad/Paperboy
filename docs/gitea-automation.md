# Paperboy Gitea Workflow and Automation

## Purpose

This document records the planned workflow and automation for the Paperboy
repository hosted at:

`http://gsa-gitea:3000/BSS/Paperboy`

The initial scope includes Issues, pull requests, milestones, and Projects.
Continuous integration is intentionally out of scope for this document's first
implementation phase. Gitea is installed on Windows, and the CI solution will
require a Docker container and coordination with GSA.

The Phase 1 tracking issue is [#7 — Integrate Codex and or Claude with issue
tracking](http://gsa-gitea.ent.co.ventura.ca.us:3000/BSS/Paperboy/issues/7).
Use that issue for the implementation record until a more specific issue is
needed.

Projects are intentionally deferred. Issues and milestones remain the planning
source of truth until Project-board administration is revisited.

## Goals

- Make every piece of planned work visible in Gitea.
- Keep issues small enough to implement, review, and release independently.
- Connect issues, branches, commits, pull requests, milestones, and releases.
- Use Projects for day-to-day flow and milestones for release or delivery goals.
- Reduce manual triage and reporting with repeatable scripts and conventions.
- Preserve an auditable record of decisions and completed work.

## Proposed workflow

1. Capture a request as an issue.
2. Add a type label, area label, priority, and milestone when known.
3. Add the issue to the Paperboy Project.
4. Refine the issue with context, acceptance criteria, and test expectations.
5. Create a branch named after the issue.
6. Implement the change and run the applicable local checks.
7. Open a pull request linked to the issue.
8. Move the Project item to Review and address review feedback.
9. Merge the pull request after review and verification.
10. Confirm the issue and Project item are complete and included in the
    appropriate milestone summary.

Recommended branch format:

```text
issue/123-short-description
```

Recommended pull request title format:

```text
Short imperative description (#123)
```

Pull requests should use closing syntax such as `Closes #123` in their
description when merging the change should close the issue.

## Issue conventions

Issues should answer:

- What problem or capability is being addressed?
- Who is affected?
- What is the desired result?
- What acceptance criteria define completion?
- What tests, documentation, migrations, or deployment notes are needed?

Suggested issue types:

- `bug` — incorrect or broken behavior.
- `feature` — new user-facing or system capability.
- `chore` — maintenance, refactoring, documentation, or tooling.
- `security` — security-sensitive work.
- `blocked` — work that cannot proceed without an external dependency.

Suggested area labels can be added as the repository's work becomes clearer,
for example `area:forms`, `area:inbox`, `area:dam`, `area:billing`,
`area:database`, `area:frontend`, and `area:deployment`.

Issues should not be closed merely because a pull request was opened. They
should close when the change is merged and the acceptance criteria are met.

## Project board

The initial Project workflow should be:

```text
Backlog -> Ready -> In progress -> Review -> Done
```

Optional states:

- `Blocked` for work waiting on GSA, access, infrastructure, or a decision.
- `Cancelled` for work intentionally abandoned without implementation.

Project usage:

- **Backlog:** captured but not yet ready to schedule.
- **Ready:** refined and suitable for implementation.
- **In progress:** actively being implemented.
- **Review:** a pull request exists and needs review or verification.
- **Done:** merged, verified, and documented as needed.

The board should represent current work status. Milestones should represent a
delivery target; they should not be used as a second status board.

## Milestones

Milestones can represent:

- a planned release,
- a deployment or operational objective,
- a focused maintenance effort, or
- a time-boxed group of related improvements.

Each milestone should have a short description, a target date when known, and
a definition of done. Before completion, review:

- open issues and pull requests,
- blocked work and external dependencies,
- required migrations or configuration changes,
- documentation and operational notes, and
- verification performed after merge.

## Pull request conventions

Every pull request should include:

- a short summary of the change,
- the linked issue number,
- notable implementation or schema considerations,
- tests and checks run,
- deployment or rollback notes when relevant, and
- any follow-up work that should become a separate issue.

The author should keep a pull request focused. If review reveals unrelated
work, record it as a new issue rather than expanding the current pull request.

For Paperboy changes, the applicable local checks normally include:

```text
bundle exec rubocop
bundle exec brakeman
bundle exec bundle-audit check
bundle exec rake test
```

Tests must use the configured SQL Server test database. They must never point
at `Paperboy_Dev`, staging, or production data.

## Automation we can implement without CI

### Repository templates and conventions

- Add issue templates for bugs, features, chores, and infrastructure requests.
- Add a pull request template with the checklist above.
- Define the initial label taxonomy and descriptions.
- Document the Project columns and milestone naming convention.

### Triage and reporting

Create a repeatable command or script that can:

- list open issues without labels or milestones,
- identify issues that have not changed recently,
- identify blocked issues and their dependency notes,
- summarize milestone completion and remaining work,
- list pull requests awaiting review,
- find pull requests without a linked issue, and
- produce a release-readiness report.

The first version should be read-only. Updates such as applying labels or
moving Project items can be added after the report is trusted.

### Gitea API helpers

If an authenticated API method is available from the development environment,
we can add small, narrowly scoped helpers for:

- creating or updating labels,
- assigning issues to milestones,
- adding issues and pull requests to a Project,
- applying standard labels from issue text,
- generating milestone summaries, and
- checking repository metadata for workflow drift.

Scripts should support a dry-run mode and should never silently close issues,
merge pull requests, delete branches, or remove Project items.

### Human-in-the-loop automation

Automation should prepare decisions for review before making consequential
changes. For example, a triage report can suggest labels and a milestone,
while a maintainer confirms the changes. This is especially appropriate for
security, deployment, database, and externally blocked work.

## CI and GSA dependency

CI is deliberately separated from the initial automation work.

Known constraints:

- Gitea is installed on Windows.
- A Docker container is expected to provide the CI runner or build
  environment.
- GSA assistance will be needed for infrastructure, permissions, networking,
  image management, secrets, and operational ownership.

The CI effort should be tracked as a separate infrastructure issue or
milestone. It should not block the issue, PR, milestone, Project, or reporting
workflow described here.

Questions for the CI planning effort include:

- Which Gitea Actions or runner version is approved?
- Where will the Docker host and runner execute?
- Which Windows, Docker, SQL Server, and network permissions are required?
- How will secrets and database credentials be supplied?
- Who owns runner updates, logs, failures, and recovery?
- Which checks are required before a pull request can merge?

## Todo list

### Phase 1 — establish the workflow

- [x] Confirm access to the Paperboy Gitea repository and its Projects feature.
- [ ] Confirm who may administer repository labels, milestones, Projects, and
      webhooks.
- [ ] Create the initial Project with the agreed workflow columns. **Deferred.**
- [x] Create the initial issue labels and descriptions.
- [x] Agree on milestone naming and target-date conventions.
- [x] Add issue templates for bug, feature, chore, and infrastructure work.
- [x] Add a pull request template.
- [x] Document the conventions in the repository README or contributor guide
      if broader visibility is needed.

The repository-side templates and README link are complete. The initial labels
and `Gitea Workflow Phase 1` milestone have also been created. The repository
is reachable at `10.135.204.125:3000`. Projects are enabled, but this Gitea
instance does not expose Project management through its API, so creating the
initial Project board remains a web UI or administrator task.

Run the Phase 3 report locally with:

```bash
ruby script/gitea_status_report.rb
```

The report reads `GITEA_TOKEN` from the environment or the local `.env` file.
It is read-only and does not create, update, label, close, or delete Gitea
records.

The Phase 4 updater is dry-run by default. It only targets one explicit issue
and supports label additions and milestone assignment:

```bash
ruby script/gitea_apply_updates.rb --issue 10 --add-label priority:normal
ruby script/gitea_apply_updates.rb --issue 10 --milestone "Gitea Workflow Phase 3"
```

Review the plan first, then repeat the command with `--apply` to make the
change. It never closes issues, merges pull requests, deletes branches, or
modifies Projects.

### Phase 2 — connect development work

- [ ] Track Phase 2 in [issue #8 — Adopt issue-linked branch and pull request
      workflow](http://gsa-gitea.ent.co.ventura.ca.us:3000/BSS/Paperboy/issues/8).
- [ ] Use issue-linked branch names for new implementation work.
- [ ] Use consistent pull request titles and issue-closing syntax.
- [ ] Add the appropriate milestone and Project item when work is scheduled.
- [ ] Record test, migration, deployment, and rollback notes in pull requests.
- [ ] Review the first milestone using the proposed release checklist.

### Phase 3 — automate reporting

- [x] Confirm whether the Gitea API is reachable from the Paperboy development
      environment.
- [x] Identify the approved authentication method without committing tokens.
- [x] Build a read-only issue and pull request status report.
- [x] Add missing-label, missing-milestone, stale-work, and unlinked-PR checks.
- [x] Add a milestone and release-readiness summary.
- [x] Add dry-run support before any update operation.
- [x] Pilot label and milestone suggestions with a maintainer review step.

### Phase 4 — optional safe updates

- [x] Add an explicit command to apply approved label changes.
- [x] Add an explicit command to assign approved milestones.
- [ ] Add an explicit command to add approved issues and pull requests to a
      Project.
- [x] Add audit-friendly output for every change made.
- [ ] Decide whether webhook-triggered updates are worthwhile.

### Separate CI track — requires GSA

- [ ] Open a separate Gitea/CI infrastructure issue.
- [ ] Document the Windows host and Docker deployment constraints.
- [ ] Confirm the runner architecture and supported Gitea integration.
- [ ] Agree on network access to the repository and required services.
- [ ] Define secret storage and rotation responsibilities.
- [ ] Define the SQL Server test-database strategy for isolated test runs.
- [ ] Define required checks and merge protection rules.
- [ ] Pilot the runner with a non-production test job.
- [ ] Document operations, troubleshooting, ownership, and recovery.

## Decisions and open questions

Record decisions here as the workflow is established.

- Project name: TBD
- Initial milestone: TBD
- Label taxonomy owner: TBD
- Gitea API authentication method: TBD
- Reporting script location: TBD
- Project update permissions: TBD
- CI infrastructure owner: GSA / TBD

## Suggested next implementation

Use the Phase 3 report to review the current issue and pull request state. Add
the missing-label, missing-milestone, stale-work, and unlinked-PR checks to the
report, then begin the optional safe-update phase only after the read-only
output is trusted.
