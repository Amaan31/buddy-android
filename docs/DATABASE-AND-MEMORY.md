# DATABASE & MEMORY ARCHITECTURE

**Project:** Multi-Character AI Companion Platform\
**Status:** Initial Design Proposal\
**Parent Document:** `docs/PLATFORM-FOUNDATION.md`\
**Database Candidate:** SQLite

## 1. Purpose

This document defines the initial database and memory architecture for a
platform hosting multiple independent AI characters. The database is
shared infrastructure, but character-specific records must remain
logically isolated. Every conversation, message, memory, persona
version, working-memory record, and relationship record must be
associated with its owning character.

## 2. Design Principles

-   Every character has a stable unique `character_id`.
-   Character-specific data must be scoped to its character.
-   Conversation history and long-term memory are different data types.
-   Memory extraction must be reviewable, editable, and reversible.
-   Candidate memories are not automatically confirmed facts.
-   Memories should retain source references where possible.
-   Characters must not access another character's private data by
    default.
-   Memory sharing is selective and requires explicit user
    authorization.
-   Deletion and correction must have predictable effects.
-   The schema must support migrations and encrypted backups.
-   The initial implementation must remain suitable for SQLite.
-   Provider credentials must not be stored as raw secrets in ordinary
    database fields.

## 3. Three Memory Layers

### 3.1 Conversation History

Stores original conversation records to reconstruct conversations,
provide recent context, support user review/export/deletion, and provide
source material for memory extraction. Conversation history is not
itself curated long-term memory.

### 3.2 Working Memory

Stores temporary context needed for active conversations, such as
rolling summaries, current topics, unresolved questions, and temporary
context relevant to the next response. Working memory may be regenerated
or discarded when no longer useful. It must not silently become
long-term memory.

### 3.3 Long-Term Memory

Stores selected information intended to remain useful across
conversations, such as user preferences, important events, ongoing
plans, confirmed facts, character-specific relationship observations,
and important corrections.

Each memory item should have a unique memory ID, owning character ID,
category/content, lifecycle status, approval status, source type,
sensitivity classification, optional certainty, source references,
timestamps, and optional review/expiry metadata. The system must
distinguish explicit statements from model inferences.

## 4. Logical Data Model

### 4.1 `characters`

Character registry: `character_id` (primary key), unique `slug`,
`display_name`, `description`, `status` (`active`, `archived`,
`deleted`), `created_at`, and `updated_at`.

### 4.2 `persona_versions`

Versioned character configuration: `persona_version_id` (primary key),
`character_id`, `version_number`, `configuration_json`,
`change_summary`, `is_active`, and `created_at`. Only one persona
version may be active per character. Conversations record the persona
version active when they began.

### 4.3 `conversations`

Conversation threads: `conversation_id` (primary key), `character_id`,
`title`, `status` (`active`, `archived`, `deleted`),
`persona_version_id`, `started_at`, `last_message_at`, and
`archived_at`. The selected persona version must belong to the same
character.

### 4.4 `messages`

Individual messages: `message_id` (primary key), `conversation_id`,
`character_id`, `sequence_number`, `role` (`user`, `assistant`,
`system`), `content`, optional `provider_id` and `model_id`,
`message_status` (`complete`, `failed`, `partial`), and `created_at`. A
composite foreign key ensures that a message's character matches its
conversation's character.

### 4.5 `working_memory`

Temporary summaries and active context: `working_memory_id` (primary
key), `character_id`, `conversation_id`, `summary`, `context_json`,
`updated_at`, and `expires_at`. The initial schema permits one
working-memory record per conversation. Working memory should be bounded
and replaceable.

### 4.6 `memory_items`

Candidate and retained long-term memories: `memory_id` (primary key),
`character_id`, `category`, `content`, `status` (`candidate`,
`confirmed`, `superseded`, `rejected`, `deleted`), `approval_status`
(`pending`, `auto_approved`, `user_approved`, `rejected`), `source_type`
(`explicit`, `inferred`, `user_approved`), `sensitivity` (`normal`,
`sensitive`), optional `certainty` between 0 and 1, optional
`supersedes_memory_id`, `review_note`, timestamps, `reviewed_at`, and
`expires_at`.

A memory must have an approved status before it can become confirmed.
Automatic approval is restricted to explicit, normal-sensitivity
memories with a confidence score of at least 0.90. Inferred or sensitive
memories require user review. Corrections supersede older memories
without continuing to present them as current truth.

