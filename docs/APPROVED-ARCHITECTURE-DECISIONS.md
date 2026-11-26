# APPROVED ARCHITECTURE DECISIONS

**Project:** Multi-Character AI Companion Platform  
**Branch target:** `PLATFORM-FOUNDATION`  
**Status:** Approved baseline for design and testing  
**Parent documents:** `docs/PLATFORM-FOUNDATION.md`, `docs/DATABASE-AND-MEMORY.md`  
**Related test plan:** `docs/APPLICATION-SECURITY-AND-BEHAVIOR-TEST-PLAN.md`

---

## 1. Purpose

This document records the seven approved application architecture decisions and the additional hard constraint that the project must remain 100% free of required paid software, subscriptions, API usage, and hosting services.

These decisions are the baseline for future design and application-layer tests. They do not mean that a backend runtime, provider, credential store, or deployment method has already been selected.

## 2. Non-negotiable cost constraint: 100% free

The platform must be designed so that its required operation does not depend on paid products or services.

### 2.1 Allowed baseline

- Free and open-source software.
- Built-in capabilities of devices and operating systems already owned by the user.
- Local/self-hosted services running on existing hardware, subject to compatibility and performance testing.
- Local inference using a model and runtime that can legally and technically be used at no charge.
- Free developer tools and free repository features.
- Optional remote provider integrations only when they can be used without payment, paid subscription, credit card, prepaid credit, or billable overage, and only after their current terms are verified.

### 2.2 Prohibited baseline dependencies

- Paid API calls or paid model usage.
- Paid AI subscriptions used as an assumed API entitlement.
- Paid hosting, VPS, cloud database, managed backend, or paid storage.
- Paid authentication, tunnel, monitoring, analytics, or automation services.
- Software that requires a paid license for the intended use.
- Any automatic fallback that can silently route a request to a billable provider or model.
- Any design that requires the user to enter payment details to keep the core platform running.

### 2.3 Cost-safety rules

1. Local inference is the preferred long-term route for a no-bill platform, but the runtime and model must be tested on the actual selected hardware before being approved.
2. Remote free-tier providers are optional adapters, not a core dependency. Free quotas, model availability, and provider terms may change.
3. Unknown or unverified provider cost status is treated as unavailable.
4. The Model Router must never silently select a paid or unknown-cost model.
5. A provider must be explicitly marked as eligible for no-cost use before it can be selected.
6. Usage limits and provider terms must be checked before enabling a remote free-tier adapter. The application must stop or ask for a new explicit decision rather than incur charges.
7. If no verified no-cost model is available, the application must return a clear `NoAvailableFreeModel` result. It must not spend money to preserve availability.
8. The project may still consume existing electricity, internet bandwidth, device storage, and hardware resources. “100% free” means no required new paid software, subscription, API, or hosting expense; it does not mean physical operation has literally zero cost.

## 3. Decision 1 — Active character context

**Approved behavior:**

- The PWA maintains the currently selected character as UI/application context.
- Each character-scoped operation is executed with one validated `character_id`.
- The backend validates that the character exists and is eligible for the requested operation.
- Every character-owned read and write is scoped to that validated context.
- A client-supplied ID is a selector, not proof of authorization and not permission to widen a query.
- Conversation and message identifiers must be checked against the same character context.
- Switching characters must replace the active context; previous character data must not be carried into the new context unless a specific, approved memory share permits one memory item.
- The initial deployment remains single-user. Network exposure beyond the trusted local environment is not enabled until a free authentication and secure remote-access design has been reviewed and tested.

**Security boundary:** Character isolation prevents accidental or application-level cross-character data mixing. It is not a multi-user authorization system.

## 4. Decision 2 — Disabled character-specific model policy

**Approved behavior:**

- An enabled character-specific policy takes precedence over an enabled global policy for the same task.
- If a character-specific policy is disabled, the resolver ignores that policy and attempts the enabled global policy.
- If no applicable enabled global policy exists, resolution continues through the configured no-cost fallback rules.
- A disabled policy does not itself mean “block this task.”
- If the product later needs a task prohibition, that must be represented by a separate explicit policy state; it must not be inferred from `is_enabled = 0`.

## 5. Decision 3 — Fallback model JSON format

**Approved format:** `fallback_models_json` is an ordered JSON array of provider/model objects.

Example:

```json
[
  {
    "provider_id": "provider_a",
    "model_id": "model_a"
  },
  {
    "provider_id": "provider_b",
    "model_id": "model_b"
  }
]
```

Rules:

- Array order is the fallback priority.
- Both IDs are required and must be non-empty strings.
- The referenced model must belong to the referenced provider.
- The provider and model must be enabled and otherwise eligible at resolution time.
- Duplicate provider/model pairs are rejected or de-duplicated during validation.
- Unknown object fields are rejected in the initial implementation to avoid ambiguous configuration.
- The database's JSON validity check is not sufficient; application validation must enforce this structure.

## 6. Decision 4 — Cross-provider fallback

**Approved:** Cross-provider fallback is allowed.

