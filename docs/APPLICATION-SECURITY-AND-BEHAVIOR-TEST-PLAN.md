# APPLICATION SECURITY & BEHAVIOR TEST PLAN

**Project:** Multi-Character AI Companion Platform  
**Branch target:** `PLATFORM-FOUNDATION`  
**Status:** Updated test specification — approved architecture baseline  
**Depends on:** `docs/PLATFORM-FOUNDATION.md`, `docs/DATABASE-AND-MEMORY.md`, `docs/APPROVED-ARCHITECTURE-DECISIONS.md`, and `database/schema/001_initial.sql`

---

## 1. Purpose

This document defines the application-level security and behavior tests required before backend implementation is considered ready.

The SQLite acceptance suite verifies database constraints. It does not prove that application services construct safe queries, enforce the selected character boundary, retrieve only eligible memories, resolve model policies correctly, enforce cost-aware routing, or perform multi-step lifecycle operations safely.

Tests must use an isolated temporary SQLite database and must not require a production database, live paid AI provider, real API key, paid hosting, or Buddy subscription. Paid-provider behavior must be tested with mocked adapters and synthetic credentials.

## 2. Scope

### In scope

1. Character Access Guard.
2. Conversation and message access.
3. Memory Retrieval Engine.
4. Explicit memory-sharing enforcement.
5. Model Policy Resolver and cost-aware routing.
6. Memory approval, correction, supersession, expiry, and deletion workflows.
7. Transaction handling and error behavior.
8. Provider credential boundary and BYOK consent.
9. Buddy-free product guarantees and paid-AI opt-in safeguards.

### Out of scope for this milestone

- PWA visual or usability tests.
- Live provider API calls and model quality evaluation.
- Production hosting, remote access, and device performance.
- Multi-user accounts and roles; v1 remains single-user.
- Vector databases, embeddings, and semantic-search infrastructure.
- Final backup encryption and restore implementation; those remain separate design work.

## 3. Test principles

- Use at least two characters in every isolation test.
- Include positive tests and negative/denial tests.
- Assert returned records, not only successful service responses.
- Use parameterized SQL and test adversarial identifiers and filter values.
- Run multi-step mutations inside transactions.
- Do not expose unrestricted database access to the PWA/client.
- Do not use AI prompt instructions as the security boundary.
- A failed or denied operation must not partially mutate data.
- Keep tests deterministic; mock provider adapters rather than calling live providers.
- Every test must run against a fresh temporary database initialized from the current schema.
- Test fixtures must not use paid services, real credentials, or real private conversations.
- Unknown provider cost status must fail closed.
- Paid AI use must require explicit user authorization and BYOK credentials.
- No test may make a live billable network request.

## 4. Application service boundaries

These are logical boundaries for testing, not a mandate to implement a particular framework or class naming convention.

| Service boundary | Responsibility |
|---|---|
| Character Manager / Access Guard | Validate selected character and scope character-owned reads and writes |
| Conversation Service | Read and write conversations and messages within selected character |
| Memory Engine | Create candidates, approve, retrieve, correct, supersede, expire, and delete memories |
| Memory Sharing Service | Grant, revoke, and revalidate individual memory shares |
| Model Router / Policy Resolver | Resolve character/global policy, ordered fallback, capability, availability, and cost classification and paid-use consent |
| Provider Manager | Check provider/model availability, cost classification, and paid-use authorization without exposing credentials |
| Credential Store Adapter | Resolve BYOK secret references using host-provided secure storage; remote provider integration disabled if unavailable |

Each service receives an explicit, validated operation context. The client must not gain direct SQL or unrestricted database access.

## 5. Character Access Guard

### 5.1 Required behavior

- Validate that the selected character exists and is eligible for the requested operation.
- Scope every character-owned read and write to the validated `character_id`.
- Verify that a conversation belongs to the selected character before reading, appending, archiving, or deleting it.
- Verify that a message belongs to the selected character and requested conversation.
- Reject mismatched or unknown identifiers without returning another character's data.
- Treat a client-supplied ID as a selector, not proof of authorization or permission to widen a query.
- Do not confuse single-user character isolation with multi-user authorization.
- Keep network exposure beyond the trusted local environment disabled until a free authentication and secure remote-access design is reviewed and tested.

