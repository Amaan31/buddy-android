# APPLICATION SECURITY & BEHAVIOR TEST PLAN

**Project:** Multi-Character AI Companion Platform  
**Branch target:** `PLATFORM-FOUNDATION`  
**Status:** Proposed application-layer test specification  
**Depends on:** `docs/PLATFORM-FOUNDATION.md`, `docs/DATABASE-AND-MEMORY.md`, and `database/schema/001_initial.sql`

---

## 1. Purpose

This document defines the application-level security and behavior tests required before backend implementation is considered ready.

The SQLite acceptance suite verifies database constraints. It does not prove that application services construct safe queries, enforce the selected character boundary, retrieve only eligible memories, resolve model policies correctly, or perform multi-step lifecycle operations safely.

The next test layer must verify those behaviors through application service interfaces. Tests should use an isolated temporary SQLite database and must not require a production database, paid AI provider, or live API key.

## 2. Scope

### In scope

1. Character Access Guard.
2. Conversation and message access.
3. Memory Retrieval Engine.
4. Explicit memory-sharing enforcement.
5. Model Policy Resolver.
6. Memory approval, correction, supersession, and deletion workflows.
7. Transaction handling and error behavior.
8. Prevention of provider credential exposure.

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
- Assert returned records, not only successful HTTP or service responses.
- Use parameterized SQL and test adversarial identifiers and filter values.
- Run multi-step mutations inside transactions.
- Do not expose unrestricted database access to the PWA/client.
- Do not use AI prompt instructions as the security boundary.
- A failed or denied operation must not partially mutate data.
- Keep tests deterministic; mock provider adapters rather than calling live providers.
- Every test must run against a fresh temporary database initialized from the current schema.

## 4. Application service boundaries

The following are logical service boundaries for testing, not a mandate to implement a particular framework or class naming convention.

| Service boundary | Responsibility |
|---|---|
| Character Manager / Access Guard | Validate the selected character and scope all character-owned reads and writes |
| Conversation Service | Read and write conversations and messages within the selected character |
| Memory Engine | Create candidates, approve, retrieve, correct, supersede, and delete memories |
| Memory Sharing Service | Grant, revoke, and revalidate individual memory shares |
| Model Router / Policy Resolver | Resolve enabled character-specific and global model policies |
| Provider Manager | Check provider/model availability without exposing credentials |

Each service should receive an explicit, validated operation context. The client must not gain direct SQL or unrestricted database access.

## 5. Character Access Guard

### 5.1 Required behavior

- Validate that the selected character exists and is eligible for use.
- Scope every character-owned read and write to the selected `character_id`.
- Verify that a conversation belongs to the selected character before reading, appending, archiving, or deleting it.
- Verify that a message belongs to the selected character and requested conversation.
- Reject mismatched or unknown identifiers without returning another character's data.
- Do not treat a client-supplied `character_id` as proof of authorization.
- Shared infrastructure records such as provider definitions and model catalogue are not character-owned records.

### 5.2 Test cases

| ID | Scenario | Expected result |
|---|---|---|
| CA-01 | Select existing active character A | Character A context is accepted |
| CA-02 | Select unknown character ID | Denied; no character data returned |
| CA-03 | Select archived or deleted character | Denied for normal conversation operations |
| CA-04 | Read character B conversation while A is selected | Denied; no message content or metadata leaked |
| CA-05 | Append a message to B conversation while A is selected | Denied; database unchanged |
| CA-06 | Request a message ID belonging to B under A context | Denied; no content leaked |
| CA-07 | Attempt to override selected character using request parameter | Request cannot widen the validated operation context |
| CA-08 | Use malformed, empty, or unexpected identifiers | Safe validation error; no SQL execution or data leak |
| CA-09 | Switch from A to B, then back to A | Each operation sees only the newly selected character's scope |

### 5.3 Security assertions

- Denial responses must not reveal whether a foreign conversation or message ID exists, unless a later product-level error policy explicitly permits that distinction.
- A denied write must leave all relevant tables unchanged.
- Character context must be applied to every query path, including detail, list, count, search, export, and deletion operations.

