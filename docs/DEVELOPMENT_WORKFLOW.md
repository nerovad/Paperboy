---
include_toc: true
gitea: none
---

# Development workflow sub-application

> Design notes for issue #41.

<!-- paperboy-wiki-source: docs/DEVELOPMENT_WORKFLOW.md -->

## Purpose

Give Paperboy engineers a discoverable, audited **web** workflow for common `bin/` operations: allowlisted forms, sidebar groups, confirmation for destructive/remote actions, async output, and ACL feature grants. No arbitrary shell. No internal helper scripts as direct actions.

## Scope (locked decisions)

1. **Dev server first.** v1 targets the **development** deploy path and local/dev tooling quality. Stage and production deploy actions may exist in the catalog later, but they are not the first delivery focus.
2. **Feature-grant split (v1).** Application access (`development`) plus these feature grants:
   - **Local** — local app lifecycle and quality checks that belong on a workstation
   - **Environment** — LockBox / `.env` inspect and refresh
   - **Gitea** — status report and **writes** (see below)
   - **Deploy** — tag / deploy-dev (and later stage/prod/AIM behind the same Deploy family as needed)
   - **Certificates** — CSR generation
3. **Gitea writes in v1.** Include create-issue, update-issue with `--apply`, and worktree clean / related write grants behind the **Gitea** feature (and confirmations). Read-only status report alone is not enough.
4. **Keep off the menu.** Do **not** expose as sidebar actions:
   - `bin/dev`
   - `bin/setup`
   - `bin/stopservers`

   Local start/stop may still be implemented via safer dedicated entry points (for example `bin/dev-local`) only if product agrees; Roy’s rule is those three names stay off the Development menu.

## Acceptance (from #41)

- [ ] Development appears in the shared app switcher behind an application access grant.
- [ ] Sidebar groups supported workflows and uses existing button variants.
- [ ] Forms validate and allowlist script arguments.
- [ ] Destructive or remote actions require confirmation and appropriate feature grants.
- [ ] Commands run asynchronously with visible output and exit status.
- [ ] Internal helper scripts are not exposed as direct actions.
- [ ] Tests cover routes, authorization, validation, and command construction.

## Architecture sketch

```text
App switcher (ACL: application development)
  └── Development sidebar
        ├── groups (filtered by feature grants)
        │     └── allowlisted ScriptCatalog entries → Runs UI
        └── Check Queue / Recent Runs (as implemented)
```

- **Catalog** (`Development::ScriptCatalog`): single place for key, label, group, feature, `bin/` name, description, argument builder.
- **Runs**: `Development::Run` + job/launcher; output and exit status on the run show page.
- **ACL**: `can_access_app?('development')` plus `can_use_app_feature?('development', feature_key)`.

### Suggested feature keys (align to Roy’s five)

| Grant label   | Suggested `feature` key(s) | Examples |
| ------------- | -------------------------- | -------- |
| Local         | `local`, optionally `tests` | unit-test; any approved local lifecycle **other than** bin/dev, bin/setup, bin/stopservers |
| Environment   | `environment`              | env-pull `--check` / pull |
| Gitea         | `gitea`                    | status-report; new-issue; update-issue (`--apply`); create-pull-request; wt clean (when exposed) |
| Deploy        | `deploy` / `deploy_dev` (+ later stage/prod/aim) | tag-master-commit; deploy-dev first |
| Certificates  | `csr`                      | gen-csr |

Map existing branch keys to this table when continuing Gary’s work; prefer collapsing deploy_* under **Deploy** for ACL clarity if CoS agrees.

## Sidebar groups (product labels)

Use human labels consistent with the UI helper (Workstation / Quality / Environment / Deployments / Collaboration) **or** rename groups to match the five grants. Either way, menu membership must honor the off-menu list above.

### On menu (v1 intent)

- Quality: unit-test (and similar allowlisted checks)
- Environment: env-pull check / pull; Recent Runs
- Collaboration / Gitea: status-report; new-issue; update-issue (dry-run default, `--apply` gated); create-pull-request; wt-related writes when ready
- Deployments: deploy-dev first; tagging as needed
- Certificates: gen-csr (confirmation + grant)

### Off menu (explicit)

- `bin/dev`, `bin/setup`, `bin/stopservers`
- Arbitrary shell, LockBox secrets as browser input, unlisted helpers

## Security and operations

- Allowlist bins and validate every argument in the catalog builders.
- Confirm destructive / remote / write actions in the UI; require the matching feature grant.
- Prefer dry-run defaults for Gitea mutators; `--apply` only after plan review (same convention as CLI).
- Credentials stay out of the browser; scripts continue to use workstation / server env and token files.

## Relation to existing wiki

- **Architecture** — portfolio / modular monolith; add Development to the application portfolio table when this page ships.
- **Gitea-Workflow** — CLI automation (`bin/new-issue`, `bin/update-issue`, `bin/wiki-publish`, worktrees); this page covers the **web** Development sub-app that wraps a subset of those tools.
- **Agents** — agent rules for worktrees and dry-run remain authoritative for automation; UI must not bypass them.

## Implementation status (branch tip — do not recreate)

Remote: `origin/issue/41-add-development-workflow-sub-application` @ `4c060aa6` (Gary). Substantial UI/catalog/jobs already landed; continue on that branch via worktree attach rather than greenfield.

Open design gaps vs locked decisions:

- Menu currently includes local start/stop wired to `dev-local` / `stopservers` — reconcile with “bin/stopservers OFF menu” and “bin/dev OFF menu”.
- Deploy stage/prod/AIM present in catalog — demote or hide until “dev server first” is satisfied.
- Confirm Gitea write surface (`--apply`, wt clean) matches grant + confirmation UX.

## Publishing this page

`config/wiki_pages.yml` entry:

```yaml
  - source: docs/DEVELOPMENT_WORKFLOW.md
    slug: Development-Workflow
    section: Workflow
    keep: true
```

`keep: true` so the design stays in git next to the sub-app and `bin/wiki-publish` refreshes it.