### 5.2 Test cases

| ID | Scenario | Expected result |
|---|---|---|
| CA-01 | Select existing active character A | Character A context accepted |
| CA-02 | Select unknown character ID | Denied; no character data returned |
| CA-03 | Select archived or deleted character | Denied for normal conversation operations |
| CA-04 | Read B conversation while A is selected | Denied; no message content or metadata leaked |
| CA-05 | Append message to B conversation while A is selected | Denied; database unchanged |
| CA-06 | Request B message ID under A context | Denied; no content leaked |
| CA-07 | Attempt to override validated context within a request | Query remains scoped to validated context |
| CA-08 | Use malformed, empty, or unexpected identifiers | Safe validation error; no SQL execution or data leak |
| CA-09 | Switch A → B → A | Each operation sees only the newly selected character's scope |
| CA-10 | Start a new character context after switching | Previous character's working context is not implicitly reused |

### 5.3 Security assertions

- Denial responses must not reveal whether a foreign conversation or message ID exists, unless a later product-level error policy explicitly permits that distinction.
- A denied write must leave all relevant tables unchanged.
- Character context must be applied to list, detail, count, search, export, update, and deletion query paths.

## 6. Conversation and message behavior

| ID | Scenario | Expected result |
|---|---|---|
| CV-01 | List conversations for A | Only A conversations returned |
| CV-02 | Fetch conversation history | Only messages for validated conversation and character returned |
| CV-03 | Append message to A conversation | Message stored with matching conversation and character IDs |
| CV-04 | Attempt cross-character append | Denied before mutation; composite foreign key remains final safeguard |
| CV-05 | Fetch history after switching character | Previous character history is not included |
| CV-06 | Archive conversation | Only selected character's conversation is changed |
| CV-07 | Include failed or partial messages | Explicit history policy is followed; never silently represent as complete |
| CV-08 | Build model context for A | No B conversation or private memory is included |

The conversation service must not combine histories from multiple characters merely because they share the platform database.

## 7. Memory Retrieval Engine

### 7.1 Eligibility rules

A memory is eligible as an active long-term memory only when:

- `status = 'confirmed'`; and
- `approval_status` is `auto_approved` or `user_approved`.

A character may retrieve:

1. Its own confirmed and approved memories that have not expired.
2. Individual normal-sensitivity memories explicitly shared with it by another character, where the share remains active and the memory has not expired.

A target character must not receive access to the source character's original conversation, source messages, unrelated memories, or sensitive memories.

The `v_accessible_memories` view provides eligible rows. The application must filter by the requested `accessible_to_character_id` and must enforce expiry at retrieval time.

### 7.2 Test cases

| ID | Scenario | Expected result |
|---|---|---|
| MR-01 | A retrieves own confirmed, approved memory | Returned |
| MR-02 | A has candidate/pending memory | Excluded |
| MR-03 | A has rejected, deleted, or superseded memory | Excluded as current fact |
| MR-04 | A requests B private memory | Excluded |
| MR-05 | A requests normal memory explicitly shared by B | Returned to A |
| MR-06 | A requests sensitive memory owned by B | Excluded |
| MR-07 | A requests memory after share is revoked | Excluded |
| MR-08 | A requests memory after owner marks it non-confirmed | Excluded |
| MR-09 | A requests memory after owner changes it to sensitive | Excluded from A |
| MR-10 | A requests memory at or after `expires_at` | Excluded |
| MR-11 | A requests memory with a different accessible character ID | No cross-character result |
| MR-12 | Retrieval result includes provenance | Only permitted memory/source metadata; no source conversation access |
| MR-13 | A's own memory expires | Excluded from A's retrieval |
| MR-14 | A retrieves after switching from B | No B-only memory remains in assembled context |

