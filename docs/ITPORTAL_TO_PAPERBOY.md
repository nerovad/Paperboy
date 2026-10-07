---
include_toc: true
gitea: none
---

# ITPortal → Paperboy conversion

> Design notes for issue #43 (conversion target). The IT Portal **shell** already
> landed on `master` via #47 / #59; this page locks the **incremental convert**
> of the live One GSA / GSA Service Desk stack into Paperboy modules.

<!-- paperboy-wiki-source: docs/ITPORTAL_TO_PAPERBOY.md -->

## Intent (locked)

Convert the production ITPortal (One GSA / `gsa-service-desk`) **incrementally**
into Paperboy coding standards and language, and **refactor to reuse Paperboy
modules** so we do not maintain a duplicate stack.

| Decision | Locked answer |
| -------- | ------------- |
| Home for the work | Default **BSS/Paperboy** (modules under Gary workflow). New BSS sibling only if this wiki proves Paperboy cannot absorb One GSA — **flag that; do not create**. |
| Look / feel of ITPortal | May stay Fluent / current UX during conversion. |
| Production ITPortal | **No** production ITPortal changes *for the conversion itself*. Live Service Desk keeps shipping on its own repo until a seam is ready. |
| Live One GSA rename / module DNS | **Do not** rename or cut DNS until Roy says the module split is ready. |
| PR hygiene | Before any later PR: **merge `origin/master` into the issue branch** (not rebase). |

## Stack map — ITPortal vs Paperboy

Facts below are from repo trees and verified ops docs; do not invent beyond them.

### Languages and runtime

| Layer | ITPortal today (`105354/gsa-service-desk`) | Paperboy (`BSS/Paperboy`) |
| ----- | ------------------------------------------ | ------------------------- |
| Frontend | Next.js 16 (App Router), React, Fluent UI v9, Tailwind; `output: "standalone"` | Rails 8 views/ERB, Hotwire/Turbo, shared Paperboy CSS / `.btn` variants |
| Backend | ASP.NET Core (.NET 10) Web API, EF Core | Rails 8 controllers/models, Solid Queue / Cache / Cable |
| Auth (browser) | IIS Negotiate / Kerberos SSO → JWT for `/api/*` | OmniAuth Entra ID (`entra_id`); ACL apps + feature grants |
| Auth (SQL) | App-pool / service identity to SQL Server | Kerberos (GSSAPI) via FreeTDS / `tiny_tds` on servers |
| Database | SQL Server — prod `GSA_servicedesk` on `GSA-SQL22\gsasql22`; dev `GSA_itportal_dev` | SQL Server — Paperboy / GSABSS (shared); tests use `Paperboy_Test` |
| Deploy | IIS site `gsa-itportal` (root → Node; `/api` in-process); nssm `GSA-NextJS` versioned folders | `bin/deploy-dev` / `bin/deploy-stage` / `bin/deploy` + systemd on Paperboy hosts |
| Repo paths | `frontend/`, `backend/src/GsaServiceDesk.*`, scripts under operator Mac `gsa-itportal-src/gsa-service-desk` | Modular monolith: `app/controllers/<app>/`, `app/views/<app>/`, Gary `bin/` + wiki + worktrees |
| Hostnames (live) | `gsa-itportal` (prod), `gsa-sd-dev` (dev) | Paperboy app hosts (dev/stage/prod per README) — **not** One GSA DNS until Roy says |

### Product slices (ITPortal)

Observed under `frontend/src/app/(protected)/`:

- **Support** — `tickets`, `dashboard`, `reports`, `notifications`, `kb`, `scheduler`, `projects`, `admin`
- **Spaces / Maps** — `maps/` (floors, import, area / rentable / billing-adjacent work reflected in operator factpack)

Paperboy today already has an **IT Portal shell** (`namespace :itp`, ACL key `itp`) with Home slideshow + Hello World dashboard only. Other Paperboy modules (forms, AIM, DAM, Data Runner, Development, billing, P2M, …) are reuse candidates — not a second portal stack.

## Reuse vs rewrite

Default bias: **call into Paperboy modules** when the capability already exists or fits Gary’s AppBuilder / ACL / forms patterns. Stay **ITPortal-shaped** (Next + .NET + Fluent) only while a slice still ships from `gsa-service-desk`, or for thin adapter seams.

| Concern | Prefer reuse (Paperboy) | Stay ITPortal-shaped for now |
| ------- | ----------------------- | ---------------------------- |
| App shell / nav / ACL | `Itp::BaseController`, app switcher, `can_access_app?('itp')`, AppFeature grants | — |
| AuthN / AuthZ model | Entra OmniAuth + Paperboy ACL groups / org grants | Kerberos Negotiate + JWT on IIS until a cutover seam exists |
| Forms / approvals / routing | Paperboy forms, Authorization Console, inbox patterns | Ticket-specific workflows still living in Service Desk API |
| Background jobs | Solid Queue / TaskRunner patterns | .NET hosted workers (email poller, voicemail, aging, …) until replaced |
| SQL access | Paperboy models / tiny_tds; shared GSABSS where data already lives there | `GSA_servicedesk` EF models until a read/write seam is designed |
| UI chrome | Paperboy layout optional later | Fluent look/feel OK during conversion |
| Maps / Spaces GIS UX | New Paperboy `itp` features only after spike proves fit | Keep shipping Maps/Spaces in ITPortal until seam + Roy OK |

