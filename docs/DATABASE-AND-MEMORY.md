
# DATABASE & MEMORY ARCHITECTURE

**Project:** Multi-Character AI Companion Platform
**Status:** Initial Design Proposal
**Parent Document:** docs/PLATFORM-FOUNDATION.md
**Database Candidate:** SQLite

## 1. Purpose

This document defines the initial database and memory architecture for a platform hosting multiple independent AI characters.

The database is shared infrastructure, but character-specific records must remain logically isolated.

Every conversation, message, memory, persona version, and relationship record must be associated with its owning character.

## 2. Design Principles

- Every character has a stable unique character_id.
- Character-specific data must be scoped to its character.
- Conversation history and long-term memory are different data types.
- Memory extraction must be reviewable, editable, and reversible.
- Candidate memories are not automatically confirmed facts.
- Memories should retain source references where possible.
- Characters must not access another character's private data.
- Deletion and correction must have predictable effects.
- The schema must support migrations and encrypted backups.
- The initial implementation must remain suitable for SQLite.

## 3. Three Memory Layers

### 3.1 Conversation History

Stores original conversation records.

Purpose:
- Reconstruct conversations.
- Provide recent context.
- Support user review, export, and deletion.
- Provide source material for memory extraction.

Conversation history is not itself curated long-term memory.

### 3.2 Working Memory

Stores temporary context needed for active conversations.

Examples:
- Rolling conversation summaries.
- Current topics.
- Unresolved questions.
- Temporary context relevant to the next response.

Working memory may be regenerated or discarded when no longer useful.

It must not silently become long-term memory.

### 3.3 Long-Term Memory

Stores selected information intended to remain useful across conversations.

Possible categories:
- User preferences.
- Important events and experiences.
- Ongoing plans and commitments.
- Confirmed facts.
- Character-specific relationship observations.
- Important corrections.

Each memory item should have:
- Unique memory ID.
- Owning character ID.
- Category and content.
- Status.
- Certainty indicator, where appropriate.
- Source references.
- Created and updated timestamps.
- Optional review or expiry metadata.

The system must distinguish explicit statements from model inferences.

## 4. Logical Data Model

### 4.1 characters

Stores the character registry.

Fields:
- character_id — primary key.
- display_name.
- status — active, archived, or deleted.
- created_at.
- updated_at.

### 4.2 persona_versions

Stores versioned character configuration.

Fields:
- persona_version_id — primary key.
- character_id — owning character.
- version_number.
- configuration — structured persona data.
- change_summary.
- created_at.

Conversations should record which persona version was active when they began.

### 4.3 conversations

Stores conversation threads.

Fields:
- conversation_id — primary key.
- character_id — owning character.
- title.
- status — active, archived, or deleted.
- started_at.
- last_message_at.
- persona_version_id.

### 4.4 messages

Stores individual messages.

Fields:
- message_id — primary key.
- conversation_id — owning conversation.
- character_id — owning character.
- role — user, assistant, or system.
- content.
- created_at.
- provider_id, where applicable.
- model_id, where applicable.
- message_status — complete, failed, or partial.

The application must validate that the message's character matches its conversation's character.

### 4.5 working_memory

Stores temporary summaries and active context.

Fields:
- working_memory_id — primary key.
- character_id.
- conversation_id.
- summary.
- context_payload.
- updated_at.
- expires_at.

Working memory should be bounded in size and replaceable.

### 4.6 memory_items

Stores candidate and retained long-term memories.

Fields:
- memory_id — primary key.
- character_id.
- category.
- content.
- status — candidate, confirmed, superseded, or deleted.
- certainty — optional confidence indicator.
- source_type — explicit statement, conversation-derived, or user-approved.
- created_at.
- updated_at.
- reviewed_at.
- expires_at.
- supersedes_memory_id — optional self-reference.

A correction should preserve the fact that an older memory was superseded without continuing to present it as current truth.

### 4.7 memory_sources

Links memory items to their source material.

Fields:
- memory_source_id — primary key.
- memory_id.
- message_id, where available.
- source_note.
- created_at.

This allows memory traceability.

### 4.8 relationship_states

Stores character-specific relationship observations.

Fields:
- relationship_state_id — primary key.
- character_id.
- state_version.
- state_data.
- evidence_summary.
- created_at.

Relationship state must be grounded in interactions and remain separate for every character.

### 4.9 platform_settings

Stores global settings that are not owned by an individual character.

Examples:
- Default provider preference.
- Global context limits.
- Backup preferences.
- Interface preferences.

Character-specific settings must remain separate.

## 5. Character Isolation

Every character-specific record must be associated with a unique character_id.

Required relationships:

