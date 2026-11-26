# DATABASE & MEMORY — RUNTIME BOUNDARY UPDATE

This addendum clarifies the existing database design. It does not replace the existing table definitions.

## 1. Agent runtime is not the source of truth

- SQLite remains the canonical store for characters, persona versions, conversations, messages, memories, memory shares, and relationship state.
- Agent-specific session files are optional runtime state. They must not replace or override canonical platform records.
- The runtime receives only the selected character's approved persona, eligible memory items, relationship context, and bounded conversation history for the current turn.
- The agent runtime must not connect directly to SQLite or issue unrestricted cross-character queries.
- Runtime session identifiers must be scoped to a validated character and conversation. Session reuse across characters is prohibited.
- CLI sign-in state, OAuth tokens, and API credentials must not be stored in SQLite. Any `credential_ref` is a pointer to a separately protected store.
- Runtime caches and agent session files must be excluded from ordinary database exports and backups unless a future encrypted-backup design explicitly covers them.
- A memory share exposes only the individually authorized memory item. It never grants access to the source conversation or the source character's other records.
- The platform must remain usable for character management and memory inspection even when no eligible free AI route is available.

## 2. Database test status

The current SQLite schema has 14 tables, one view, five triggers, and supporting indexes. The existing acceptance suite has 13 tests, previously run with 13/13 passing against the matching SQL schema in an isolated test database.

That result validates database-level constraints only. It does not prove that API routes, application services, agent processes, runtime credentials, or network access are secure.

## 3. Remaining tests

- Application/service-layer character isolation.
- Memory sharing and revocation integration tests.
- Memory deletion and correction integration tests.
- Backup and restoration.
- Runtime session scoping.
- Credential-store and backup exclusion.
- Cross-character context leakage tests.