**Absorption test (flag, do not create sibling repo):** If a spike shows that Support or Spaces/Maps **cannot** live as Paperboy modules without a permanent second stack (second framework, second auth plane, second deploy pipeline as the long-term home), stop and document the blocker on this wiki + #43. Do **not** create a new BSS sibling until Roy agrees.

## Done criteria

### Support slice (tickets / desk)

Done when **all** of the following hold:

1. Support entry points live under the Paperboy IT Portal app (`itp`) behind ACL, without requiring operators to keep a parallel “conversion-only” UI.
2. Ticket (or successor) workflows call shared Paperboy services/modules where overlap exists; no duplicated auth, ACL, or job-runner stack for the converted surface.
3. Acceptance tests cover routes, authorization, and the thin seam used to reach remaining Service Desk data (if any).
4. Production ITPortal Support continues to run on its own deploy until an explicit cutover issue — conversion work did not require drive-by prod ITPortal churn.
5. Wiki + issue updated with what was reused vs left behind.

### Spaces / Maps slice

Done when **all** of the following hold:

1. Spaces/Maps capabilities targeted for Paperboy are reachable from `itp` (or a named Paperboy module) with AppBuilder/ACL conventions.
2. Floor / area / rentable / billing-adjacent reads or writes that Paperboy absorbs use one data access path agreed in a later spike (no silent dual-write).
3. Look/feel may still match ITPortal; coding standards and module reuse match Paperboy.
4. Live Maps DNS / One GSA rename **not** flipped until Roy confirms module split ready.
5. Same non-goals as Support: no big-bang, no second parallel stack as the destination architecture.

## Explicit non-goals

- **Not** a look-and-feel rewrite — Fluent / current ITPortal UX may remain during conversion.
- **Not** a big-bang cutover of Support + Spaces/Maps in one PR.
- **Not** production ITPortal changes *for conversion* (hotfix/ops on Service Desk stay on that repo’s normal process).
- **Not** a second long-term parallel stack (no permanent Next+.NET twin beside Rails as the target).
- **Not** creating a new Gitea BSS sibling “because conversion is hard” without proving Paperboy cannot absorb and getting Roy’s OK.
- **Not** renaming live One GSA / module DNS until Roy says the split is ready.
- **Not** starting spike implementation in this wiki step (step 1 = wiki + issue only).

## Strangler outline — first spike candidates

Thin seams only. Ranked for **learning value / risk**, not for shipping full Support.

| Rank | Spike (thin seam) | Why | Risk |
| ---- | ----------------- | --- | ---- |
| 1 | **Read-only Support summary card in `itp`** — one ACL-gated Rails action that displays a small, non-mutating summary (counts or deep-link out) from an agreed read path or link to live ITPortal | Proves AppBuilder/ACL + “reuse Paperboy shell” without touching ticket write paths or prod ITPortal code | Low |
| 2 | **Spaces/Maps deep-link catalog in `itp` sidebar** — nav entries that deep-link to current ITPortal Maps routes; no data copy | Confirms IA under Paperboy without GIS rewrite | Low |
| 3 | **Auth / identity bridge spike (design-only or dry-run)** — document how Entra/Paperboy user maps to Service Desk user for a future API call; no prod auth change | Unblocks later API seams; must not change IIS Negotiate | Medium (design) |
| 4 | **Read-only SQL or API peek of one Spaces metric** into Paperboy (dev DB only) | Tests data access without dual-write | Medium |
| 5 | **Write-path ticket comment via Paperboy** | High coupling; defer until read seams and auth bridge are proven | High — not first |

### Recommendation (one)

**Do spike #1 first:** a read-only Support summary (or outbound deep-link) card inside the existing Paperboy `itp` shell, ACL-gated, with tests for route + authorization, and **zero** production ITPortal deploys. Stop after the spike issue is filed from this wiki; do not expand into ticket CRUD in the same change.

## PR hygiene (later steps)

When implementation branches exist:

1. `git fetch origin`
2. On the issue branch: **`git merge origin/master`** (not rebase)
3. Resolve conflicts, run `bin/unit-test` as touched
4. Push and open PR only when Roy asks; PR closes the issue on merge

## Relation to prior #43 work

| Already on `master` | Still this epic |
| ------------------- | --------------- |
| IT Portal sub-app shell (`Itp::`, routes, ACL `itp`, rename from IP Portal #59) | Incremental convert of live One GSA Support + Spaces/Maps into Paperboy modules per this page |
| PR #47 closed the original “add shell” acceptance | Reopened / retargeted tracking via wiki link on #43 |

## Publishing this page

`config/wiki_pages.yml` entry:

```yaml
  - source: docs/ITPORTAL_TO_PAPERBOY.md
    slug: ITPortal-to-Paperboy
    section: Proposals
    keep: true
```

`keep: true` so the playbook stays in git and `bin/wiki-publish` refreshes it.

Wiki URL after publish:

`http://10.135.204.125:3000/BSS/Paperboy/wiki/ITPortal-to-Paperboy`