- One character has many persona versions.
- One character has many conversations.
- One conversation has many messages.
- One character has many working-memory records.
- One character has many long-term memory items.
- One memory item may have multiple source references.
- One character has many relationship-state versions.

The backend must validate the selected character before retrieving conversations or memories.

One character must never automatically retrieve another character's private data.

Where practical, use foreign keys and composite constraints to enforce ownership.

## 6. Memory Lifecycle

Proposed lifecycle:

1. Capture: store the original message.
2. Detect: identify potentially useful information.
3. Create candidate: create a candidate memory with source references.
4. Review: check relevance, duplication, contradiction, sensitivity, and certainty.
5. Retain: confirm according to the configured approval policy.
6. Retrieve: select relevant memories for future conversations.
7. Update: correct or supersede outdated memories.
8. Forget: process deletion requests and derived data.

The first implementation should favor conservative memory creation.

## 7. Memory Retrieval

The Memory Engine retrieves only a small relevant subset of memories.

Initial retrieval signals:
- Correct character ID.
- Relevance to current topic.
- Memory category.
- Recency, where useful.
- Confirmation status.
- Expiry and supersession status.

Do not retrieve:
- Memories belonging to another character.
- Deleted or superseded memories as current facts.
- Low-certainty inferences as confirmed facts.
- Unrelated personal details.

Initial retrieval can use SQLite queries and simple ranking.

Vector databases and embeddings are optional future enhancements.

## 8. Deletion, Correction, and Privacy

The platform must support:
- Editing a memory.
- Marking a memory as incorrect.
- Superseding outdated memories.
- Deleting memories.
- Deleting conversations.
- Archiving characters.
- Exporting character data.

Deletion must consider derived data, including working-memory summaries and source references.

The product must explain what is deleted and what may remain in backups until their retention period ends.

## 9. SQLite Implementation Notes

Initial requirements:
- Enable foreign-key enforcement on every connection.
- Use parameterized queries.
- Use transactions for multi-record operations.
- Add indexes for character_id, conversation_id, created_at, and memory status as needed.
- Use schema migrations.
- Store timestamps consistently in UTC.
- Keep large media files outside SQLite.
- Encrypt backups.
- Test against the SQLite version available in the selected runtime.

## 10. Initial Build Order

1. Create character registry.
2. Create persona version records.
3. Create conversations and messages.
4. Enforce character ownership.
5. Add working memory.
6. Add candidate and confirmed long-term memories.
7. Add memory source references.
8. Add correction and deletion workflows.
9. Add relationship-state versioning.
10. Test isolation with at least two characters.

## 11. Acceptance Criteria

The foundation is ready when:

- Two or more characters can be created.
- Each character has independent conversations.
- Messages cannot be attached to another character's conversation.
- Memory retrieval never crosses character boundaries.
- Candidate and confirmed memories are distinguishable.
- Memories can be traced to sources where available.
- Corrections can supersede outdated memories.
- Deletion behavior is documented and tested.
- Database backups can be restored.

## 12. Open Decisions

Still to be decided:
- Whether memory candidates require user approval, automatic approval under strict rules, or a hybrid policy.
- Exact memory categories.
- Certainty representation.
- Retention periods.
- Whether embeddings are necessary.
- Final schema and migration tooling.
- Whether multi-user support is required in the first release.

## 13. Current Status

Stage: Database and Memory Architecture Design.

Next milestone: Review this conceptual model, then create the first SQLite schema and migration.

No production database has been created yet.

## 14. Architecture Decisions

The following decisions are approved for the initial version of the platform.

14.1 Memory Approval: Hybrid

The platform uses a hybrid memory approval system.

- The AI may automatically identify potential memory items from conversations.
- Only explicit, non-sensitive, and high-confidence information may be automatically approved.
- Ambiguous, inferred, sensitive, or uncertain information must remain pending until reviewed by the user.
- The user can inspect, correct, approve, reject, or delete memory items.
- Automatic approval must follow the restrictions defined in Section 15.

14.2 Memory Sharing: Selective

Each character has its own isolated memory space.

- Characters cannot access another character's memories by default.
- The user may explicitly share individual confirmed memory items with selected characters.
- Sharing one memory does not grant access to the original conversation or other memories.
- The user can revoke memory-sharing permissions at any time.
- Sensitive memories cannot be shared in the initial version.

14.3 Platform Ownership: Single-User

The initial version is designed for one user.

- No multi-user account system is required for the initial implementation.
- Character data belongs to the platform owner.
- The database must retain character-level data isolation.
- The architecture should remain extendable to support multiple users in a future version without requiring a complete redesign.

---

## 15. Hybrid Memory Approval Policy

15.1 Memory Candidate Identification

The AI may identify potential memories from conversation messages and create memory candidates.

