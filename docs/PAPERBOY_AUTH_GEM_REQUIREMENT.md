# Paperboy Authentication Gem

## Purpose

Document the requirement to evaluate and, if appropriate, extract Paperboy's
authentication and session handling into a reusable Ruby/Rails gem.

This document is intentionally a starting point for an architectural
discussion. It does not select a gem name, public API, storage model, or
migration strategy.

## Current Paperboy behavior

Paperboy currently combines several authentication paths:

- Employees sign in through Microsoft Entra ID via OmniAuth.
- Contractors sign in with an email address and a bcrypt password.
- Contractor password setup and reset use Rails signed tokens.
- Employees and contractors are represented by a common session shape.
- `ApplicationController` reconstructs `SessionUser` from the session.
- Permissions are resolved separately through `EmployeePermissions` and the
  Paperboy ACL model.
- Administrators can impersonate employees or contractors by replacing the
  active session identity.
- `Current.user` receives the session user hash for auditing and status history.
- Data Runner contains a second, partially duplicated employee OAuth flow.

The likely reusable boundary is authentication, session lifecycle, identity
serialization, and password-token handling. Paperboy's employee models,
contractor business rules, GSABSS lookups, ACLs, organization hierarchy,
impersonation policy, and application-specific views should not be assumed to
belong in the first version of the gem.

## Desired outcome

Produce an evidence-based architecture and migration plan for a reusable Rails
authentication gem that Paperboy can consume without changing authorization
semantics or weakening current employee, contractor, and impersonation flows.

The result should make it possible to answer:

1. What code belongs in the gem?
2. What remains an application adapter or Paperboy concern?
3. What public interfaces must the gem provide?
4. How can Paperboy migrate incrementally with rollback points?
5. Should the gem support only Paperboy's two identity sources, or a broader
   provider-neutral contract?

## Non-goals for the first phase

- Replacing Paperboy's ACL or permission system.
- Replacing `Employee`, `Contractor`, or `SessionUser` immediately.
- Adding a general-purpose authorization framework.
- Rewriting all authentication views before the boundary is agreed upon.
- Publishing a gem before the extraction has a tested host-application seam.

## Known issues to resolve or explicitly accept

- Employee OAuth sign-in should rotate the session before establishing a new
  identity, as contractor sign-in already does.
- Logout should use a deliberate session invalidation policy; clearing only
  `:user_id` and `:user` leaves other session state behind.
- The legacy employee-ID login endpoint needs an explicit development/test
  restriction or removal.
- OAuth identity matching should use a stable provider identity and tenant,
  not only the local part of an email address.
- OAuth callbacks should handle missing or malformed OmniAuth data safely.
- Authentication logs should not expose unnecessary email addresses or full
  employee records.
- `sessions#setup` is present in the route table but not as an action in the
  controller; the OmniAuth middleware interception should be documented or
  the route arrangement simplified.
- The session currently contains a relatively large user hash. The gem should
  evaluate whether to store a minimal identity and load display attributes
  through an adapter.
- Data Runner's duplicate session controller should either consume the gem or
  be deliberately left independent with documented reasons.

## Candidate gem responsibilities

These are candidates, not decisions:

- Shared sign-in and sign-out session lifecycle.
- Session fixation protection and session rotation.
- OmniAuth callback normalization and failure handling.
- Provider identity extraction and application identity resolution hooks.
- A minimal `current_user` and `user_signed_in?` integration.
- Local password authentication hooks.
- Signed password setup/reset token support.
- Configurable session serialization.
- Controller/helper integration for Rails applications.
- Test helpers for host applications.

## Candidate application responsibilities

- Finding Paperboy employees in GSABSS.
- Finding contractors in the Paperboy database.
- Contractor activation, expiration, and eligibility rules.
- Contractor email delivery and application mailers.
- Employee/contractor model shape and submitter behavior.
- ACL, group, organization, and feature permissions.
- Admin impersonation authorization and audit policy.
- Paperboy-specific redirects, views, notices, and navigation.
- `Current.user` compatibility for Paperboy audit concerns.

## Architectural discussion

The following questions are intentionally open:

### Gem shape