### 7.3 Ranking and context limits

Exact ranking weights, category taxonomy, maximum memory count, and token budget remain open. Until approved:

- Test eligibility and isolation independently from ranking.
- Use deterministic fixtures for ranking tests.
- Do not invent ranking weights or memory limits.
- Record ranking and context-budget policy as an open design decision.

## 8. Memory Sharing Service

### 8.1 Required behavior

- Sharing requires explicit user authorization for one individual memory and one target character.
- Only confirmed, approved, normal-sensitivity, unexpired memories may be shared.
- Source and target characters must differ.
- Sharing never grants access to source conversations or other memories.
- Revocation immediately removes target retrieval eligibility.
- Re-activation must revalidate eligibility.
- If a shared memory becomes ineligible or expires, it must no longer grant access.
- A memory deletion/forget operation revokes all associated active shares.

### 8.2 Test cases

| ID | Scenario | Expected result |
|---|---|---|
| MS-01 | User authorizes eligible M from A to B | One active share created |
| MS-02 | Share candidate or pending memory | Denied |
| MS-03 | Share sensitive memory | Denied |
| MS-04 | Share memory A to A | Denied |
| MS-05 | Share without explicit authorization | Denied |
| MS-06 | B retrieves shared memory | Only that memory visible |
| MS-07 | B attempts to read A source conversation | Denied |
| MS-08 | Revoke A-to-B share | B can no longer retrieve M |
| MS-09 | Re-activate share while M remains eligible | Allowed only after revalidation |
| MS-10 | Re-activate after M becomes sensitive or unapproved | Denied |
| MS-11 | Share M with B and C, then revoke B | B loses access; C unaffected |
| MS-12 | Duplicate share for same memory and target | No duplicate active grant |
| MS-13 | Shared memory expires | Target loses retrieval eligibility |
| MS-14 | Forget/delete M | All active shares cease granting access |

## 9. Model Policy Resolver and cost-aware routing

### 9.1 Approved policy precedence

1. Resolve the enabled character-specific policy.
2. If it is absent or disabled, fall back to the enabled global policy.
3. Validate provider, model, connection, task capability, cost classification, and user consent.
4. If the preferred candidate is unavailable or ineligible, evaluate configured fallbacks in stored array order.
5. Cross-provider fallback is allowed only when explicitly configured and all capability, credential, cost, and consent checks pass.
6. If no authorized candidate remains, return `NoAvailableModel` or an equivalent typed error.
7. Never silently route to a paid or unknown-cost candidate.

### 9.2 Approved fallback JSON structure

`fallback_models_json` is an ordered array:

```json
[
  {"provider_id": "provider_a", "model_id": "model_a"},
  {"provider_id": "provider_b", "model_id": "model_b"}
]
```

Both IDs are required non-empty strings. The model must belong to the provider. Array order defines priority. Unknown object fields and duplicate pairs are rejected or normalized by validation. JSON validity alone is insufficient.

### 9.3 Cost classification and consent

A provider/model candidate must be classified as one of:

- `local`: inference runs on a user's own device or self-hosted hardware.
- `verified_free`: provider access has been verified as no-cost under its current terms.
- `user_paid_byok`: paid provider access using the user's own provider account/API key.
- `unknown`: cost or billing behavior is not verified and must be treated as ineligible.

Paid AI is permitted only when all of the following are true:

- The user has supplied a supported provider credential through BYOK.
- The credential is stored outside SQLite and ordinary configuration.
- The user has explicitly enabled paid use for that provider/model.
- The user has been told that the provider may charge their account.
- Any paid fallback route has been explicitly authorized; failure of a free/local model alone is not consent.

Provider charges are billed directly by the provider to the user's account. Buddy does not sell credits, resell inference, or pay provider bills. Buddy itself remains free and must not require a paid tier or subscription.

### 9.4 Test cases

