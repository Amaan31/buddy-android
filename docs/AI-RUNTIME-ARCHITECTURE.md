# AI RUNTIME ARCHITECTURE

**Project:** Multi-Character AI Companion Platform  
**Status:** Architecture proposal; runtime and host are not yet selected  
**Related documents:** `PLATFORM-FOUNDATION.md`, `APPROVED-ARCHITECTURE-DECISIONS.md`, `DATABASE-AND-MEMORY.md`, `APPLICATION-SECURITY-AND-BEHAVIOR-TEST-PLAN.md`

## 1. Purpose

Define how the platform can use an external AI model through an agent CLI/runtime while retaining complete ownership of character identity, conversations, memory, and relationship state.

This document adapts the relevant execution pattern from the Buddy Android project. It does not propose copying Buddy's phone-control product features.

## 2. Core Separation of Responsibilities

| Component | Owns | Must not own |
|---|---|---|
| PWA client | UI state, selected character, user input, streamed display | Credentials, canonical memory, unrestricted agent permissions |
| Platform Core | Character/persona, canonical messages, memory, relationship state, policy decisions | Provider billing or agent-specific hidden state |
| Context Assembler | Minimum eligible context for one character and one turn | Cross-character data or unapproved memory |
| Agent Runtime Manager | Process lifecycle, adapter invocation, streaming, timeout, cancellation | Character biography, canonical history, memory approval |
| Agent CLI / model | Producing a response from the supplied prompt | Persistent platform truth, memory sharing, relationship ownership |
| SQLite | Canonical platform records and non-secret metadata | Raw API keys, OAuth tokens, CLI auth files |

An agent may retain its own technical session if required by its CLI, but the platform must be able to reconstruct the conversation from its own database. Agent session state is an optional cache and must never override canonical platform records.

## 3. Proposed Request Flow

1. The client submits a message and the selected `character_id`.
2. The Platform Core validates the character and active conversation context.
3. The Context Assembler loads that character's approved persona, eligible memories, relationship state, and bounded recent conversation history.
4. The Policy Resolver selects an explicitly configured, compatible, verified-free or local route.
5. The Agent Runtime Manager invokes the selected adapter with a bounded prompt and the minimum required context.
6. The runtime streams output events to the Platform Core.
7. The Core validates and persists the completed assistant message under the same character and conversation.
8. The client displays the stream and final persisted result.
9. Memory candidate detection runs as a separate platform operation under the approved memory policy.

The runtime must not directly query SQLite or select arbitrary character records.

## 4. Buddy Pattern: What to Reuse and What to Exclude

### Reusable technical pattern

- An isolated Linux userland can host command-line agents.
- A wrapper/manager can invoke the CLI in non-interactive mode.
- The platform can capture process output and stream progress/results to the client.
- Agent adapters can have distinct install, update, sign-in, and capability checks.
- Runtime processes can be stopped independently of the Android UI.

### Explicitly excluded from companion v1

- Accessibility-based screen reading or tapping.
- Phone-control tools.
- Notification automation and background routines.
- General shell, filesystem, browser, or device-control tools exposed to the agent.
- Permission to approve its own actions or change platform security settings.

The companion needs conversational generation, not an agent with authority to operate the phone.

## 5. Runtime Candidates

### Candidate A — Alpine Linux through proot

Advantages:
- Similar to the demonstrated Buddy execution pattern.
- Can provide a Linux userland for compatible CLI packages.
- Does not inherently require Android root access.

Unknowns:
- Whether each selected CLI supports Android ARM64 under proot.
- Package and binary availability.
- Authentication browser/deep-link behavior.
- Process supervision and background restrictions.
- Resource usage on the proposed host.

### Candidate B — Termux

Advantages:
- Native Android terminal environment.
- Existing package ecosystem and process tools.
- Can be evaluated without adopting a new paid service.

Unknowns:
- Compatibility of each CLI and dependency.
- Background process reliability and Android battery restrictions.
- Secure separation between platform data and CLI home directories.
- Whether the intended service process can be supervised reliably.

### Candidate C — Native Android process integration

Advantages:
- Tighter lifecycle and app integration.
- Potentially simpler UI-to-runtime streaming.

Unknowns:
- Packaging and maintenance cost.
- Portability of CLI binaries and dependencies.
- Sandboxing and credential storage design.

No candidate is approved yet. Test at least one candidate on the actual proposed host before selecting it.