## 6. Conversation and message behavior

| ID | Scenario | Expected result |
|---|---|---|
| CV-01 | List conversations for selected character A | Only A conversations returned |
| CV-02 | Fetch conversation history | Only messages from the validated conversation and character returned |
| CV-03 | Append a message to A conversation | Message stored with matching conversation and character IDs |
| CV-04 | Attempt cross-character message append | Denied before mutation; composite foreign key remains a final safeguard |
| CV-05 | Fetch history after switching character | Previous character's history is not included |
| CV-06 | Archive a conversation | Only the selected character's conversation is changed |
| CV-07 | Include failed or partial messages in history | Behavior follows an explicit conversation-history policy; they must not be silently represented as complete |

The conversation service must not combine histories from multiple characters merely because they share the same platform database.

## 7. Memory Retrieval Engine

### 7.1 Eligibility rules from the approved database design

A memory is eligible as an active long-term memory only when:

- `status = 'confirmed'`; and
- `approval_status` is `auto_approved` or `user_approved`.

A character may retrieve:

1. Its own confirmed and approved memories.
2. Individual normal-sensitivity memories explicitly shared with it by another character.

A target character must not receive access to the source character's original conversation, source messages, unrelated memories, or sensitive memories.

The `v_accessible_memories` view is a source of eligible records. The application must still filter by the requested `accessible_to_character_id`.

### 7.2 Test cases

| ID | Scenario | Expected result |
|---|---|---|
| MR-01 | A retrieves its own confirmed, approved memory | Returned |
| MR-02 | A has a candidate/pending memory | Excluded |
| MR-03 | A has a rejected, deleted, or superseded memory | Excluded as current fact |
| MR-04 | A requests B's private memory | Excluded |
| MR-05 | A requests a normal-sensitivity memory explicitly shared by B | Returned to A |
| MR-06 | A requests a sensitive memory owned by B | Excluded |
| MR-07 | A requests a shared memory after its share is revoked | Excluded |
| MR-08 | A requests a memory after its owner marks it non-confirmed | Excluded |
| MR-09 | A requests a memory after its owner changes it to sensitive | Excluded from A |
| MR-10 | A requests an expired memory | Excluded according to the expiry policy |
| MR-11 | A requests memories with a different accessible character ID | No cross-character result |
| MR-12 | Retrieval result includes provenance | Only permitted memory/source metadata is returned; no source conversation access |

### 7.3 Retrieval ranking and context limits

The database design calls for a small relevant subset, using character ID, relevance, category, recency, approval status, sensitivity/sharing eligibility, expiry, and supersession.

Exact ranking weights, category taxonomy, maximum memory count, and token budget are not yet approved. Until those decisions are made:

- Test eligibility and isolation independently from ranking.
- Use deterministic fixtures for any ranking tests.
- Do not invent ranking weights or memory limits in implementation.
- Record ranking and context-budget policy as an open design decision.

## 8. Memory Sharing Service

### 8.1 Required behavior

- Sharing requires explicit user authorization for one individual memory and one target character.
- Only confirmed, approved, normal-sensitivity memories may be shared.
- Source and target characters must differ.
- Sharing a memory never grants access to source conversations or other memories.
- Revocation immediately removes the target's retrieval eligibility.
- Re-activation must revalidate eligibility.
- If a shared memory becomes ineligible, its active shares must no longer grant access.

### 8.2 Test cases

| ID | Scenario | Expected result |
|---|---|---|
| MS-01 | User authorizes eligible memory M from A to B | One active share is created |
| MS-02 | Share a candidate or pending memory | Denied |
| MS-03 | Share a sensitive memory | Denied |
| MS-04 | Share a memory from A to A | Denied |
| MS-05 | Share without explicit authorization | Denied |
| MS-06 | B retrieves the shared memory | Only that memory is visible |
| MS-07 | B attempts to read A's source conversation | Denied |
| MS-08 | Revoke A-to-B share | B can no longer retrieve M |
| MS-09 | Re-activate share while M remains eligible | Allowed only after revalidation |
| MS-10 | Re-activate share after M becomes sensitive or unapproved | Denied |
| MS-11 | A shares M with B and C, then revokes B | B loses access; C remains unaffected |
| MS-12 | Share record is duplicated for the same memory and target | Existing permission is handled safely; no duplicate active grant |

