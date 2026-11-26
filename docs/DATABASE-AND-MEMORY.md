
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
