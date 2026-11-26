
-- ============================================================
-- AI CHARACTER PLATFORM
-- DATABASE SCHEMA V1
-- Database: SQLite
-- ============================================================

PRAGMA foreign_keys = ON;

-- ------------------------------------------------------------
-- 1. CHARACTERS
-- ------------------------------------------------------------

CREATE TABLE characters (
    character_id TEXT PRIMARY KEY,
    slug TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    description TEXT,

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'archived', 'deleted')),

    created_at TEXT NOT NULL DEFAULT
        (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

    updated_at TEXT NOT NULL DEFAULT
        (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- ------------------------------------------------------------
-- 2. PERSONA VERSIONS
-- ------------------------------------------------------------

CREATE TABLE persona_versions (
    persona_version_id TEXT PRIMARY KEY,
    character_id TEXT NOT NULL,

    version_number INTEGER NOT NULL
        CHECK (version_number > 0),

    configuration_json TEXT NOT NULL
        CHECK (json_valid(configuration_json)),

    change_summary TEXT,

    is_active INTEGER NOT NULL DEFAULT 0
        CHECK (is_active IN (0, 1)),

    created_at TEXT NOT NULL DEFAULT
        (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

    UNIQUE (character_id, version_number),
    UNIQUE (persona_version_id, character_id),

    FOREIGN KEY (character_id)
        REFERENCES characters(character_id)
        ON DELETE CASCADE
);

CREATE UNIQUE INDEX idx_one_active_persona
ON persona_versions(character_id)
WHERE is_active = 1;

-- ------------------------------------------------------------
-- 3. CONVERSATIONS
-- ------------------------------------------------------------

CREATE TABLE conversations (
    conversation_id TEXT PRIMARY KEY,
    character_id TEXT NOT NULL,

    title TEXT,

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'archived', 'deleted')),

    persona_version_id TEXT,

    started_at TEXT NOT NULL DEFAULT
        (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

    last_message_at TEXT,
    archived_at TEXT,

    UNIQUE (conversation_id, character_id),

    FOREIGN KEY (character_id)
        REFERENCES characters(character_id)
        ON DELETE CASCADE,

    FOREIGN KEY (persona_version_id, character_id)
        REFERENCES persona_versions(
            persona_version_id,
            character_id
        )
        ON DELETE RESTRICT
);

CREATE INDEX idx_conversations_character
ON conversations(character_id, last_message_at);

-- ------------------------------------------------------------
-- 4. AI PROVIDERS
-- ------------------------------------------------------------

CREATE TABLE ai_providers (
    provider_id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'disabled'))
);

-- ------------------------------------------------------------
-- 5. AI MODELS
-- ------------------------------------------------------------

CREATE TABLE ai_models (
    model_id TEXT PRIMARY KEY,
    provider_id TEXT NOT NULL,

    display_name TEXT NOT NULL,

    capabilities_json TEXT
        CHECK (
            capabilities_json IS NULL
            OR json_valid(capabilities_json)
        ),

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'disabled')),

    UNIQUE (model_id, provider_id),

    FOREIGN KEY (provider_id)
        REFERENCES ai_providers(provider_id)
        ON DELETE RESTRICT
);

-- ------------------------------------------------------------
-- 6. PROVIDER CONNECTIONS
-- ------------------------------------------------------------

