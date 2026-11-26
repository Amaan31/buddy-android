# AI CHARACTER PLATFORM — FOUNDATION

**Project Type:** Multi-Character AI Companion Platform  
**Project Name:** To be determined  
**Stage:** Architecture Foundation  
**Cost Policy:** 100% free; no paid AI usage or paid infrastructure

## 1. Project Overview

This project is a platform for creating, managing, and interacting with multiple independent AI characters.

The platform is not dedicated to a single character. Sania is one planned character among many.

Each character has its own identity, personality, communication style, conversation history, memories, and relationship development.

The platform provides shared infrastructure while maintaining logical data isolation between characters. Character identity and continuity must remain consistent even when the underlying agent, model, or provider changes.

The AI capability is supplied by an external AI model or service. The platform owns the companion experience and its persistent state; an external agent/CLI is an execution adapter, not the owner of character identity, memory, conversation records, or relationship state.

## 2. Core Principles

- Multi-character architecture with independent character identity and personality.
- Character-specific conversation history, memories, and relationship development.
- Provider- and agent-independent character configuration.
- Shared infrastructure with strict logical isolation between characters.
- AI execution through external agents/models where the route is officially supported and genuinely free.
- 100% free operation: no required paid service, API billing, subscription, credit card, or billable overage.
- No silent paid fallback. Unknown-cost routes are unavailable.
- User-controlled memory approval, correction, sharing, and deletion.
- Secure handling of authentication material.
- Modular architecture with testable boundaries.
- Privacy-aware use of reference conversations.

## 3. High-Level Architecture

### Client Layer
- Progressive Web App (PWA).
- POCO F6 as the primary client.
- Browser access from other devices only after secure remote access is designed and tested.

### Platform Core
- Character Manager.
- Persona Engine.
- Conversation Engine.
- Memory Engine.
- Relationship Engine.
- Model/Agent Policy Resolver.
- Agent Runtime Manager.
- Provider/Agent Adapter Registry.
- Authentication Boundary.
- Context Assembler and Output Validator.

### Agent Runtime Layer
- Runs a selected external agent CLI or compatible execution adapter.
- May use an isolated Linux userland through proot, following the technical pattern used by Buddy.
- Starts and supervises agent processes, sends a bounded prompt, receives streamed output, handles cancellation, and reports runtime status.
- Does not own canonical conversation history, character configuration, memories, or relationship state.
- Receives only the selected character's assembled context and the minimum data needed for the current turn.
- Has no general phone-control, accessibility, filesystem, shell, or network tools by default. Any future tool capability requires a separate permission design and tests.

### AI Execution Layer
- External AI models/services accessed only through officially supported and terms-permitted routes.
- Local inference may be evaluated separately as an optional no-cost route.
- Agent CLI authentication and model/provider authentication are distinct concerns and must be documented per adapter.
- A consumer subscription must not be assumed to authorize third-party CLI/API use.

### Data Layer
- SQLite as the initial database candidate.
- Character profiles and persona versions.
- Conversation and message history.
- Working and long-term memories.
- Relationship states.
- Agent/provider definitions and model policies.
- Platform settings and non-secret runtime metadata.

### Infrastructure
- Mi 9 SE is a proposed host candidate only, not an approved deployment target.
- POCO F6 is the primary client.
- Encrypted backups and remote access remain design items.
- No paid hosting, database, storage, tunnel, authentication, monitoring, analytics, or automation dependency.

## 4. Shared Platform Components

### Character Manager
Creates, edits, archives, and selects characters. Each character receives a unique identifier.

### Persona Engine
Loads the selected character's approved identity, personality, communication style, boundaries, and behavior rules. The platform must not invent character biography or personal history.

### Conversation Engine
Coordinates each turn and combines the selected persona, eligible memories, relationship context, and bounded recent conversation history. It persists canonical messages independently of the agent runtime.

### Memory Engine
Detects memory candidates, applies the approved review policy, retrieves eligible memories, and supports correction, sharing, expiry, and deletion.

### Relationship Engine
Tracks gradual relationship development independently for each character. Relationship state is platform data, not an agent-owned session.

### Agent Runtime Manager
Selects and supervises a compatible agent adapter, starts a process, streams output, enforces time/resource limits where available, and terminates failed or cancelled runs. Runtime-specific session files are disposable implementation details, not the canonical record.

### Agent/Provider Adapter Registry
Describes each adapter's supported authentication method, model access, tool capabilities, cost classification, platform/ABI requirements, and known limitations. Unsupported or unverified routes are disabled.