## 9. Model Policy Resolver

### 9.1 Source-backed policy rules

The database design establishes:

- Policies may be global (`character_id IS NULL`) or character-specific.
- Character-specific policies may override global defaults.
- The preferred model must belong to the preferred provider.
- The Model Router selects according to availability, capability, configured preferences, and cost.
- Provider/model catalogues and connection status are shared infrastructure.

### 9.2 Proposed resolver precedence to validate

The following is a proposed deterministic interpretation of the approved override rule. Confirm it before treating it as a final product contract:

1. Look for an enabled policy for the selected character and requested task type.
2. If none is applicable, look for an enabled global policy for that task type.
3. Validate that the preferred provider and model exist and are enabled, and that the provider connection is usable.
4. If the preferred model is unavailable, evaluate configured fallbacks in their stored order, validating each candidate.
5. If no valid model remains, return a typed `NoAvailableModel`/configuration error. Do not silently select an unrelated model.

An explicitly disabled character-specific policy is not yet defined as either “fall back to global” or “disable this task for this character.” This behavior must be decided and tested before implementation.

### 9.3 Test cases

| ID | Scenario | Expected result |
|---|---|---|
| MP-01 | Character A has enabled policy; global policy also exists | A's policy wins |
| MP-02 | Character A has no policy; global policy exists | Global policy is used |
| MP-03 | Character A and B have different policies | Each resolves independently |
| MP-04 | Preferred model belongs to a different provider | Rejected by data constraints or resolver validation |
| MP-05 | Preferred provider is disabled | Candidate is not selected |
| MP-06 | Preferred model is disabled | Candidate is not selected |
| MP-07 | Provider connection is disconnected, expired, or in error | Candidate is not treated as usable |
| MP-08 | Preferred model unavailable; first fallback available | First valid fallback selected |
| MP-09 | First fallback unavailable; later fallback available | Next valid fallback selected |
| MP-10 | No preferred or fallback candidate is usable | Typed error; no arbitrary model selected |
| MP-11 | Task type differs | Policy for another task is not applied |
| MP-12 | Disabled policy behavior | Pending product decision; test after decision |

Fallback entries are currently stored as JSON. Their exact shape, provider/model identifier format, validation rules, and whether cross-provider fallback is permitted must be specified before MP-08 and MP-09 are implemented.

## 10. Memory Lifecycle and deletion workflows

### 10.1 Required behavior

- Candidate detection does not itself approve a memory.
- Only explicit, normal-sensitivity memories with certainty at least `0.90` may be auto-approved.
- Inferred, ambiguous, sensitive, or low-confidence candidates require user review.
- User review must support approve, edit before approval, reject, delete, and correction.
- Corrections supersede outdated memories rather than continuing to present them as current truth.
- Retrieval excludes superseded, rejected, deleted, and pending memories.
- Deletion must account for working-memory summaries and source references.
- Message source references must be detached before deleting a referenced message.
- Multi-record operations must be transactional.

### 10.2 Test cases

| ID | Scenario | Expected result |
|---|---|---|
| ML-01 | Create an inferred candidate | Remains pending |
| ML-02 | User approves a pending candidate | Becomes confirmed and user-approved |
| ML-03 | User rejects a candidate | Rejected and excluded from retrieval |
| ML-04 | User edits a candidate before approval | Edited content is what gets approved |
| ML-05 | User corrects a confirmed memory | Old memory is superseded; corrected memory becomes eligible only after approval |
| ML-06 | Delete a memory with active shares | Shares no longer grant access |
| ML-07 | Delete a source message referenced by memory_sources | Source is detached transactionally before message deletion |
| ML-08 | Delete operation fails midway | Transaction rolls back; no partial deletion |
| ML-09 | Delete a conversation | Related working memory is handled; retained memory provenance follows explicit deletion policy |
| ML-10 | Archive a character | Character is unavailable for normal use; data is not physically erased |
| ML-11 | Physically erase a character | Only through an explicit, tested erasure workflow |
| ML-12 | User asks to forget information represented in derived working memory | Relevant derived context is also removed or rebuilt according to the deletion policy |

