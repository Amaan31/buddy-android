# APPROVED ARCHITECTURE DECISIONS

**Project:** Multi-Character AI Companion Platform  
**Branch target:** `PLATFORM-FOUNDATION`  
**Status:** Approved baseline for design and testing  
**Parent documents:** `docs/PLATFORM-FOUNDATION.md`, `docs/DATABASE-AND-MEMORY.md`  
**Related test plan:** `docs/APPLICATION-SECURITY-AND-BEHAVIOR-TEST-PLAN.md`

---

## 1. Purpose

This document records the seven approved application architecture decisions and the approved product-cost rule: Buddy itself is free, while optional AI inference may be free or paid through user-owned provider accounts (BYOK) with explicit consent.

These decisions are the baseline for future design and application-layer tests. They do not mean that a backend runtime, provider, credential store, or deployment method has already been selected.

## 2. Product and cost model: Buddy is free; AI usage may be paid

Buddy itself must remain free to obtain and use. The application/platform must not require a purchase, subscription, activation fee, premium tier, or payment to unlock its core product functionality.

AI inference is a separate, user-selected service and may be free or paid:

- Local models and no-cost remote providers may be used where compatible and available.
- A user may connect a paid AI provider using their own account and API key (BYOK — Bring Your Own Key).
- Any provider charges are billed by that provider directly to the user's provider account. Buddy does not sell AI credits, resell API usage, collect AI usage payments, or pay provider bills on the user's behalf.
- Buddy must clearly identify the provider/model and disclose that usage may incur provider charges before enabling or making a paid request.
- The user must explicitly enable paid use for the relevant provider/model. Merely saving an API key does not authorize paid usage.
- A free/local route must never silently fall back to a paid route. Paid fallback is allowed only when the user has explicitly enabled and authorized that exact fallback behavior.
- If no authorized model is available, return a clear `NoAvailableModel` result. Do not make an unauthorized request.
- Buddy must not require a credit card, prepaid AI credit, or paid subscription to use Buddy itself. A paid AI provider may independently impose its own account/payment requirements.
- Provider pricing, quotas, billing rules, and model availability can change. Show the provider's current pricing reference where practical and avoid claiming a fixed cost unless verified.
- Existing electricity, internet bandwidth, device storage, and hardware use may have real-world costs. “Buddy is free” means Buddy itself has no required purchase or subscription; it does not mean all third-party AI usage or physical operation is literally zero-cost.

### 2.1 Free Buddy platform baseline

- No paid Buddy edition, subscription, activation, or premium-only core feature.
- No required paid hosting, managed database, storage, authentication, tunnel, monitoring, analytics, or automation service.
- Prefer free/open-source software and self-hosted/local components where feasible.
- Core application functions must remain usable without connecting a paid AI provider.

### 2.2 Optional AI provider costs

- Provider integrations are optional adapters.
- Support both local/free inference and user-owned paid provider accounts.
- BYOK secrets must be stored securely and never exposed to the PWA, logs, exports, or ordinary configuration.
- The provider bills the user directly; Buddy must not proxy charges through a Buddy-owned billing account.
- Do not infer API access from a consumer chat subscription. Only supported provider API credentials and terms may be used.

### 2.3 Cost-safety rules

1. Every provider/model candidate must carry an explicit cost classification: `local`, `verified_free`, `user_paid_byok`, or `unknown`.
2. `unknown` is ineligible. A paid candidate is eligible only when its provider connection is valid and the user has explicitly enabled paid usage for it.
3. Saving credentials is not equivalent to consent to incur charges.
4. The Model Router must never silently select a paid or unknown-cost model.
5. Cross-provider fallback may cross from free to paid only when the user has explicitly enabled that specific paid fallback route.
6. If no authorized model is available, return `NoAvailableModel`; never incur charges merely to preserve availability.
7. The project must not introduce required paid dependencies for Buddy itself.

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
- If no applicable enabled global policy exists, resolution continues through the configured fallback rules, with cost classification and user-consent checks applied to every candidate.
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
- Its cost classification is known.
- If it is paid, the user has explicitly enabled paid use for that provider/model and authorized it as a fallback.
- The route cannot incur a charge without that authorization.

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
- Local inference that does not require provider credentials remains a preferred route, subject to hardware validation.
- Optional remote paid providers may be connected through BYOK; provider charges are billed directly to the user's provider account.
- The exact credential-store implementation is deferred until the backend host/runtime is selected and tested.

## 10. Provider and Model Router cost and consent enforcement

Every provider/model candidate must pass all of these checks before selection:

1. Provider exists and is enabled.
2. Model exists, belongs to that provider, and is enabled.
3. Provider connection is usable when a connection is required.
4. The model supports the requested task.
5. Cost classification is explicit: `local`, `verified_free`, `user_paid_byok`, or `unknown`.
6. `unknown` cost is always ineligible.
7. `user_paid_byok` is eligible only when a valid user-owned credential is available and the user has explicitly enabled paid usage for that provider/model.
8. Paid fallback is never selected solely because free/local candidates failed; the user must have authorized that paid fallback route in advance.
9. Buddy never pays provider charges or routes paid usage through a Buddy-owned billing account.

If any check fails, the candidate is skipped. If no authorized candidate remains, return `NoAvailableModel` or an equivalent typed result.

The UI must distinguish “API key saved” from “paid usage authorized”. Before first paid use, disclose that the provider may charge the user's account and require explicit confirmation. The application must not promise a particular price unless current provider pricing has been verified.

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

Each must be evaluated for license, compatibility, security, and cost. Buddy itself must remain free; optional paid AI providers may be supported through explicit BYOK consent.

## 12. Implementation gate

No implementation may introduce a required paid dependency or payment gate for Buddy itself. Optional paid AI provider integrations are permitted only through user-owned BYOK credentials and explicit paid-use consent.

Before a backend runtime is approved, document:

- Software license and price.
- Whether any subscription or account payment is required.
- Whether API use can incur charges and who is billed.
- Whether paid AI usage is strictly opt-in and BYOK.
- Whether hosting or remote-access components are paid.
- Whether the solution can run on existing hardware.
- Whether the solution works without network access for its local/core functions.
- How credentials are stored without a paid service.

## 13. Current status

**Approved:** all seven architecture recommendations; Buddy itself must be free; optional paid AI usage is permitted through BYOK and explicit user consent.

**Ready for next design stage:** backend runtime, local inference compatibility, and optional BYOK provider integration evaluation.

**Not yet approved:** any specific backend framework, inference runtime, model, provider, or credential-store implementation.

**No backend implementation has started.**
