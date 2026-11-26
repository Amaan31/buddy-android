# RUNTIME FEASIBILITY TEST — DEVICE PREFLIGHT

**Status:** Test procedure; no runtime or AI route is approved by this document.
**Purpose:** Collect a safe baseline from the proposed host before installing or authenticating any agent CLI.

## Scope

This first test is intentionally non-invasive. It records device/runtime facts only. It does not install packages, contact an AI provider, read credentials, inspect personal files, or change device settings.

Run it first on the proposed Mi 9 SE. Run the same test on the POCO F6 only if considering moving the host role to that device.

## 1. Run the preflight

1. Install Termux from a trusted official distribution source if it is not already installed.
2. Download `tools/runtime-preflight.sh` from this branch.
3. In Termux, navigate to the download location and run:

```sh
sh runtime-preflight.sh
```

4. Copy the generated report into the chat for review. Inspect it before sharing; the script intentionally omits serial numbers, account identifiers, IP addresses, home-directory contents, and credentials.

If the script cannot read a field, it reports `unavailable`. Do not treat that as a device failure.

## 2. What the preflight checks

- Android release and SDK level, when exposed by the environment.
- Device manufacturer/model and CPU ABI.
- Kernel and userspace architecture.
- CPU core count and readable CPU frequency information.
- Total/available memory.
- Available storage on the app data filesystem.
- Battery level, temperature, and charging status, when readable.
- Presence and versions of optional runtime utilities such as Termux, proot, Python, Node.js, Git, curl, and OpenSSL.

The script does not decide compatibility by itself. These facts are inputs to the runtime decision.

## 3. Manual tests after preflight

Do not install or sign into an AI CLI yet. First record:

| Test | Pass condition |
|---|---|
| Runtime install | Termux/proot install succeeds from trusted sources without root |
| Reproducibility | A clean reinstall can repeat the setup from documented steps |
| CLI support | The chosen CLI officially supports the detected OS/ABI and its dependencies run |
| Authentication | The exact sign-in flow is officially permitted for this third-party integration |
| Free-cost proof | Official terms establish no subscription, payment, card, API billing, or billable overage |
| One-turn test | A minimal prompt returns a valid response on the target device |
| Streaming | Output arrives incrementally and remains correctly ordered |
| Cancellation | A running process stops promptly when cancelled |
| Background survival | Screen-off/background operation behaves within the product's intended use |
| Recovery | A killed process can be restarted without corrupting canonical platform data |
| Resource use | CPU, memory, temperature, and battery impact are acceptable for sustained use |
| Credential boundary | Authentication material stays in private app/runtime storage and is excluded from logs/backups |
| Tool restriction | The agent cannot access shell, filesystem, phone-control, or unrelated tools during companion chat |
| Character isolation | A run receives only one character's bounded context |

## 4. Decision rules

- A missing or unsupported ABI/runtime dependency rejects that runtime/CLI combination.
- An unofficial or prohibited authentication route rejects that adapter, even if it happens to work technically.
- Unknown cost or unclear terms means `unknown` and is ineligible.
- A free quota expiring or being exhausted makes the route unavailable; it does not permit paid fallback.
- If credentials cannot be protected, disable remote authentication for that adapter.
- Do not begin backend implementation until at least one host/runtime/adapter combination passes the required compatibility, cost, terms, and security checks.

## 5. Result record

Record the following in a test report (do not include tokens, passwords, account email, or private auth files):

- Test date:
- Device:
- Android version / SDK:
- ABI:
- Runtime candidate:
- CLI and version:
- Official authentication method and terms URL:
- Cost classification: `local` / `verified_free` / `unknown`
- Quota and reset behavior:
- One-turn / streaming / cancellation:
- Background survival / recovery:
- CPU / memory / temperature / battery observations:
- Credential storage and backup exclusion:
- Tool restriction:
- Character isolation:
- Final result: `PASS` / `FAIL` / `BLOCKED`
- Evidence and unresolved issues:

Never paste secrets into the report.
