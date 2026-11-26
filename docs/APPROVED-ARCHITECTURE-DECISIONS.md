# APPROVED ARCHITECTURE DECISIONS — UPDATE

**Purpose:** This update supersedes conflicting cost and runtime statements in the existing `APPROVED-ARCHITECTURE-DECISIONS.md`. Keep the seven existing application decisions unless this update explicitly changes their interpretation.

## 1. Product and cost model — 100% free

The entire platform and its AI routes must remain 100% free. This is stricter than making the app free while permitting paid inference.

- No paid API usage, paid BYOK, prepaid credits, required subscription, credit card, or billable overage.
- No required paid hosting, managed database, storage, authentication, tunnel, monitoring, analytics, or automation service.
- Prefer free/open-source software and self-hosted/local components on existing hardware.
- Remote AI routes are eligible only when current official terms confirm no payment, subscription, credit card, API billing, or billable overage and permit the intended integration.
- A consumer subscription is not assumed to authorize third-party CLI/API access.
- Local inference is eligible only after license and hardware/runtime compatibility are verified.
- Unknown or unclear cost/terms make a candidate ineligible.
- Exhausting a free quota means the route is unavailable until reset. It does not authorize paid fallback.
- If no eligible route remains, return `NoAvailableFreeModel`.

“100% free” describes software, services, and AI usage. It does not mean electricity, internet bandwidth, device storage, or hardware operation have literally zero real-world cost.

## 2. Credential policy

- Never store raw API keys, OAuth tokens, or CLI authentication material in SQLite, ordinary configuration, source code, logs, or frontend state.
- `provider_connections.credential_ref` is only a reference to a separate secure storage mechanism.
- Prefer OS-provided secure storage where available without a paid service.
- Agent CLI sign-in state must remain in private app-owned runtime storage and be excluded from ordinary database exports and backups unless an encrypted-backup design is explicitly reviewed.
- If the selected runtime cannot protect credentials adequately, the affected remote adapter remains disabled.
- Paid BYOK and billable provider integrations are not allowed under the current project policy.

## 3. Model/agent routing policy

A candidate is eligible only when:
1. Its adapter is enabled and compatible with the tested runtime.
2. Authentication is officially supported and permitted for the intended integration.
3. Cost is explicitly `local` or `verified_free`.
4. It requires no paid subscription, API billing, credit card, prepaid credits, or billable overage.
5. Free quota/reset behavior is known where applicable.
6. Any fallback is explicitly configured and also meets all free-only requirements.

`unknown` cost or unclear terms are always ineligible. If all eligible routes fail or are exhausted, return `NoAvailableFreeModel`. Do not make a paid request to preserve availability.

## 4. Runtime architecture decision

The agent CLI is an execution adapter, not the owner of character identity, canonical conversation history, memories, or relationship state.

- SQLite and the Platform Core remain the source of truth.
- The runtime receives only the selected character's assembled context.
- Agent session state is optional and disposable.
- The runtime has no general phone-control, accessibility, shell, filesystem, or browser tools by default.
- Proot-based Alpine Linux and Termux are candidates, not selected technologies.
- Mi 9 SE remains a proposed host only until actual compatibility, background stability, resource use, and credential protection are tested.
- POCO F6 remains the primary client.
- Buddy's phone-control/accessibility feature set is outside companion v1 scope.

See `docs/AI-RUNTIME-ARCHITECTURE.md` for the full design and test gate.

## 5. Implementation gate

No backend implementation may begin until:
- The runtime/host/agent combination passes compatibility tests.
- At least one genuinely free and officially permitted AI route is verified.
- No paid route or billable fallback can be selected.
- Credential isolation, character isolation, prompt-injection handling, streaming, cancellation, and process cleanup are tested.
- No paid dependency is required for core functionality.