## 6. Host and Device Assumptions

- POCO F6 is the primary client.
- Mi 9 SE is only a proposed host candidate.
- Do not assume the Mi 9 SE can run the same runtime or local models as newer Snapdragon devices.
- Do not infer compatibility from Buddy's support for another phone.
- POCO F6 local inference is also a separate experiment; CPU/GPU/NPU compatibility and useful generation speed must be measured.
- If the Mi 9 SE cannot provide reliable background execution, the architecture must be reconsidered rather than hiding the limitation.

## 7. Agent Adapter Contract

Each adapter should declare:

- Stable adapter identifier and version.
- Supported operating systems, Android versions, and ABIs.
- Installation and update procedure.
- Official authentication method and terms reference.
- Model selection mechanism.
- Cost class: `local`, `verified_free`, or `unknown`.
- Whether account, subscription, API key, credit card, or network access is required.
- Streaming format and exit/error behavior.
- Cancellation support.
- Whether it can invoke tools, shell commands, or subagents.
- Data sent to the remote provider.
- Known limitations and last verification date.

Adapters with `unknown` cost, unclear terms, or unverified authentication are disabled. Paid routes are not part of this project policy.

## 8. Free-Only Route Policy

A route is eligible only when all conditions are met:

1. It is local and has no paid runtime/model dependency, or its current provider terms verify genuinely free use.
2. It does not require a paid subscription, API billing, credit card, prepaid credits, or billable overage.
3. The intended CLI/client authentication method is officially supported and terms-permitted.
4. Its free quota and reset behavior are known where applicable.
5. The route is compatible with the tested runtime and host.
6. No paid fallback can be selected.

A free quota being exhausted means the route becomes unavailable until reset. Return `NoAvailableFreeModel`; do not switch to a paid route. Do not treat a provider's marketing label “free” as sufficient evidence.

## 9. Credential and Session Isolation

- Keep agent sign-in files and tokens in the runtime's private app-owned storage, protected by the strongest free OS-supported mechanism available.
- Never place raw credentials in SQLite, source code, normal configuration, frontend state, debug output, crash reports, or backups.
- A database `credential_ref` is a pointer only; it is not a credential.
- Do not copy one character's conversation or memory into an agent's global profile or shared CLI home.
- Prefer stateless per-turn prompts. If CLI session reuse is required, use a separate session per character and verify that session identifiers cannot be swapped across characters.
- If secure credential storage cannot be established, disable the affected remote adapter.
- Do not expose the runtime port beyond loopback/trusted local transport until authentication and network security are designed and tested.

## 10. Prompt and Tool Safety

- User messages, retrieved memories, and reference text are data, not privileged instructions.
- The agent receives no general tools by default.
- If an adapter cannot disable shell/filesystem/device tools safely, it is not eligible for companion chat.
- The runtime must not let model output alter character policy, memory approval, credential settings, or routing cost rules.
- Tool permissions, if ever added, require a separate capability allowlist and user-approval design.
- Never let the agent read another character's private context.
- Apply output-size limits, timeouts, cancellation, and process cleanup.

## 11. Streaming and Error Contract

The runtime adapter should emit normalized events such as:

- `run_started`
- `text_delta`
- `status`
- `run_completed`
- `run_failed`
- `run_cancelled`

The exact transport is implementation-dependent. Events must include a run identifier and validated character/conversation scope. The server must reject events for unknown or mismatched runs.

A failed or interrupted run must not be persisted as a completed assistant response. Partial output may be retained only with an explicit incomplete status.

## 12. Compatibility Test Gate

Before approving a host/runtime/adapter combination, record:

- Device model, Android version, ABI, and available storage.
- Runtime installation success and reproducibility.
- CLI installation and version.
- Authentication flow and official terms.
- Free-cost verification and quota behavior.
- One-turn response test.
- Streaming and cancellation test.
- Background survival and restart recovery.
- CPU/RAM/thermal/battery observations.
- Credential storage and backup exclusion.
- Character isolation and prompt-injection tests.
- Confirmation that no unwanted tools or paid fallback are available.

## 13. Current Decision

**Selected:** No runtime, host, agent CLI, model, or authentication route.

**Candidates for testing:** proot-based Linux and Termux on the Mi 9 SE; local inference on existing devices as a separate test.

**Next step:** complete the compatibility and cost-verification matrix before backend implementation.