### 4.7 `memory_sources`

Links memory items to source material: `memory_source_id` (primary key),
`memory_id`, `character_id`, optional `message_id`, `source_note`, and
`created_at`. The message reference uses a restrictive delete rule.
Before deleting a source message, the application must first detach the
reference by setting `message_id` to `NULL`, while preserving the source
record where appropriate. Source references must never allow
cross-character conversation access.

### 4.8 `memory_shares`

Explicit sharing permissions: `memory_share_id` (primary key),
`memory_id`, `source_character_id`, `target_character_id`, `status`
(`active`, `revoked`), `granted_at`, and `revoked_at`. Only confirmed,
approved, normal-sensitivity memories may be shared. Sharing a memory
does not grant access to its original conversation or other memories.
Re-activating a revoked permission must revalidate eligibility.

### 4.9 `relationship_states`

Character-specific relationship observations: `relationship_state_id`
(primary key), `character_id`, `state_version`, `state_json`,
`evidence_summary`, and `created_at`. Relationship state must be
grounded in interactions and remain separate for every character.

### 4.10 `platform_settings`

Global settings not owned by an individual character: `setting_key`
(primary key), JSON `setting_value`, and `updated_at`. Examples include
global context limits, backup preferences, and interface preferences.
Character-specific settings remain separate.

### 4.11 `ai_providers`

Supported provider definitions: `provider_id` (primary key),
`display_name`, and `status` (`active`, `disabled`).

### 4.12 `ai_models`

Available models associated with providers: `model_id` (primary key),
`provider_id`, `display_name`, `capabilities_json`, and `status`
(`active`, `disabled`). A model belongs to one provider.

### 4.13 `provider_connections`

Provider connection metadata: `connection_id` (primary key),
`provider_id`, `auth_method`, `status` (`connected`, `disconnected`,
`expired`, `error`), `credential_ref`, `last_checked_at`, and
`created_at`. `credential_ref` points to secure credential storage. Raw
API keys and OAuth tokens must never be stored directly in this table.

### 4.14 `model_policies`

Global and character-specific model selection policies: `policy_id`
(primary key), nullable `character_id` (`NULL` means global policy),
`task_type`, `preferred_provider_id`, `preferred_model_id`,
`fallback_models_json`, `is_enabled`, `created_at`, and `updated_at`.
The Model Router uses these policies to select an appropriate provider
and model for each task. Character-specific policies may override global
defaults. The preferred model must belong to the preferred provider.

## 5. Character Isolation

Every character-specific record must be associated with a unique
`character_id`.

Required relationships: - One character has many persona versions. - One
character has many conversations. - One conversation has many
messages. - One conversation has at most one working-memory record in
the initial schema. - One character has many long-term memory items. -
One memory item may have multiple source references. - One memory item
may have multiple sharing permissions. - One character has many
relationship-state versions. - Model policies may be global or
character-specific.

The backend must validate the selected character before retrieving
conversations or memories. One character must never automatically
retrieve another character's private data. Use foreign keys and
composite constraints where practical.

## 6. Memory Lifecycle

1.  Capture: store the original message.
2.  Detect: identify potentially useful information.
3.  Create candidate: create a candidate memory with source references.
4.  Review: check relevance, duplication, contradiction, sensitivity,
    and certainty.
5.  Retain: confirm according to the configured approval policy.
6.  Retrieve: select relevant memories for future conversations.
7.  Update: correct or supersede outdated memories.
8.  Forget: process deletion requests and derived data.

The first implementation should favor conservative memory creation. A
memory is eligible for retrieval only when its lifecycle status is
`confirmed` and approval status is `auto_approved` or `user_approved`.

## 7. Memory Retrieval

The Memory Engine retrieves only a small relevant subset. Initial
signals include correct character ID, relevance, category, recency,
confirmation/approval status, sensitivity/sharing eligibility, expiry,
and supersession.

A character may retrieve: 1. Its own confirmed and approved memories. 2.
Individual normal-sensitivity memories explicitly shared with it by
another character.

Do not retrieve another character's memories unless explicitly shared;
deleted, rejected, superseded, or pending memories as current facts;
low-certainty inferences as confirmed facts; sensitive memories shared
from another character; or unrelated personal details.

Memory sharing does not grant access to source conversations. Initial
retrieval can use SQLite queries and simple ranking. Vector databases
and embeddings are optional future enhancements.

The `v_accessible_memories` view provides eligible records, but the
backend must filter by the requested `accessible_to_character_id`. The
application must not expose unrestricted database access to clients.