- Rails engine, Rails integration module, or framework-neutral Ruby core with a
  small Rails adapter?
- One gem for employee and contractor authentication, or a core gem plus an
  optional password-authentication component?
- Should the gem own controllers and routes, or provide concerns and endpoint
  building blocks for the host application?

### Identity contract

- Is the canonical identity a provider subject, local record ID, or both?
- Should the gem require a `User` object, or support separate employee and
  contractor records through an identity adapter?
- Which fields, if any, must be serialized into the session?
- How should the gem represent impersonation without knowing Paperboy's ACL
  rules?

### Persistence and security

- Cookie-backed session versus a server-side session store?
- Should the gem enforce session rotation and full reset by default?
- How should provider, tenant, subject, and local account identifiers be
  validated and logged?
- Should password reset tokens remain Rails model tokens, or become a gem
  service with a host-provided persistence contract?

### Migration

- Extract the shared session writer first, then move endpoints incrementally?
- Introduce an adapter around the existing controllers before moving code?
- Migrate Data Runner first as the smaller duplicate consumer?
- What rollback mechanism is required at each step?

## Proposed restart prompt

Use the following prompt to resume the work in a future session:

> Continue the Paperboy authentication-gem architecture investigation.
> Read `AGENTS.md` and `docs/PAPERBOY_AUTH_GEM_REQUIREMENT.md` first. Inspect
> the current employee Entra/OmniAuth flow, contractor password flow, session
> lifecycle, admin impersonation, Data Runner authentication, and related tests.
> Do not implement the gem yet. Produce an architectural comparison of at
> least two viable designs, identify the smallest stable public interface,
> separate gem responsibilities from Paperboy adapters, and propose an
> incremental migration with security fixes and rollback points. Preserve room
> for discussion; call out decisions that require approval. End with an
> updated TODO list and a proposed commit message following the repository's
> commit-message rules.

## TODO

### Discovery

- [ ] Inventory every authentication entry point and consumer.
- [ ] Trace all session keys, including impersonation and contractor markers.
- [ ] Inventory authentication and authorization tests.
- [ ] Confirm the runtime OmniAuth request/callback behavior in each
      environment.
- [ ] Identify whether any external application already depends on the current
      session hash.

### Security hardening before extraction

- [ ] Define and test session rotation on every sign-in path.
- [ ] Define and test complete logout/session invalidation behavior.
- [ ] Restrict or remove legacy employee-ID login.
- [ ] Replace local-part email matching with stable identity matching.
- [ ] Add malformed/missing OAuth callback coverage.
- [ ] Reduce authentication log data and review filtered parameters.
- [ ] Verify password-reset token expiry and invalidation behavior.

### Architecture

- [ ] Compare a Rails engine, integration module, and core-plus-adapter design.
- [ ] Define the identity resolver interface.
- [ ] Define the session serializer interface.
- [ ] Define local-password and password-token interfaces.
- [ ] Define the host hooks for redirects, mailers, and audit context.
- [ ] Decide how impersonation composes with the gem without moving ACL policy
      into it.
- [ ] Decide whether the gem owns routes/controllers or only reusable services.

### Prototype and migration

- [ ] Build a non-published spike behind Paperboy adapters.
- [ ] Add contract tests for the proposed public interfaces.
- [ ] Migrate one authentication path behind a feature flag or equivalent
      rollback mechanism.
- [ ] Migrate Data Runner if the shared boundary proves valid.
- [ ] Remove duplicated authentication code only after equivalent coverage.
- [ ] Document installation, configuration, upgrade, and rollback procedures.

### Release readiness

- [ ] Run RuboCop, Brakeman, bundle-audit, and the full test suite.
- [ ] Review cookie/session contents and secret handling.
- [ ] Verify behavior in development, staging, and production-like Entra
      configuration.
- [ ] Decide gem ownership, repository location, versioning, and release
      process.
- [ ] Approve the final architecture before extracting production code.

## Decision record

Record architectural decisions here as the discussion progresses.

| Date | Decision | Rationale | Owner |
|------|----------|-----------|-------|
| TBD | No extraction design selected yet | This document is the discussion starting point | TBD |