CREATE TABLE provider_connections (
    connection_id TEXT PRIMARY KEY,
    provider_id TEXT NOT NULL,

    auth_method TEXT NOT NULL,

    status TEXT NOT NULL DEFAULT 'disconnected'
        CHECK (
            status IN (
                'connected',
                'disconnected',
                'expired',
                'error'
            )
        ),

    credential_ref TEXT,
    last_checked_at TEXT,

    created_at TEXT NOT NULL DEFAULT
        (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

    FOREIGN KEY (provider_id)
        REFERENCES ai_providers(provider_id)
        ON DELETE RESTRICT
);

-- credential_ref points to secure storage.
-- Never store raw API keys or OAuth tokens here.

-- ------------------------------------------------------------
-- 7. MESSAGES
-- ------------------------------------------------------------

CREATE TABLE messages (
    message_id TEXT PRIMARY KEY,

    conversation_id TEXT NOT NULL,
    character_id TEXT NOT NULL,

    sequence_number INTEGER NOT NULL
        CHECK (sequence_number > 0),

    role TEXT NOT NULL
        CHECK (role IN ('user', 'assistant', 'system')),

    content TEXT NOT NULL,

    provider_id TEXT,
    model_id TEXT,

    message_status TEXT NOT NULL DEFAULT 'complete'
        CHECK (
            message_status IN (
                'complete',
                'failed',
                'partial'
            )
        ),

    created_at TEXT NOT NULL DEFAULT
        (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

    UNIQUE (conversation_id, sequence_number),
    UNIQUE (message_id, character_id),

    CHECK (
        (provider_id IS NULL AND model_id IS NULL)
        OR
        (provider_id IS NOT NULL AND model_id IS NOT NULL)
    ),

    FOREIGN KEY (conversation_id, character_id)
        REFERENCES conversations(
            conversation_id,
            character_id
        )
        ON DELETE CASCADE,

    FOREIGN KEY (model_id, provider_id)
        REFERENCES ai_models(model_id, provider_id)
        ON DELETE RESTRICT
);

CREATE INDEX idx_messages_conversation
ON messages(conversation_id, sequence_number);

CREATE INDEX idx_messages_character
ON messages(character_id, created_at);

-- ------------------------------------------------------------
-- 8. WORKING MEMORY
-- ------------------------------------------------------------

CREATE TABLE working_memory (
    working_memory_id TEXT PRIMARY KEY,

    character_id TEXT NOT NULL,
    conversation_id TEXT NOT NULL,

    summary TEXT,

    context_json TEXT
        CHECK (
            context_json IS NULL
            OR json_valid(context_json)
        ),

    updated_at TEXT NOT NULL DEFAULT
        (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

    expires_at TEXT,

    UNIQUE (conversation_id),

    FOREIGN KEY (message_id, character_id)
    REFERENCES messages(
        message_id,
        character_id
    )
    ON DELETE RESTRICT
);

-- ------------------------------------------------------------
-- 9. LONG-TERM MEMORY ITEMS
-- ------------------------------------------------------------

CREATE TABLE memory_items (
    memory_id TEXT PRIMARY KEY,
    character_id TEXT NOT NULL,

    category TEXT NOT NULL,
    content TEXT NOT NULL,

    status TEXT NOT NULL DEFAULT 'candidate'
        CHECK (
            status IN (
                'candidate',
                'confirmed',
                'superseded',
                'rejected',
                'deleted'
            )
        ),

    approval_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (
            approval_status IN (
                'pending',
                'auto_approved',
                'user_approved',
                'rejected'
            )
        ),

    source_type TEXT NOT NULL
        CHECK (
            source_type IN (
                'explicit',
                'inferred',
                'user_approved'
            )
        ),

    sensitivity TEXT NOT NULL DEFAULT 'normal'
        CHECK (
            sensitivity IN ('normal', 'sensitive')
        ),

    certainty REAL
        CHECK (
            certainty IS NULL
            OR (certainty >= 0 AND certainty <= 1)
        ),

    supersedes_memory_id TEXT,

    review_note TEXT,

    created_at TEXT NOT NULL DEFAULT
        (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

    updated_at TEXT NOT NULL DEFAULT
        (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

    reviewed_at TEXT,
    expires_at TEXT,

    UNIQUE (memory_id, character_id),

    CHECK (
        status != 'confirmed'
        OR approval_status IN (
            'auto_approved',
            'user_approved'
        )
    ),

    FOREIGN KEY (character_id)
        REFERENCES characters(character_id)
        ON DELETE CASCADE,

    FOREIGN KEY (supersedes_memory_id, character_id)
        REFERENCES memory_items(
            memory_id,
            character_id
        )
        ON DELETE RESTRICT
);

CREATE INDEX idx_memory_character_status
ON memory_items(character_id, status);

CREATE INDEX idx_memory_category
ON memory_items(character_id, category);

-- ------------------------------------------------------------
-- 10. MEMORY SOURCES
-- ------------------------------------------------------------

CREATE TABLE memory_sources (
    memory_source_id TEXT PRIMARY KEY,

    memory_id TEXT NOT NULL,
    character_id TEXT NOT NULL,

    message_id TEXT,

    source_note TEXT,

    created_at TEXT NOT NULL DEFAULT
        (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

    FOREIGN KEY (memory_id, character_id)
        REFERENCES memory_items(
            memory_id,
            character_id
        )
        ON DELETE CASCADE,

    FOREIGN KEY (message_id, character_id)
        REFERENCES messages(
            message_id,
            character_id
        )
        ON DELETE SET NULL
);

CREATE INDEX idx_memory_sources_memory
ON memory_sources(memory_id);

-- ------------------------------------------------------------
-- 11. MEMORY SHARES
-- ------------------------------------------------------------

CREATE TABLE memory_shares (
    memory_share_id TEXT PRIMARY KEY,

    memory_id TEXT NOT NULL,

    source_character_id TEXT NOT NULL,
    target_character_id TEXT NOT NULL,

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'revoked')),

    granted_at TEXT NOT NULL DEFAULT
        (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

    revoked_at TEXT,

    CHECK (source_character_id != target_character_id),

    UNIQUE (memory_id, target_character_id),

    FOREIGN KEY (memory_id, source_character_id)
        REFERENCES memory_items(
            memory_id,
            character_id
        )
        ON DELETE CASCADE,

    FOREIGN KEY (source_character_id)
        REFERENCES characters(character_id)
        ON DELETE CASCADE,

    FOREIGN KEY (target_character_id)
        REFERENCES characters(character_id)
        ON DELETE CASCADE
);

CREATE INDEX idx_memory_shares_target
ON memory_shares(target_character_id, status);

-- Only confirmed, normal-sensitivity memories
-- may be shared with another character.

CREATE TRIGGER trg_validate_memory_share
BEFORE INSERT ON memory_shares
WHEN NEW.status = 'active'
BEGIN
    SELECT CASE
        WHEN NOT EXISTS (
            SELECT 1
            FROM memory_items
            WHERE memory_id = NEW.memory_id
              AND character_id = NEW.source_character_id
              AND status = 'confirmed'
              AND approval_status IN (
                  'auto_approved',
                  'user_approved'
              )
              AND sensitivity = 'normal'
        )
        THEN RAISE(
            ABORT,
            'Only confirmed normal memories can be shared'
        )
    END;
END;

-- Revoke existing shares if a memory becomes
-- unconfirmed, sensitive, or otherwise unavailable.

CREATE TRIGGER trg_revoke_invalid_memory_shares
AFTER UPDATE OF status, sensitivity, approval_status
ON memory_items
WHEN NEW.status != 'confirmed'
  OR NEW.sensitivity != 'normal'
  OR NEW.approval_status NOT IN (
      'auto_approved',
      'user_approved'
  )
BEGIN
    UPDATE memory_shares
    SET status = 'revoked',
        revoked_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
    WHERE memory_id = NEW.memory_id
      AND source_character_id = NEW.character_id
      AND status = 'active';
END;

-- ------------------------------------------------------------
-- 12. MEMORY APPROVAL SAFEGUARD
-- ------------------------------------------------------------

-- Automatic approval is allowed only for explicit,
-- normal-sensitivity, high-certainty memories.
-- Sensitive and inferred memories require review.

CREATE TRIGGER trg_validate_auto_memory
BEFORE INSERT ON memory_items
WHEN NEW.approval_status = 'auto_approved'
BEGIN
    SELECT CASE
        WHEN NEW.source_type != 'explicit'
          OR NEW.sensitivity != 'normal'
          OR NEW.certainty IS NULL
          OR NEW.certainty < 0.90
        THEN RAISE(
            ABORT,
            'Memory does not meet automatic approval policy'
        )
    END;
END;

CREATE TRIGGER trg_validate_auto_memory_update
BEFORE UPDATE OF approval_status, source_type,
                 sensitivity, certainty
ON memory_items
WHEN NEW.approval_status = 'auto_approved'
BEGIN
    SELECT CASE
        WHEN NEW.source_type != 'explicit'
          OR NEW.sensitivity != 'normal'
          OR NEW.certainty IS NULL
          OR NEW.certainty < 0.90
        THEN RAISE(
            ABORT,
            'Memory does not meet automatic approval policy'
        )
    END;
END;

-- ------------------------------------------------------------
-- 13. RELATIONSHIP STATES
-- ------------------------------------------------------------

CREATE TABLE relationship_states (
    relationship_state_id TEXT PRIMARY KEY,

    character_id TEXT NOT NULL,

    state_version INTEGER NOT NULL
        CHECK (state_version > 0),

    state_json TEXT NOT NULL
        CHECK (json_valid(state_json)),

    evidence_summary TEXT,

    created_at TEXT NOT NULL DEFAULT
        (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

    UNIQUE (character_id, state_version),

    FOREIGN KEY (character_id)
        REFERENCES characters(character_id)
        ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- 14. PLATFORM SETTINGS
-- ------------------------------------------------------------

CREATE TABLE platform_settings (
    setting_key TEXT PRIMARY KEY,

    setting_value TEXT NOT NULL
        CHECK (json_valid(setting_value)),

    updated_at TEXT NOT NULL DEFAULT
        (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- ------------------------------------------------------------
-- 15. ACCESSIBLE MEMORY VIEW
-- ------------------------------------------------------------

-- A character can access:
-- 1. Its own confirmed memories.
-- 2. Memories explicitly shared with it.
--
-- Shared memories do not grant access to source conversations.

CREATE VIEW v_accessible_memories AS

SELECT
    memory_id,
    character_id AS owner_character_id,
    character_id AS accessible_to_character_id,
    category,
    content,
    sensitivity,
    created_at
FROM memory_items
WHERE status = 'confirmed'
  AND approval_status IN (
      'auto_approved',
      'user_approved'
  )

UNION ALL

SELECT
    m.memory_id,
    m.character_id AS owner_character_id,
    s.target_character_id AS accessible_to_character_id,
    m.category,
    m.content,
    m.sensitivity,
    m.created_at
FROM memory_shares s
JOIN memory_items m
  ON m.memory_id = s.memory_id
 AND m.character_id = s.source_character_id
WHERE s.status = 'active'
  AND m.status = 'confirmed'
  AND m.approval_status IN (
      'auto_approved',
      'user_approved'
  )
  AND m.sensitivity = 'normal';

-- ============================================================
-- END OF INITIAL SCHEMA
-- ============================================================