## 8. Deletion, Correction, and Privacy

The platform must support editing memories, marking memories incorrect,
superseding outdated memories, deleting memories and conversations,
archiving characters, exporting character data, and revoking sharing
permissions.

Deletion must consider derived data, including working-memory summaries
and source references. Before deleting a message referenced by
`memory_sources`, the application must detach the source reference in a
transaction. The source record and useful source note may remain,
subject to the user's deletion request and retention policy.

The initial schema uses restrictive foreign-key rules for certain
provenance relationships. The application must implement the
corresponding deletion workflow rather than relying on blind cascades.
Character records should normally be archived or soft-deleted. Physical
deletion requires an explicit, tested erasure workflow.

The product must explain what is deleted and what may remain in backups
until their retention period ends.

## 9. SQLite Implementation Notes

-   Enable foreign-key enforcement on every connection.
-   Use parameterized queries.
-   Use transactions for multi-record operations.
-   Add indexes for character IDs, conversation IDs, timestamps, and
    memory status as needed.
-   Use versioned schema migrations.
-   Store timestamps consistently in UTC.
-   Keep large media files outside SQLite.
-   Encrypt backups.
-   Test against the SQLite version available in the selected runtime.
-   Confirm JSON function support in the target SQLite build.
-   Never expose provider credentials to the frontend.

`database/schema/001_initial.sql` is an initial schema for a new
database, not an upgrade migration for an existing database.

## 10. Initial Build Order

1.  Create character registry.
2.  Create persona version records.
3.  Create conversations and messages.
4.  Enforce character ownership.
5.  Add provider, model, and model-policy records.
6.  Add working memory.
7.  Add candidate and confirmed long-term memories.
8.  Add memory source references.
9.  Add selective memory sharing and revocation.
10. Add correction and deletion workflows.
11. Add relationship-state versioning.
12. Test isolation with at least two characters.

## 11. Acceptance Criteria

The foundation is ready for backend implementation when: - Two or more
characters can be created. - Each character has independent persona
versions and conversations. - Messages cannot be attached to another
character's conversation. - Memory retrieval never crosses character
boundaries without an explicit share. - Candidate and confirmed memories
are distinguishable. - Automatic approval rejects inferred, sensitive,
or low-confidence memories. - User-approved memories can be retained. -
Memories can be traced to sources where available. - Sharing is limited
to confirmed, approved, normal-sensitivity memories. - Revoked sharing
permissions no longer provide access. - Re-activating a share
revalidates eligibility. - Corrections can supersede outdated
memories. - Message deletion handles source references safely. -
Provider credentials are not stored as raw secrets. - Database backups
can be restored. - Global and character-specific model policies can
coexist.

## 12. Open Decisions

The following remain open for future design and implementation: - Exact
memory category taxonomy. - Memory retention and expiry policies. -
Embedding and vector-search requirements. - Final migration tooling. -
Secure credential-storage implementation. - Backup encryption and
restoration strategy. - Runtime compatibility and deployment
validation. - Future multi-user migration requirements.

Approved decisions: - Hybrid memory approval. - Selective memory
sharing. - Single-user initial architecture. - SQLite as the initial
database candidate.

## 13. Architecture Decisions

### 13.1 Memory Approval: Hybrid

The AI may automatically identify potential memory items. Only explicit,
non-sensitive, high-confidence information may be automatically
approved. Ambiguous, inferred, sensitive, or uncertain information
remains pending until reviewed by the user. The user can inspect,
correct, approve, reject, or delete memory items. Automatic approval
follows Section 14.

### 13.2 Memory Sharing: Selective

Each character has its own isolated memory space. Characters cannot
access another character's memories by default. The user may explicitly
share individual confirmed memory items with selected other characters.
Sharing one memory does not grant access to the original conversation or
other memories. Sharing can be revoked. Sensitive memories cannot be
shared in the initial version.

### 13.3 Platform Ownership: Single-User

The initial version is designed for one user. No multi-user account
system is required. Character data belongs to the platform owner, while
character-level data isolation remains mandatory. The architecture
should remain extendable to future multi-user support without building
that system now.

## 14. Hybrid Memory Approval Policy

### 14.1 Candidate Identification

The AI may identify potential memories from conversation messages and
create candidates. Each candidate should contain its content, owning
character ID, source reference where available, source type, confidence
score, sensitivity classification, approval status, and creation
timestamp. Identifying a candidate does not mean it is approved for
long-term storage.

