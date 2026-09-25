# Restart Prompt: Paperboy Authentication Gem

Copy and paste the prompt below to restart the investigation:

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

## Immediate TODO

- [ ] Inventory authentication entry points, session keys, and consumers.
- [ ] Review OAuth callback identity matching and failure handling.
- [ ] Review session rotation, logout, legacy login, and impersonation.
- [ ] Compare at least two gem architectures.
- [ ] Define the smallest host-application adapter contract.
- [ ] Propose an incremental migration and rollback plan.
- [ ] Leave unresolved architectural choices documented for discussion.

