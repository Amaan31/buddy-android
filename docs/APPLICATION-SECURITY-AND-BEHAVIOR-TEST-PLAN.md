# APPLICATION SECURITY & BEHAVIOR TEST PLAN — UPDATE

This addendum supersedes the previous paid-BYOK test assumptions. The project requirement is 100% free AI usage.

## 1. Free-only route enforcement

Every model/agent candidate must be classified as `local`, `verified_free`, or `unknown`.

- `local` is eligible only after license and hardware/runtime compatibility checks.
- `verified_free` is eligible only when current official terms confirm the intended use requires no payment, subscription, credit card, API billing, or billable overage.
- `unknown` is always ineligible.
- Consumer subscription access must not be assumed to authorize third-party CLI/API use.
- A free quota exhaustion must make that route unavailable until reset.
- No paid BYOK, paid API, prepaid credit, or billable fallback is permitted.
- If no eligible route remains, the system returns `NoAvailableFreeModel`.

### Route test cases

| ID | Scenario | Expected result |
|---|---|---|
| MP-01 | Enabled character-specific policy exists | Character policy selected |
| MP-02 | Character policy disabled; enabled global policy exists | Global policy selected |
| MP-03 | Character and global policies unavailable | `NoAvailableFreeModel`; no arbitrary model |
| MP-04 | Preferred model belongs to another provider | Rejected |
| MP-05 | Provider/adapter disabled | Candidate skipped |
| MP-06 | Runtime or authentication unavailable | Candidate not usable |
| MP-07 | Preferred unavailable; first verified-free fallback eligible | First fallback selected |
| MP-08 | First fallback unavailable; next eligible | Next valid fallback selected |
| MP-09 | No preferred or fallback candidate eligible | `NoAvailableFreeModel`; no arbitrary model |
| MP-10 | Explicit cross-provider fallback is configured and eligible | Allowed only if verified free |
| MP-11 | Candidate has unknown cost or unclear terms | Skipped |
| MP-12 | Candidate requires paid subscription, API billing, credit card, or prepaid credits | Rejected |
| MP-13 | Free quota is exhausted | Route unavailable until reset; no paid fallback |
| MP-14 | Free/local route fails and no other eligible free route exists | `NoAvailableFreeModel`; no paid request |
| MP-15 | Candidate attempts to use a paid endpoint or billable fallback | Blocked; test fails if request is sent |
| MP-16 | Adapter terms no longer permit the intended integration | Adapter disabled |
| MP-17 | Provider/agent selection attempts to use an unknown-cost route | Rejected |
| MP-18 | App attempts to charge for core functionality or AI use | Prohibited; test fails |
| MP-19 | Fallback JSON has missing IDs, wrong types, unknown fields, or duplicates | Configuration rejected |

Router tests must use mocked adapters and synthetic cost metadata. They must not make real billable calls.

## 2. Provider and agent credential boundary

- Raw API keys, OAuth tokens, and CLI authentication material never enter SQLite, source code, ordinary configuration, frontend state, or logs.
- Credential references point to a separately protected store.
- Agent CLI authentication files remain in private runtime storage.
- Runtime credential storage must be excluded from ordinary exports and backups.
- If the target runtime cannot protect credentials adequately, the affected remote adapter remains disabled.
- No paid BYOK or billable provider integration is permitted under the 100%-free policy.

### Credential test cases

| ID | Scenario | Expected result |
|---|---|---|
| PC-01 | Save provider/agent credential | Stored only in approved secure storage |
| PC-02 | Inspect SQLite database | No raw credential or token |
| PC-03 | Inspect frontend state and API responses | No raw credential or token |
| PC-04 | Trigger application/runtime error | No credential in logs |
| PC-05 | Export database | No CLI sign-in files or raw credentials |
| PC-06 | Secure store unavailable | Remote credential-based adapter disabled |
| PC-07 | Attempt to configure paid BYOK | Rejected by project policy |
| PC-08 | Credential reference points to missing secret | Adapter reports disconnected; no paid fallback |

## 3. 100%-free product and AI safeguards

The platform and its AI routes must remain 100% free. Paid BYOK, paid APIs, prepaid credits, required subscriptions, credit cards, billable overages, and paid fallback are prohibited.

| ID | Scenario | Expected result |
|---|---|---|
| FR-01 | Use core character and memory features without AI connection | Core features remain available |
| FR-02 | Select a verified-free route | Allowed after compatibility and terms checks |
| FR-03 | Select an unknown-cost route | Rejected |
| FR-04 | Select a paid route | Rejected |
| FR-05 | Free quota exhausted | Route unavailable until reset |
| FR-06 | All free routes unavailable | `NoAvailableFreeModel`; no paid fallback |
| FR-07 | Attempt to add paid hosting or required managed service | Architecture review fails |
| FR-08 | Attempt to enable paid BYOK | Rejected |
| FR-09 | Provider changes terms or introduces billing | Route disabled pending re-verification |

## 4. Agent runtime security tests

| ID | Scenario | Expected result |
|---|---|---|
| AR-01 | Agent receives a prompt for Character A | Context contains only Character A data |
| AR-02 | Agent attempts to query SQLite directly | No database access is available |
| AR-03 | Agent session ID from Character A is supplied to Character B | Rejected |
| AR-04 | Prompt injection asks agent to reveal another character's memory | No cross-character data exists in its context |
| AR-05 | Agent output asks to approve or create a memory | Output alone cannot approve memory |
| AR-06 | Agent output asks to change model cost policy | Policy remains unchanged |
| AR-07 | Adapter has shell/device-control tools enabled | Adapter rejected for companion chat |
| AR-08 | User cancels a run | Process is terminated and cancellation is recorded |
| AR-09 | Runtime crashes mid-stream | No completed assistant message is persisted |
| AR-10 | Runtime emits an event for an unknown run ID | Event rejected |
| AR-11 | Runtime emits event with mismatched character/conversation | Event rejected |
| AR-12 | Free route fails | No paid fallback request is issued |

## 5. Release gate

Backend implementation must not begin until:
- SQLite schema acceptance tests pass.
- Application/service-layer character isolation tests pass.
- Memory approval, sharing, revocation, correction, and deletion tests pass.
- Runtime/host/agent compatibility has been demonstrated on the actual target device.
- At least one AI route is verified free and officially permitted for the intended integration.
- No paid route or billable fallback can be selected.
- Agent tools are disabled or restricted to the minimum required for chat generation.
- Runtime credential storage and backup exclusion are tested.
- Streaming, cancellation, crash recovery, and process cleanup are tested.
- Prompt-injection tests confirm that user content and retrieved memories cannot override platform policy.
- No agent can access another character's private data.
- All integration tests pass on the selected runtime.
