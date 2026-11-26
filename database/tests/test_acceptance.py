"""Acceptance tests for the initial SQLite schema.

Run from the repository root:
    python -m unittest discover -s database/tests -v

The tests use an in-memory database and never modify a production database.
"""
from pathlib import Path
import sqlite3
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = REPO_ROOT / "database" / "schema" / "001_initial.sql"


class DatabaseAcceptanceTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        self.db.row_factory = sqlite3.Row
        self.db.execute("PRAGMA foreign_keys = ON")
        self.db.executescript(SCHEMA_PATH.read_text(encoding="utf-8"))

    def tearDown(self):
        self.db.close()

    def execute(self, sql, params=()):
        return self.db.execute(sql, params)

    def assertIntegrityError(self, sql, params=()):
        with self.assertRaises(sqlite3.IntegrityError):
            self.execute(sql, params)

    def add_character(self, character_id):
        self.execute(
            "INSERT INTO characters(character_id, slug, display_name) VALUES (?, ?, ?)",
            (character_id, character_id.lower(), character_id),
        )

    def add_persona(self, persona_id, character_id, version=1, active=1):
        self.execute(
            """INSERT INTO persona_versions
               (persona_version_id, character_id, version_number,
                configuration_json, is_active)
               VALUES (?, ?, ?, ?, ?)""",
            (persona_id, character_id, version, '{"persona":"test"}', active),
        )

    def add_conversation(self, conversation_id, character_id, persona_id=None):
        self.execute(
            """INSERT INTO conversations
               (conversation_id, character_id, title, persona_version_id)
               VALUES (?, ?, ?, ?)""",
            (conversation_id, character_id, conversation_id, persona_id),
        )

    def add_message(self, message_id, conversation_id, character_id, sequence=1):
        self.execute(
            """INSERT INTO messages
               (message_id, conversation_id, character_id, sequence_number,
                role, content)
               VALUES (?, ?, ?, ?, 'user', 'test message')""",
            (message_id, conversation_id, character_id, sequence),
        )

    def add_memory(
        self, memory_id, character_id, *, status="confirmed",
        approval="user_approved", source_type="explicit",
        sensitivity="normal", certainty=0.95
    ):
        self.execute(
            """INSERT INTO memory_items
               (memory_id, character_id, category, content, status,
                approval_status, source_type, sensitivity, certainty)
               VALUES (?, ?, 'preference', 'test memory', ?, ?, ?, ?, ?)""",
            (memory_id, character_id, status, approval, source_type,
             sensitivity, certainty),
        )

    def test_01_schema_objects_and_foreign_keys(self):
        tables = {
            row["name"] for row in self.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            )
        }
        expected = {
            "characters", "persona_versions", "conversations", "ai_providers",
            "ai_models", "model_policies", "provider_connections", "messages",
            "working_memory", "memory_items", "memory_sources", "memory_shares",
            "relationship_states", "platform_settings",
        }
        self.assertTrue(expected.issubset(tables))
        self.assertIsNotNone(self.execute(
            "SELECT name FROM sqlite_master WHERE type='view' "
            "AND name='v_accessible_memories'"
        ).fetchone())
        self.assertEqual(self.execute("PRAGMA foreign_key_check").fetchall(), [])

    def test_02_character_data_isolation_via_composite_foreign_keys(self):
        self.add_character("A")
        self.add_character("B")
        self.add_conversation("CONV-A", "A")
        self.assertIntegrityError(
            """INSERT INTO messages
               (message_id, conversation_id, character_id, sequence_number, role, content)
               VALUES ('MSG-X', 'CONV-A', 'B', 1, 'user', 'cross-character')"""
        )

    def test_03_working_memory_cannot_cross_character_conversations(self):
        self.add_character("A")
        self.add_character("B")
        self.add_conversation("CONV-A", "A")
        self.assertIntegrityError(
            """INSERT INTO working_memory
               (working_memory_id, character_id, conversation_id, summary)
               VALUES ('WM-X', 'B', 'CONV-A', 'invalid cross-character summary')"""
        )

    def test_04_persona_version_isolation_and_one_active_persona(self):
        self.add_character("A")
        self.add_character("B")
        self.add_persona("P-A1", "A")
        self.assertIntegrityError(
            """INSERT INTO conversations
               (conversation_id, character_id, persona_version_id)
               VALUES ('CONV-B', 'B', 'P-A1')"""
        )
        self.assertIntegrityError(
            """INSERT INTO persona_versions
               (persona_version_id, character_id, version_number,
                configuration_json, is_active)
               VALUES ('P-A2', 'A', 2, '{"persona":"second"}', 1)"""
        )

    def test_05_automatic_memory_approval_policy(self):
        self.add_character("A")
        self.add_memory(
            "M-AUTO", "A", status="confirmed", approval="auto_approved",
            source_type="explicit", sensitivity="normal", certainty=0.90
        )
        self.assertIntegrityError(
            """INSERT INTO memory_items
               (memory_id, character_id, category, content, status,
                approval_status, source_type, sensitivity, certainty)
               VALUES ('M-LOW', 'A', 'fact', 'low confidence', 'candidate',
                'auto_approved', 'explicit', 'normal', 0.89)"""
        )
        self.assertIntegrityError(
            """INSERT INTO memory_items
               (memory_id, character_id, category, content, status,
                approval_status, source_type, sensitivity, certainty)
               VALUES ('M-INFERRED', 'A', 'fact', 'inferred', 'candidate',
                'auto_approved', 'inferred', 'normal', 0.99)"""
        )
        self.assertIntegrityError(
            """INSERT INTO memory_items
               (memory_id, character_id, category, content, status,
                approval_status, source_type, sensitivity, certainty)
               VALUES ('M-SENSITIVE', 'A', 'fact', 'sensitive', 'candidate',
                'auto_approved', 'explicit', 'sensitive', 0.99)"""
        )

    def test_06_pending_memory_cannot_be_confirmed_without_approval(self):
        self.add_character("A")
        self.add_memory(
            "M-PENDING", "A", status="candidate", approval="pending",
            source_type="inferred", certainty=0.60
        )
        self.assertIntegrityError(
            "UPDATE memory_items SET status='confirmed' WHERE memory_id='M-PENDING'"
        )
        self.execute(
            """UPDATE memory_items
               SET approval_status='user_approved', status='confirmed',
                   reviewed_at=strftime('%Y-%m-%dT%H:%M:%fZ','now')
               WHERE memory_id='M-PENDING'"""
        )
        row = self.execute(
            "SELECT status, approval_status FROM memory_items WHERE memory_id='M-PENDING'"
        ).fetchone()
        self.assertEqual((row["status"], row["approval_status"]),
                         ("confirmed", "user_approved"))

    def test_07_memory_sharing_visibility_revocation_and_reactivation(self):
        self.add_character("A")
        self.add_character("B")
        self.add_character("C")
        self.add_memory("M-SHARE", "A")

        self.execute(
            """INSERT INTO memory_shares
               (memory_share_id, memory_id, source_character_id, target_character_id)
               VALUES ('SHARE-AB', 'M-SHARE', 'A', 'B')"""
        )
        visible = {
            row["accessible_to_character_id"]
            for row in self.execute(
                "SELECT accessible_to_character_id FROM v_accessible_memories "
                "WHERE memory_id='M-SHARE'"
            )
        }
        self.assertEqual(visible, {"A", "B"})
        self.assertEqual(self.execute(
            "SELECT COUNT(*) FROM v_accessible_memories "
            "WHERE memory_id='M-SHARE' AND accessible_to_character_id='C'"
        ).fetchone()[0], 0)

        self.execute(
            """UPDATE memory_shares
               SET status='revoked', revoked_at='2026-01-01T00:00:00Z'
               WHERE memory_share_id='SHARE-AB'"""
        )
        self.assertEqual(self.execute(
            "SELECT COUNT(*) FROM v_accessible_memories "
            "WHERE memory_id='M-SHARE' AND accessible_to_character_id='B'"
        ).fetchone()[0], 0)

        self.execute(
            """UPDATE memory_shares
               SET status='active', revoked_at=NULL
               WHERE memory_share_id='SHARE-AB'"""
        )
        self.assertEqual(self.execute(
            "SELECT COUNT(*) FROM v_accessible_memories "
            "WHERE memory_id='M-SHARE' AND accessible_to_character_id='B'"
        ).fetchone()[0], 1)

    def test_08_invalid_memory_cannot_be_shared_and_invalidated_share_is_revoked(self):
        self.add_character("A")
        self.add_character("B")
        self.add_memory("M-SHARE", "A")
        # The valid confirmed memory is shareable; the candidate below is not.

        # A candidate/pending memory is not eligible for sharing.
        self.add_memory(
            "M-CANDIDATE", "A", status="candidate", approval="pending",
            source_type="inferred", certainty=0.50
        )
        self.assertIntegrityError(
            """INSERT INTO memory_shares
               (memory_share_id, memory_id, source_character_id, target_character_id)
               VALUES ('SHARE-CANDIDATE', 'M-CANDIDATE', 'A', 'B')"""
        )

        self.execute(
            """INSERT INTO memory_shares
               (memory_share_id, memory_id, source_character_id, target_character_id)
               VALUES ('SHARE-OK', 'M-SHARE', 'A', 'B')"""
        )
        # Change approval first so the row remains valid under memory CHECK constraints.
        self.execute(
            """UPDATE memory_items
               SET approval_status='user_approved', sensitivity='sensitive'
               WHERE memory_id='M-SHARE'"""
        )
        share = self.execute(
            "SELECT status, revoked_at FROM memory_shares WHERE memory_share_id='SHARE-OK'"
        ).fetchone()
        self.assertEqual(share["status"], "revoked")
        self.assertIsNotNone(share["revoked_at"])
        self.assertEqual(self.execute(
            "SELECT COUNT(*) FROM v_accessible_memories "
            "WHERE memory_id='M-SHARE' AND accessible_to_character_id='B'"
        ).fetchone()[0], 0)

    def test_09_message_source_must_be_detached_before_message_deletion(self):
        self.add_character("A")
        self.add_conversation("CONV-A", "A")
        self.add_message("MSG-A", "CONV-A", "A")
        self.add_memory("M-A", "A")
        self.execute(
            """INSERT INTO memory_sources
               (memory_source_id, memory_id, character_id, message_id)
               VALUES ('SRC-A', 'M-A', 'A', 'MSG-A')"""
        )
        self.assertIntegrityError("DELETE FROM messages WHERE message_id='MSG-A'")
        self.execute(
            "UPDATE memory_sources SET message_id=NULL WHERE memory_source_id='SRC-A'"
        )
        self.execute("DELETE FROM messages WHERE message_id='MSG-A'")
        self.assertIsNone(self.execute(
            "SELECT message_id FROM memory_sources WHERE memory_source_id='SRC-A'"
        ).fetchone()[0])

    def test_10_model_policy_global_and_character_overrides_are_unique(self):
        self.add_character("A")
        self.add_character("B")
        self.execute("INSERT INTO ai_providers(provider_id, display_name) VALUES ('PROV', 'Provider')")
        self.execute(
            """INSERT INTO ai_models(model_id, provider_id, display_name)
               VALUES ('MODEL', 'PROV', 'Model')"""
        )
        self.execute(
            """INSERT INTO model_policies
               (policy_id, character_id, task_type, preferred_provider_id, preferred_model_id)
               VALUES ('POL-GLOBAL', NULL, 'chat', 'PROV', 'MODEL')"""
        )
        self.execute(
            """INSERT INTO model_policies
               (policy_id, character_id, task_type, preferred_provider_id, preferred_model_id)
               VALUES ('POL-A', 'A', 'chat', 'PROV', 'MODEL')"""
        )
        self.execute(
            """INSERT INTO model_policies
               (policy_id, character_id, task_type, preferred_provider_id, preferred_model_id)
               VALUES ('POL-B', 'B', 'chat', 'PROV', 'MODEL')"""
        )
        self.assertIntegrityError(
            """INSERT INTO model_policies
               (policy_id, character_id, task_type)
               VALUES ('POL-GLOBAL-DUP', NULL, 'chat')"""
        )
        self.assertIntegrityError(
            """INSERT INTO model_policies
               (policy_id, character_id, task_type)
               VALUES ('POL-A-DUP', 'A', 'chat')"""
        )
        self.assertEqual(self.execute(
            "SELECT COUNT(*) FROM model_policies WHERE task_type='chat'"
        ).fetchone()[0], 3)

    def test_11_relationship_state_versions_are_character_scoped(self):
        self.add_character("A")
        self.add_character("B")
        self.execute(
            """INSERT INTO relationship_states
               (relationship_state_id, character_id, state_version, state_json)
               VALUES ('RS-A1', 'A', 1, '{"level":1}')"""
        )
        self.execute(
            """INSERT INTO relationship_states
               (relationship_state_id, character_id, state_version, state_json)
               VALUES ('RS-B1', 'B', 1, '{"level":1}')"""
        )
        self.assertIntegrityError(
            """INSERT INTO relationship_states
               (relationship_state_id, character_id, state_version, state_json)
               VALUES ('RS-A1-DUP', 'A', 1, '{"level":2}')"""
        )

    def test_12_character_deletion_cascades_owned_data_when_sources_are_detached(self):
        self.add_character("A")
        self.add_conversation("CONV-A", "A")
        self.add_message("MSG-A", "CONV-A", "A")
        self.add_memory("M-A", "A")
        self.execute(
            """INSERT INTO memory_sources
               (memory_source_id, memory_id, character_id, message_id)
               VALUES ('SRC-A', 'M-A', 'A', 'MSG-A')"""
        )
        self.execute(
            "UPDATE memory_sources SET message_id=NULL WHERE memory_source_id='SRC-A'"
        )
        self.execute("DELETE FROM characters WHERE character_id='A'")
        self.assertEqual(self.execute(
            "SELECT COUNT(*) FROM memory_items WHERE character_id='A'"
        ).fetchone()[0], 0)
        self.assertEqual(self.execute(
            "SELECT COUNT(*) FROM conversations WHERE character_id='A'"
        ).fetchone()[0], 0)

    def test_13_json_columns_reject_invalid_json(self):
        self.add_character("A")
        self.assertIntegrityError(
            """INSERT INTO persona_versions
               (persona_version_id, character_id, version_number, configuration_json)
               VALUES ('P-BAD', 'A', 1, 'not-json')"""
        )
        self.assertIntegrityError(
            """INSERT INTO platform_settings(setting_key, setting_value)
               VALUES ('bad', 'not-json')"""
        )


if __name__ == "__main__":
    unittest.main()