Each candidate should contain:

- The memory content.
- The owning character ID.
- Its source message or conversation reference, when available.
- Its source type.
- Its confidence score.
- Its sensitivity classification.
- Its approval status.
- Its creation timestamp.

Identifying a candidate does not automatically mean that the information is approved for long-term storage.

15.2 Automatic Approval Conditions

A memory candidate may be automatically approved only when all of the following conditions are met:

1. The information was explicitly stated by the user.
2. The information is classified as non-sensitive.
3. The confidence score is at least 0.90.
4. The information is not ambiguous or dependent on unsupported assumptions.

Automatic approval must not be used for inferred personal information, sensitive information, or uncertain interpretations.

15.3 User Review Required

The following candidates must remain pending until the user reviews them:

- Inferred information.
- Ambiguous statements.
- Sensitive personal information.
- Information with insufficient confidence.
- Information that could materially affect a character's understanding of the user but is not explicitly confirmed.

The user must be able to:

- Approve a candidate.
- Edit a candidate before approval.
- Reject a candidate.
- Delete an existing memory.
- Correct an inaccurate memory.

15.4 Memory Status Lifecycle

Memory items use the following lifecycle statuses:

Status| Description
candidate| Identified but not yet confirmed
confirmed| Approved for long-term use
superseded| Replaced by a newer or corrected memory
rejected| Explicitly rejected by the user
deleted| Marked as deleted and excluded from retrieval

Approval status and memory lifecycle status are separate concepts.

Approval status records how a memory was approved:

- "pending"
- "auto_approved"
- "user_approved"
- "rejected"

A memory must not be retrieved as an active long-term memory unless its lifecycle status is "confirmed".

---

## 16. Selective Memory Sharing

16.1 Default Isolation

Every memory item belongs to exactly one character through its "character_id".

A character may retrieve:

1. Its own confirmed memories.
2. Individual memories explicitly shared with it by another character.

A character must never gain access to another character's conversation history simply because a memory was shared.

16.2 Sharing Requirements

A memory may be shared only when:

- Its lifecycle status is "confirmed".
- Its sensitivity classification is "normal".
- Its approval status is "auto_approved" or "user_approved".
- The source and target characters are different.
- The user explicitly authorizes the sharing action.

Sensitive memories must not be shared in the initial version.

16.3 Sharing Records

The "memory_shares" table records individual sharing permissions.

Each record must identify:

- The original memory.
- The source character.
- The target character.
- The sharing status.
- The creation timestamp.
- The revocation timestamp, when applicable.

A sharing permission can have the following statuses:

- "active"
- "revoked"

A revoked permission must no longer provide access to the memory.

16.4 Sharing Revocation

The user may revoke a sharing permission at any time.

After revocation:

- The target character must no longer retrieve the shared memory.
- The original memory remains owned by its source character.
- The original conversation remains inaccessible to the target character.
- Other sharing permissions are not affected.

Revoking access must not delete the original memory.

16.5 Memory Retrieval Rules

Memory retrieval must enforce character ownership and sharing permissions at the database or service layer.

The retrieval process must not rely solely on AI instructions to enforce isolation.

---

## 17. Single-User Architecture

17.1 Initial Scope

The initial platform supports one owner.

The first version does not require:

- User registration.
- Multi-user account management.
- User roles and permissions.
- A separate user table.

Character identity and ownership remain separate concepts. Characters represent AI personas, not platform users.

17.2 Data Ownership

All platform data belongs to the single platform owner.

Character-specific data must remain associated with its owning character.

Shared infrastructure data, such as AI provider configurations and global platform settings, may be managed centrally.

17.3 Future Compatibility

Although multi-user support is not part of the initial implementation, the database design should avoid assumptions that would make future migration unnecessarily difficult.

Future multi-user support may introduce:

- A "users" table.
- An owner or user reference for characters.
- User-level access control.
- User-scoped provider connections and settings.

These components must not be implemented until multi-user support becomes an explicit project requirement.

---

## 18. Implementation Constraints

The initial database implementation must follow these constraints:

1. SQLite is the initial database engine.
2. Every character-owned record must preserve character-level ownership.
3. Memory retrieval must enforce ownership and sharing permissions.
4. Raw API keys and provider credentials must never be stored directly in ordinary database fields.
5. Provider credentials must be referenced through a secure credential-storage mechanism.
6. Memory sources should preserve provenance whenever possible.
7. Deletion and correction operations must maintain memory consistency.
8. Database migrations must be versioned.
9. The application must support database backup and restoration.
10. Memory sharing and automatic approval must be enforced by application logic and database constraints where practical.

The initial implementation must be tested with at least two characters to verify that memory isolation and selective sharing work as intended.