| ID | Scenario | Expected result |
|---|---|---|
| MP-01 | Enabled character-specific policy exists | Character policy selected |
| MP-02 | Character policy disabled; enabled global policy exists | Global policy selected |
| MP-03 | Character and global policies unavailable | `NoAvailableModel`; no arbitrary model |
| MP-04 | Preferred model belongs to another provider | Rejected |
| MP-05 | Preferred provider disabled | Candidate skipped |
| MP-06 | Provider disconnected, expired, or in error | Candidate not usable |
| MP-07 | Preferred unavailable; first fallback eligible | First fallback selected |
| MP-08 | First fallback unavailable; next eligible | Next valid fallback selected |
| MP-09 | No preferred or fallback candidate eligible | `NoAvailableModel`; no arbitrary model |
| MP-10 | Explicit cross-provider fallback is configured and eligible | Allowed |
| MP-11 | Candidate has unknown cost | Skipped |
| MP-12 | User supplies valid BYOK key but has not enabled paid use | Paid request blocked |
| MP-13 | User enables paid use for selected provider/model | Paid request may proceed after disclosure/confirmation |
| MP-14 | Free/local route fails and paid fallback was not authorized | No paid request; `NoAvailableModel` |
| MP-15 | Paid fallback is explicitly authorized and valid BYOK is present | Paid fallback may proceed |
| MP-16 | User revokes paid-use consent | Subsequent paid requests blocked |
| MP-17 | Provider billing is routed through Buddy-owned account | Prohibited architecture; test fails |
| MP-18 | Buddy UI attempts to charge for app access or core features | Prohibited; test fails |
| MP-19 | Fallback JSON has missing IDs, wrong types, unknown fields, or duplicates | Configuration rejected |

The router tests must use mocked provider adapters, synthetic credentials, and fake cost metadata. They must not make real billable calls.

## 10. Memory Lifecycle and deletion workflows

### 10.1 Approved behavior

- Candidate detection does not itself approve a memory.
- Only explicit, normal-sensitivity memories with certainty at least `0.90` may be auto-approved.
- Inferred, ambiguous, sensitive, or low-confidence candidates require user review.
- User review supports approve, edit before approval, reject, delete, and correction.
- Corrections supersede outdated memories rather than continuing to present them as current truth.
- Retrieval excludes superseded, rejected, deleted, pending, and expired memories.
- Long-term memory does not expire by default.
- Expiry does not automatically mean physical deletion.
- Working memory is temporary, but exact default TTL is still undecided.
- Deletion accounts for working-memory summaries, active shares, and source references.
- Message source references are detached before deleting a referenced message.
- Multi-record operations are transactional.

### 10.2 Test cases

| ID | Scenario | Expected result |
|---|---|---|
| ML-01 | Create inferred candidate | Remains pending |
| ML-02 | User approves pending candidate | Confirmed and user-approved |
| ML-03 | User rejects candidate | Rejected and excluded |
| ML-04 | User edits candidate before approval | Edited content is approved |
| ML-05 | User corrects confirmed memory | Old memory superseded; corrected memory eligible only after approval |
| ML-06 | Delete memory with active shares | Shares no longer grant access |
| ML-07 | Delete source message | Source detached transactionally before deletion |
| ML-08 | Delete operation fails midway | Transaction rolls back |
| ML-09 | Delete conversation | Working memory handled; retained provenance follows approved deletion scope |
| ML-10 | Archive character | Unavailable for normal use; data not physically erased |
| ML-11 | Physically erase character | Only through explicit tested erasure workflow |
| ML-12 | Forget information in derived working memory | Derived context invalidated or rebuilt |
| ML-13 | Long-term memory has no expiry | Remains eligible while other rules pass |
| ML-14 | Long-term memory expires | Excluded from retrieval; not automatically physically deleted |
| ML-15 | Working memory reaches configured expiry | Excluded/cleared according to configured TTL |
| ML-16 | Forget operation fails at a later step | Transaction rollback or safe retry; no partial active access |
| ML-17 | Forget operation completes | Target memory, shares, and identifiable derived context no longer appear in retrieval |

