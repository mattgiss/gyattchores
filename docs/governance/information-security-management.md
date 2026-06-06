# Information Security Management

| | |
|---|---|
| **Document ID** | GOV-SEC-001 |
| **Practice** | Information Security Management (ITIL 4) |
| **Service** | GyattChores |
| **Owner** | Repository owner (`mattgiss`) |
| **Status** | Defined |
| **Related** | [`SECURITY.md`](../../SECURITY.md) (threat model & disclosure) |
| **Review cadence** | Quarterly |

---

## 1. Purpose & relationship to SECURITY.md

This document governs the **security of the repository and delivery pipeline**
(supply chain, secrets, access). It complements the existing
[`SECURITY.md`](../../SECURITY.md), which governs the **application's** threat
model (local-first data, the non-boundary admin PIN, the anon-key/RLS posture).

> Read `SECURITY.md` for *what the app protects*; read this for *how the
> repository and pipeline are protected*.

---

## 2. Security objectives (CIA, scaled to context)

GyattChores is a private family app with **non-sensitive data and no user
accounts**. Objectives are scaled accordingly:

| Objective | Stance |
|---|---|
| **Confidentiality** | Low for app data (chore logs are non-sensitive, local-first). **High for credentials** — webhook URLs, anon keys, and any future service-role keys must never leak. |
| **Integrity** | **Protect `main`** so only reviewed changes reach production (CA-01). |
| **Availability** | High by design — local-first storage means a backend outage cannot stop core use. |

---

## 3. Identity & access management

| Control | Current state | Action |
|---|---|---|
| Collaborators | 1 admin (`mattgiss`). | Maintain least privilege; add collaborators as **write**, reserve **admin** for the owner. |
| MFA | Should be enforced on the owner's GitHub account. | Verify 2FA enabled. |
| Break-glass / recovery | **Not documented (GAP-02).** | CA-02 — document account-recovery and a secondary owner/recovery contact. |
| Branch protection | None (GAP-01). | CA-01 — protect `main`. |

**Principle of least privilege:** grant the minimum access required, for the
minimum time. The single-admin model concentrates risk — CA-02 mitigates the
key-person dependency.

---

## 4. Secrets management

| Secret / credential | Where | Policy |
|---|---|---|
| `DISCORD_WEBHOOK` | GitHub Actions secret | Never echo in logs; rotate if exposed (KE-003, CA-06). Treated as a credential. |
| Supabase **anon** key | Embedded in `index.html` **by design** | Public-safe key; access bounded by row-level security. **Never** commit the `service_role` key. Documented in `SECURITY.md`. |
| Admin PIN | `ADMIN_CODE` in `index.html` | **Not a security boundary** (client-visible). A child-lock only. |

### 4.1 Rules

1. **No real secrets in the repository.** The anon key and PIN are the *only*
   client-side values, and both are documented as non-confidential.
2. **Secrets live in GitHub Actions secrets**, referenced via `${{ secrets.* }}`.
3. **Fail closed on exposure.** A leaked credential is rotated immediately
   (webhook procedure in the [monitoring doc](monitoring-and-event-management.md#52-rotating-the-webhook-security-hygiene)).
4. **Enable GitHub secret scanning + push protection** (CA-06) so accidental
   commits of tokens are blocked at push time.

---

## 5. Supply-chain security

The web app loads dependencies from CDNs at runtime (React, Babel, optionally
Supabase) — there is no build step or lockfile.

| Risk | Control |
|---|---|
| A CDN dependency changes behaviour or is compromised. | Pin to explicit major versions; record the dependency inventory in the [configuration doc](README.md#5-service-configuration-cmdb-lite); review on the quarterly cadence (CA-07). |
| A GitHub Action is compromised. | Prefer first-party `actions/*`; pin third-party actions to a commit SHA, not a moving tag. (The current workflow uses only `curl`/`jq` on the runner — minimal action surface.) |
| Native app dependencies | Track in the `GyattChoresApp` target when the Xcode project is committed. |

---

## 6. Data protection & privacy

- Chore data (player name, chore, points, status, timestamp) is **non-sensitive**
  and stored **local-first** on each device.
- Optional Supabase sync stores the same non-sensitive logs under permissive
  RLS — **no accounts, email, analytics, or third-party tracking** (per
  `SECURITY.md`).
- **Children's data:** although minimal and non-identifying, treat display
  names with care. If the service ever adds real accounts or identifying data,
  COPPA-style consent and retention controls become mandatory — see
  `SECURITY.md` §"If you want stronger guarantees."

---

## 7. Vulnerability & disclosure

- **Reporting:** per `SECURITY.md`, open a repository issue (label `security`).
  There is no formal disclosure program for this family project.
- **Triage:** security issues are prioritised as **problems** (see
  [Incident & Problem Management](incident-and-problem-management.md)) and fixed
  as Normal or Emergency changes by severity.

---

## 8. Security control checklist (quarterly)

```
- [ ] Owner GitHub account has 2FA/MFA enabled
- [ ] main branch protection is ON and enforced
- [ ] Secret scanning + push protection enabled
- [ ] No secrets present in repo history or client beyond the documented anon key/PIN
- [ ] DISCORD_WEBHOOK rotated if it was ever exposed
- [ ] CDN dependency versions reviewed; no unexpected drift
- [ ] Break-glass / account recovery contact still valid
- [ ] SECURITY.md still accurately reflects the app's threat model
```

Completing this checklist each quarter satisfies the security half of the
[Continual Improvement](continual-improvement.md) review.