A fallback may use a different provider from the preferred model, provided that:

- It appears explicitly in the ordered fallback list.
- The provider and model are enabled.
- The provider connection is usable.
- The model supports the requested task.
- Its cost status is verified as no-cost under the platform's cost policy.
- Selecting it cannot create a billable request.

Fallback is not permission to discover or select arbitrary models from a provider catalogue.

## 7. Decision 5 — Memory expiry

**Approved defaults:**

| Data type | Default behavior |
|---|---|
| Confirmed long-term memory | No expiry by default |
| Long-term memory with `expires_at` | Excluded from retrieval at or after expiry |
| Working memory | Temporary; expiry is supported and should be applied according to a separately configured retention value |
| Superseded memory | Excluded from current-fact retrieval |
| Rejected or deleted memory | Excluded from retrieval |

Additional rules:

- Expiry does not automatically mean physical deletion.
- The initial implementation must not invent a universal working-memory duration.
- The exact default working-memory TTL remains a configuration decision to be set before implementation.
- Expired items may be retained for correction, audit, or deletion workflows, subject to the user's privacy and retention choices.

## 8. Decision 6 — Memory deletion and derived data

**Approved behavior:**

### 8.1 Delete one memory

- Mark the memory as deleted or otherwise make it ineligible for retrieval using the approved lifecycle.
- Revoke all active shares associated with that memory.
- Remove it from future retrieval and context assembly.
- Remove or detach source references as required by the user's deletion request and provenance policy.
- Rebuild or invalidate working-memory summaries that still contain the deleted information.

### 8.2 Forget information throughout the platform

A full forget operation must locate and process the target information in:

- The selected long-term memory item(s).
- Active memory shares.
- Working-memory summaries and structured context.
- Derived summaries or caches that can be linked to the source information.
- Source references and retained source notes, according to the requested deletion scope.

Original conversation messages are handled according to the user's requested scope. A memory share never authorizes access to the source conversation.

### 8.3 Transaction and backup behavior

- Multi-record deletion operations must be transactional where supported.
- A failed operation must not leave a partially updated active share or retrievable derived memory.
- Message references in `memory_sources` must be detached before deleting a referenced message.
- Backup copies may retain deleted data until their documented retention period ends. The product must explain this limitation and must not claim immediate erasure from offline backups.
- The exact backup retention period and secure backup mechanism remain open until the deployment design is selected.

## 9. Decision 7 — Provider credential storage

**Approved security rule:**

- Never store raw API keys or OAuth tokens in SQLite, ordinary configuration files, source code, logs, or frontend state.
- `provider_connections.credential_ref` is only a reference to a separate secure storage mechanism.
- Prefer built-in secure storage provided by the selected host operating system when it is available without a paid service.
- If a suitable secure store cannot be used on the selected runtime, remote credential-based provider integrations remain disabled.
- Local inference that does not require provider credentials remains available as the preferred no-cost route, subject to hardware validation.
- The exact credential-store implementation is deferred until the backend host/runtime is selected and tested.

## 10. Provider and Model Router no-cost enforcement

Every provider/model candidate must pass all of these checks before selection:

1. Provider exists and is enabled.
2. Model exists, belongs to that provider, and is enabled.
3. Provider connection is usable when a connection is required.
4. Model supports the requested task.
5. Cost status is explicitly verified as eligible for no-cost use.
6. The selected route cannot incur payment, paid overage, or automatic billing.
7. The provider's current free-use terms and quota have not been marked unknown or expired for verification.

If any check fails, the candidate is skipped. If no candidate remains, return `NoAvailableFreeModel` or an equivalent typed result.

No-cost status must not be inferred from a provider name, model name, free trial, promotional credit, or the presence of a free account.

## 11. Decisions that remain open

The following are not silently decided by this document:

- Backend language and framework.
- Backend runtime and final host device.
- Local inference runtime and model compatibility on POCO F6 / Mi 9 SE.
- Exact working-memory TTL.
- Exact memory ranking, category taxonomy, and retrieval budget.
- Secure credential-store implementation for any optional remote provider.
- Free authentication and remote-access design, if remote access is later required.
- Backup encryption, restore process, and backup retention period.
- Provider-specific free quotas and terms at the time of integration.

Each must be evaluated against the 100%-free constraint before adoption.

## 12. Implementation gate

No implementation may introduce a required paid dependency without an explicit change to the approved project constraint.

Before a backend runtime is approved, document:

- Software license and price.
- Whether any subscription or account payment is required.
- Whether API use can incur charges.
- Whether hosting or remote-access components are paid.
- Whether the solution can run on existing hardware.
- Whether the solution works without network access for its local/core functions.
- How credentials are stored without a paid service.

## 13. Current status

**Approved:** all seven architecture recommendations and the 100%-free constraint.

**Ready for next design stage:** backend runtime and local inference compatibility evaluation.

**Not yet approved:** any specific backend framework, inference runtime, model, provider, or credential-store implementation.

**No backend implementation has started.**