### Model/Agent Policy Resolver
Chooses only an enabled, compatible, verified-free or local route. It must reject unknown-cost and paid routes. Fallback is allowed only among explicitly configured eligible free/local candidates.

### Authentication Boundary
Keeps CLI sign-in state, tokens, and credentials outside SQLite, ordinary configuration, frontend state, and logs. If the selected host cannot protect credentials adequately, that adapter remains disabled.

## 5. Character Data Isolation

Every character-specific record must be associated with a unique `character_id`.

The following data belongs to each individual character:

- Character profile and approved biography.
- Personality and persona configuration.
- Conversation history.
- Working and long-term memories.
- Relationship state.
- Character-specific settings and model/agent policy.

One character must never automatically access another character's private memories or conversations. A user-approved memory share may expose only the individual shared memory item and its permitted fields; it never grants access to the source conversation.

## 6. AI and Cost Policy

The platform must remain 100% free to use.

Allowed candidates:
- Local inference that runs on existing hardware without paid licensing or usage charges.
- Remote model/agent routes that are verified to be usable without payment, subscription, credit card, API billing, or billable overage, and whose official terms permit the intended use.
- Free quotas only while their current terms and limits are verified; once exhausted, the route becomes unavailable until a free quota resets.

Disallowed candidates:
- Paid API usage, paid BYOK, prepaid credits, paid subscriptions, required credit cards, or billable overages.
- Routes with unknown or unclear cost.
- Consumer subscription authentication unless official provider terms explicitly permit the intended third-party integration and it remains free.
- Silent fallback from a free/local route to a paid route.

If no eligible route remains, return `NoAvailableFreeModel`. Never send a billable request to preserve availability.

## 7. Deployment and Runtime Candidates

### Primary Client
POCO F6 through a PWA interface.

### Candidate Host
Mi 9 SE is a test candidate only. Approval requires evidence for:
- Android version, ABI, and OS restrictions.
- Proot/Termux and package compatibility.
- Agent CLI installation and authentication.
- Process lifecycle and background survival.
- CPU, RAM, storage, thermal behavior, and battery impact.
- Local network access and secure client-to-host communication.
- Credential protection without a paid service.

### Runtime Strategy
Buddy demonstrates one possible pattern: an Android app can run an Alpine Linux userland through proot, install supported agent CLIs, invoke them as processes, and stream results back to the app. This is a reference pattern, not proof that every CLI or the Mi 9 SE is compatible.

The project will evaluate proot-based Linux and Termux as runtime candidates. No runtime or host is selected until compatibility tests pass.

### Database
SQLite is the initial candidate. The schema must support multiple characters from the beginning.

## 8. Initial Logical Data Domains

- `characters`
- `persona_versions`
- `conversations`
- `messages`
- `working_memory`
- `memory_items`
- `memory_sources`
- `memory_shares`
- `relationship_states`
- `ai_providers`
- `ai_models`
- `provider_connections`
- `model_policies`
- Runtime adapter metadata and non-secret execution records.

Detailed database structures are documented in `docs/DATABASE-AND-MEMORY.md`.

## 9. Development Roadmap

1. Foundation and approved architecture decisions.
2. Multi-character database and memory design.
3. Agent runtime architecture and compatibility test matrix.
4. Character profile and persona architecture.
5. Memory and relationship services.
6. Agent adapters and verified-free/local route evaluation.
7. Conversation orchestration and streaming.
8. PWA interface and character selection.
9. Runtime, isolation, privacy, and security testing.
10. Remote access and backup design, only if a free and secure approach is verified.

## 10. Important Constraints

- The platform must not be limited to Sania.
- Buddy is a technical reference, not the product identity.
- Do not invent the platform's final name.
- Character biographies must be defined or approved by the project owner.
- Do not mix memories between characters.
- Do not copy private reference conversations verbatim.
- Do not expose credentials to clients or logs.
- Do not assume consumer subscriptions permit third-party integration.
- No paid AI, paid BYOK, required paid dependency, or paid fallback.
- Agent runtime sessions are not the source of truth for platform data.
- Phone-control/accessibility tools from Buddy are outside this companion platform's v1 scope.

## 11. Current Status

**Project Stage:** Foundation and architecture alignment.

**Completed:** Multi-character data model draft, initial SQLite schema, database acceptance tests, memory-sharing and memory-approval policies.

**In progress:** Aligning the platform architecture with the actual Buddy-style agent CLI runtime pattern.

**Not yet approved:** Final host device, runtime, backend framework, agent adapter, AI model, authentication route, and remote-access method.

**Implementation gate:** Do not begin backend implementation until the runtime and at least one genuinely free, officially permitted AI route have passed compatibility, cost, and security checks.