### 14.2 Automatic Approval Conditions

Automatic approval is allowed only when all conditions are met: 1. The
information was explicitly stated by the user. 2. It is classified as
non-sensitive. 3. Its confidence score is at least 0.90. 4. It is not
ambiguous or dependent on unsupported assumptions.

Automatic approval must not be used for inferred personal information,
sensitive information, or uncertain interpretations.

### 14.3 User Review Required

The following remain pending until user review: inferred information,
ambiguous statements, sensitive personal information,
insufficient-confidence information, and information that could
materially affect a character's understanding of the user but is not
explicitly confirmed.

The user must be able to approve, edit before approval, reject, delete,
and correct memories.

### 14.4 Memory Status Lifecycle

  Status         Description
  -------------- -----------------------------------------------
  `candidate`    Identified but not yet confirmed
  `confirmed`    Approved for long-term use
  `superseded`   Replaced by a newer or corrected memory
  `rejected`     Explicitly rejected by the user
  `deleted`      Marked as deleted and excluded from retrieval

Approval status is separate from lifecycle status: - `pending` -
`auto_approved` - `user_approved` - `rejected`

A memory is retrievable as an active long-term memory only when
lifecycle status is `confirmed` and approval status is `auto_approved`
or `user_approved`.

## 15. Selective Memory Sharing

### 15.1 Default Isolation

Every memory item belongs to exactly one character through
`character_id`. A character may retrieve its own confirmed and approved
memories and individual normal-sensitivity memories explicitly shared
with it. Sharing never grants access to the source character's
conversation history.

### 15.2 Sharing Requirements

A memory may be shared only when: - Its lifecycle status is
`confirmed`. - Its sensitivity is `normal`. - Its approval status is
`auto_approved` or `user_approved`. - Source and target characters are
different. - The user explicitly authorizes sharing.

Sensitive memories cannot be shared in the initial version.

### 15.3 Sharing Records

`memory_shares` records the original memory, source character, target
character, status, grant timestamp, and optional revocation timestamp.
Permission status is `active` or `revoked`. A revoked permission no
longer provides access. Re-activating it must revalidate memory
eligibility.

### 15.4 Revocation

After revocation, the target character cannot retrieve the shared
memory. The original memory remains owned by its source character; the
source conversation remains inaccessible to the target; and other
sharing permissions are unaffected. Revoking access does not delete the
original memory.

### 15.5 Enforcement

Memory retrieval must enforce ownership and sharing permissions at the
database or service layer. It must not rely solely on AI instructions.

## 16. Single-User Architecture

### 16.1 Initial Scope

The initial platform supports one owner. It does not require user
registration, multi-user account management, roles, permissions, or a
separate user table. Characters represent AI personas, not platform
users.

### 16.2 Data Ownership

All platform data belongs to the single platform owner.
Character-specific data remains associated with its owning character.
Shared infrastructure such as provider definitions, model catalogue, and
global settings may be managed centrally.

### 16.3 Future Compatibility

Future multi-user support may introduce a `users` table, owner
references for characters, user-level access control, and user-scoped
provider connections/settings. These components must not be implemented
until multi-user support becomes an explicit requirement.

## 17. Implementation Constraints

1.  SQLite is the initial database engine.
2.  Every character-owned record must preserve character-level
    ownership.
3.  Memory retrieval must enforce ownership and sharing permissions.
4.  Raw API keys and provider credentials must never be stored directly
    in ordinary database fields.
5.  Provider credentials must be referenced through secure credential
    storage.
6.  Memory sources should preserve provenance whenever possible.
7.  Deletion and correction operations must maintain memory consistency.
8.  Database migrations must be versioned.
9.  The application must support database backup and restoration.
10. Memory sharing and automatic approval must be enforced by
    application logic and database constraints where practical.
11. The initial implementation must be tested with at least two
    characters.

## 18. Current Status

**Stage:** Database and Memory Architecture Design.

**Completed:** - Logical database model. - Character-level data
isolation design. - Hybrid memory approval policy. - Selective memory
sharing policy. - Single-user architecture decision. - Initial SQLite
schema draft.

**Pending:** - Final SQL schema review. - SQLite execution and integrity
testing. - Two-character memory isolation testing. - Memory sharing and
revocation testing. - Memory deletion and correction testing. - Backup
and restoration testing.

**Next milestone:** Validate the initial SQLite schema before
implementing the backend.

No production database has been created yet.