The precise policy for retaining source notes after a message deletion, and for removing derived information from backups, remains to be defined. Tests must reflect the final approved policy rather than assume one.

## 11. Provider credential boundary

- Raw API keys and OAuth tokens must never be stored in ordinary database fields.
- `provider_connections.credential_ref` must point to secure credential storage.
- The PWA must not receive raw provider credentials.
- Logs, exception messages, test output, and exported diagnostics must redact secrets.
- Provider adapters should be mocked in unit and integration tests.

| ID | Scenario | Expected result |
|---|---|---|
| PC-01 | Inspect provider connection records | Only credential reference metadata is present |
| PC-02 | Fetch provider configuration for PWA | No raw secret is returned |
| PC-03 | Provider adapter raises an exception containing a secret | Logs and client error redact it |
| PC-04 | Export character/platform data | Provider secrets are excluded |

The exact secure credential-storage mechanism is an open architecture decision and must be selected before live provider integration.

## 12. Test execution strategy

### 12.1 Test layers

1. **Unit tests:** individual guards, eligibility predicates, policy resolution, and lifecycle rules.
2. **Service integration tests:** service operations against a temporary SQLite database using the real schema.
3. **API boundary tests:** request validation, selected-character context, denial behavior, and response redaction.
4. **Regression tests:** every discovered defect becomes a permanent test.

### 12.2 Suggested repository layout

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
  integration/
    test_application_services.py
  api/
    test_character_scoping.py
    test_error_redaction.py
```

This is a proposed layout. It does not imply that a backend language, web framework, API style, or dependency-injection library has already been selected.

### 12.3 Test data fixture

Use at least:

- Character A and Character B.
- One active persona version per character.
- One conversation and multiple messages per character.
- Own confirmed/approved memory for each character.
- Candidate, pending, rejected, superseded, and deleted memory examples.
- One eligible shared memory and one revoked share.
- One sensitive memory that must never be shared.
- Two providers and multiple models with enabled/disabled states.
- Global and per-character model policies.
- Mock provider connection states: connected, disconnected, expired, and error.

Do not use real private conversations or real provider credentials in fixtures.

## 13. Release gate before backend implementation

The application-layer design is ready to move toward implementation only when:

- All test cases have a defined expected result.
- Open policy decisions in Sections 7, 9, and 10 are resolved or explicitly deferred with safe defaults.
- Every character-owned read and write is scoped through a validated character context.
- Memory retrieval is tested against private, shared, revoked, sensitive, pending, superseded, and deleted records.
- Model policy precedence and fallback format are specified.
- Lifecycle operations are transactional and have rollback tests.
- Provider secrets are never exposed to the client or logs.
- All application and integration tests pass on the target runtime.

Passing tests demonstrates the tested behaviors; it is not a substitute for a broader security review before exposing the service to a network.

## 14. Open decisions to resolve before implementation

1. What is the trusted source of the currently selected character in the single-user deployment?
2. What should an explicitly disabled character-specific model policy mean: block the task, or fall back to global?
3. What exact JSON structure and identifier format should `fallback_models_json` use?
4. Are cross-provider fallbacks allowed?
5. What are the memory expiry defaults and exact expiry behavior?
6. What source notes or derived summaries may remain after a user requests deletion?
7. What secure credential-storage mechanism is available on the selected host/runtime?

## 15. Current status

**Completed:** database schema acceptance suite (`database/tests/test_acceptance.py`) has been added and checked against the initial SQLite schema.

**Current milestone:** application security and behavior test specification.

**Not yet completed:** application service implementation, application-layer test suite, API tests, provider integration, and production security review.

**Next action:** review and approve the open decisions in Section 14, then select the backend runtime and implement the testable service boundaries before adding provider integrations.