The exact working-memory TTL, source-note retention, and backup retention period remain open. Tests must not invent these values.

## 11. Provider credential boundary

### 11.1 Approved behavior

- Raw API keys and OAuth tokens are never stored in SQLite, source code, ordinary configuration files, frontend state, logs, or exports.
- `provider_connections.credential_ref` points to separate secure storage.
- Prefer built-in host operating-system secure storage where available without payment.
- If a suitable secure store cannot be used, remote credential-based provider integrations remain disabled.
- Local inference without provider credentials remains preferred, subject to compatibility testing.
- The selected secure-store implementation is not yet approved.

### 11.2 Test cases

| ID | Scenario | Expected result |
|---|---|---|
| PC-01 | Inspect provider connection records | Only credential reference metadata |
| PC-02 | Fetch provider configuration for PWA | No raw secret returned |
| PC-03 | Provider exception contains secret | Logs and client error redact it |
| PC-04 | Export platform data | Provider secrets excluded |
| PC-05 | Host secure store unavailable | Remote credential integration disabled |
| PC-06 | Credential reference cannot be resolved | Safe error; no fallback to plaintext storage |
| PC-07 | Local inference needs no credential | Works without provider secret |
| PC-08 | BYOK key is saved but paid-use consent is off | Paid request blocked |
| PC-09 | User revokes paid-use consent | Subsequent paid requests blocked |
| PC-10 | Provider error includes API key | Secret redacted from logs and client errors |

## 12. Buddy-free product and optional paid-AI safeguards

### 12.1 Required product rule

Buddy itself must be free to obtain and use. No purchase, subscription, activation fee, paid tier, or payment is required for core platform functionality.

AI inference is a separate optional service. Users may choose local inference, verified-free remote providers, or paid AI providers using their own accounts and API keys (BYOK). Any paid provider charges are billed directly by that provider to the user. Buddy must not sell AI credits, resell usage, or bill the user for AI consumption.

### 12.2 Test cases

| ID | Scenario | Expected result |
|---|---|---|
| FR-01 | Inspect required Buddy runtime dependencies | No paid license or subscription required |
| FR-02 | Inspect hosting/deployment plan | Core platform runs on existing hardware; no paid hosting required |
| FR-03 | Core application starts without any AI provider connected | Core platform remains usable |
| FR-04 | User selects local inference | No remote provider credential required |
| FR-05 | User selects verified-free remote provider | Allowed while current no-cost terms remain verified |
| FR-06 | User connects paid provider with own API key | Allowed only through BYOK and explicit paid-use consent |
| FR-07 | User saves paid-provider key but does not consent to paid usage | No paid request is sent |
| FR-08 | Free/local provider fails; paid fallback not authorized | No paid request; show `NoAvailableModel` |
| FR-09 | Free/local provider fails; paid fallback explicitly authorized | Paid fallback may run using user's own provider account |
| FR-10 | Provider pricing/terms are unknown or verification expired | Candidate blocked until current cost/billing terms are verified |
| FR-11 | Provider requires payment details or paid subscription | This does not make Buddy paid; disclose provider requirement and let user decide whether to connect |
| FR-12 | Paid provider usage occurs | Provider bills the user's own account directly; Buddy does not bill or proxy charges |
| FR-13 | Buddy asks for payment to unlock core app functionality | Prohibited; test fails |
| FR-14 | Buddy-owned API key or billing account is used to charge users | Prohibited; test fails |
| FR-15 | Test suite is executed | No live billable network request or real secret required |

### 12.3 Meaning of “Buddy is free”

- Buddy itself has no required purchase, subscription, activation fee, or paid core tier.
- Optional paid AI usage is separate and is paid by the user directly to the AI provider through the user's own account/API key.
- Local inference and verified-free providers should be supported where technically feasible.
- Existing electricity, internet bandwidth, storage, and hardware use may still have real-world costs.
- Never describe a paid provider's AI usage as free, and never imply that a consumer AI subscription automatically grants API access.

## 13. Test execution strategy

### 13.1 Test layers

1. Unit tests: access guards, eligibility predicates, policy resolution, cost gates, and lifecycle rules.
2. Service integration tests: services against temporary SQLite using the real schema.
3. API boundary tests: request validation, selected-character context, denial behavior, and response redaction.
4. Regression tests: every discovered defect becomes a permanent test.
5. Dependency audit: review licenses, pricing, payment requirements, and hosting assumptions before approving a runtime/provider.

### 13.2 Suggested repository layout

```text
database/
  schema/
    001_initial.sql
  tests/
    test_acceptance.py

tests/
  application/
    test_character_access.py
    test_conversations.py
    test_memory_retrieval.py
    test_memory_sharing.py
    test_model_policy_resolver.py
    test_memory_lifecycle.py
    test_provider_credential_boundary.py
    test_cost_and_consent_policy.py
  integration/
    test_application_services.py
  api/
    test_character_scoping.py
    test_error_redaction.py
```

This layout does not imply that a backend language, framework, API style, or dependency-injection library has been selected.

### 13.3 Test fixtures

Use at least:

- Character A and B.
- One active persona version per character.
- One conversation and multiple messages per character.
- Own confirmed/approved memories for each character.
- Candidate, pending, rejected, superseded, deleted, and expired memories.
- One eligible shared memory and one revoked share.
- One sensitive memory that must never be shared.
- Two providers and multiple models with enabled/disabled states.
- Global and per-character policies.
- Mock provider connection states: connected, disconnected, expired, and error.
- Mock cost states: local, verified-free, user-paid-BYOK, and unknown; include expired pricing verification and billing-risk cases.
- Mock credential store: available, unavailable, and lookup failure.

Do not use real private conversations, real provider credentials, or live billable services in fixtures.

## 14. Release gate before backend implementation

The application-layer design is ready to move toward implementation only when:

- All test cases have defined expected results.
- Character-owned reads and writes are scoped through validated character context.
- Retrieval is tested against private, shared, revoked, sensitive, pending, superseded, deleted, and expired records.
- Model policy precedence and fallback format are specified.
- The router rejects unknown candidates and requires BYOK plus explicit consent for paid candidates.
- Lifecycle operations are transactional and have rollback tests.
- Provider secrets are never exposed to client or logs.
- Secure credential storage is either tested or remote credential integrations remain disabled.
- Required Buddy dependencies and hosting are free; optional paid AI is BYOK and explicitly authorized.
- All application and integration tests pass on the target runtime.

Passing tests demonstrates tested behavior; it is not a substitute for broader security review before exposing the service to a network.

## 15. Decisions still open

The seven baseline decisions are approved and are no longer open. These implementation choices remain undecided:

1. Backend language and framework.
2. Backend runtime and final host device.
3. Local inference runtime and model compatibility on POCO F6 / Mi 9 SE.
4. Exact working-memory TTL.
5. Memory ranking, category taxonomy, and retrieval budget.
6. Secure credential-store implementation for any optional remote provider.
7. Free authentication and remote-access design, if remote access is later required.
8. Backup encryption, restore process, and retention period.
9. Provider-specific free quotas and terms at the time of integration.

Every choice must pass the Buddy-free product requirement and optional paid-AI safeguards before adoption.

## 16. Current status

**Completed:**
- SQLite schema acceptance suite is present at `database/tests/test_acceptance.py`.
- Seven application architecture recommendations are approved.
- Buddy-free product requirement and optional paid-AI safeguards are approved.
- Application-layer test specification has been updated to reflect these decisions.

**Not yet completed:**
- Backend runtime selection.
- Local inference compatibility testing.
- Application service implementation.
- Application-layer test suite.
- API tests.
- Provider integration.
- Production security review.

**Next action:** evaluate backend runtime, local inference, and optional BYOK provider integration against existing hardware and the Buddy-free product requirement. Do not start backend implementation until the target runtime is selected and its compatibility/cost audit is complete.
