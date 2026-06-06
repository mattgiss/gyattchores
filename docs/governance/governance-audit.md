# GitHub Governance Audit — GyattChores

| | |
|---|---|
| **Document ID** | GOV-AUD-001 |
| **Service** | GyattChores (Family Chore Tracker) |
| **Repository** | `mattgiss/gyattchores` |
| **Audit date** | 2026-06-06 |
| **Auditor** | Platform engineering (automated assessment) |
| **Framework** | ITIL 4 + GitHub Well-Architected governance baseline |
| **Classification** | Internal |
| **Next review** | 2026-09-06 (quarterly) |

---

## 1. Purpose & scope

This audit assesses how the GyattChores GitHub repository is **governed** — how
changes are controlled, how production is protected, how incidents are detected,
and how accountability is recorded. It establishes a baseline against which the
Service Management System (SMS) in this directory can drive **continual
improvement**.

**In scope:** repository configuration, branch & change controls, access model,
CI/CD and deployment path, monitoring, security posture, and supporting
governance artifacts.

**Out of scope:** application source-code quality, UX, and feature correctness
(tracked separately under the product backlog).

---

## 2. Executive summary

GyattChores is a low-complexity, single-maintainer static web application
deployed continuously to GitHub Pages from `main`. The engineering hygiene of
individual changes is **good** (clear pull requests, recorded verification
steps, an explicit security model). However, the **control environment is
immature**: production (`main`) is unprotected, every pull request is
self-authored and self-merged, and there are no automated quality gates.

The single most valuable control recently added is **Monitoring & Event
Management** (the Discord notification workflow), which gives the service its
first real-time feedback loop.

**Overall governance maturity: Level 2 of 5 — "Repeatable but informal."**
Practices happen consistently because one person performs them, not because the
system enforces them. The dominant risk is **key-person dependency (bus
factor = 1)** combined with **no enforced change control on production**.

| Domain | RAG | Maturity (1–5) |
|---|:---:|:---:|
| Change Enablement | 🔴 | 1 |
| Release & Deployment | 🟠 | 2 |
| Access & Identity | 🔴 | 1 |
| Monitoring & Event Mgmt | 🟢 | 3 |
| Incident & Problem Mgmt | 🟠 | 2 |
| Information Security | 🟠 | 2 |
| Configuration & Docs | 🟢 | 3 |

---

## 3. Evidence base

Findings are derived from the live repository state on the audit date:

- **Access:** 1 collaborator — `mattgiss` (role: `admin`). No teams, no other
  contributors.
- **Branches:** 12 total; `protected: false` on **all**, including `main`.
- **Pull requests:** 10 lifetime. 100% authored by the owner. Merged PRs were
  open for as little as ~1–2 minutes (e.g. PR #10 opened 00:52Z, merged
  00:53Z), indicating no independent review step.
- **Workflows:** 1 — `.github/workflows/discord-notify.yml` (event
  notifications to Discord). No build, test, or lint workflow.
- **Secrets:** `DISCORD_WEBHOOK` configured in Actions. Supabase **anon** key
  is embedded in the client by design (documented in `SECURITY.md`).
- **Governance artifacts present:** `README.md`, `SECURITY.md`.
- **Governance artifacts absent (pre-audit):** branch protection, `CODEOWNERS`,
  `CONTRIBUTING.md`, PR/issue templates, `LICENSE` file (MIT declared in README
  but unfiled), `dependabot.yml`, CI pipeline, `CHANGELOG`.
- **Deployment:** GitHub Pages serves `main`. A push to `main` is, in effect, a
  **production release** with no staging or approval gate.

---

## 4. Findings register

Severity reflects likelihood × impact for a private family service with
non-sensitive data. Each finding maps to a corrective action (CA-xx) in the
[Continual Improvement register](continual-improvement.md).

| ID | Finding | Severity | Corrective action |
|---|---|:---:|---|
| **GAP-01** | `main` (production) has **no branch protection** — direct pushes, force-pushes, and deletion are all permitted. | 🔴 High | CA-01 |
| **GAP-02** | **Bus factor = 1.** A single admin owns all access, knowledge, and merge authority. No break-glass or recovery path is documented. | 🔴 High | CA-02 |
| **GAP-03** | **No independent review.** All 10 PRs were self-merged, frequently within ~2 minutes — change review is a formality, not a control. | 🟠 Medium | CA-01, CA-03 |
| **GAP-04** | **No automated quality gate.** Nothing validates `index.html` (HTML/JSX/JSON parse, link/asset checks) before it reaches production. | 🟠 Medium | CA-04 |
| **GAP-05** | **Production = direct push to `main`** with no staging environment or deployment approval. | 🟠 Medium | CA-01, CA-05 |
| **GAP-06** | **Secret-scanning & push protection** state is unmanaged/undocumented; client carries a long-lived Supabase anon key and a Discord webhook URL was once pasted into chat. | 🟠 Medium | CA-06 |
| **GAP-07** | **No dependency governance.** React/Babel/Supabase load from CDNs with no version pinning policy or update cadence (Dependabot N/A for CDN, so a manual control is required). | 🟢 Low | CA-07 |
| **GAP-08** | **`LICENSE` file missing** though README asserts MIT — licensing intent is unenforceable as-is. | 🟢 Low | CA-08 |
| **GAP-09** | **No contribution/change templates** (`CODEOWNERS`, PR template, issue templates) to make process self-service. | 🟢 Low | CA-09 |
| **GAP-10** | **Branch hygiene:** 12 branches persist, several already merged — stale refs obscure the active line of development. | 🟢 Low | CA-10 |
| **GAP-11** | **No documented operational runbooks** for change, incident, or release management (addressed by this SMS). | 🟠 Medium | CA-11 |

---

## 5. Strengths (controls to preserve)

These are working and should be **protected from regression**:

1. **Clear change records.** PR descriptions consistently state *what*, *why*,
   *how*, and include **verification tables** — a strong change-evidence habit.
2. **Explicit security model.** `SECURITY.md` honestly documents the threat
   model and that the admin PIN is *not* a security boundary.
3. **Resilient architecture.** Local-first storage means a backend outage
   cannot block the core "log a chore" function — availability risk is low by
   design.
4. **Monitoring now exists.** The Discord workflow provides event-level
   visibility of pushes, PRs, reviews, issues, and branch changes.

---

## 6. Maturity assessment (ITIL / CMMI scale)

```
Level 5  Optimising      ┊
Level 4  Measured        ┊
Level 3  Defined         ┊■■■  Monitoring · Config/Docs
Level 2  Repeatable      ┊■■■■■  Release · Incident · Security
Level 1  Initial         ┊■■  Change · Access
         ───────────────────────────────────────────
```

**Target state (12 months): Level 3 "Defined"** across all domains — controls
exist *in the system*, not just *in the owner's head*. The corrective-action
roadmap in §7 is sequenced to reach it.

---

## 7. Prioritised roadmap

The full, trackable register lives in
[`continual-improvement.md`](continual-improvement.md). Summary sequence:

| Wave | Goal | Corrective actions | Outcome |
|---|---|---|---|
| **Now (P1)** | Protect production & remove single points of failure | CA-01 (branch protection), CA-02 (break-glass + recovery), CA-06 (secret hygiene) | `main` cannot be changed without a PR; recovery is documented; secrets are governed. |
| **Next (P2)** | Make change control real | CA-04 (CI quality gate), CA-03 (review policy), CA-05 (deployment record) | Every change is validated and recorded before production. |
| **Soon (P3)** | Make governance self-service | CA-09 (templates/CODEOWNERS), CA-08 (LICENSE), CA-11 (runbooks), CA-07 (dependency cadence), CA-10 (branch cleanup) | The repository teaches contributors how to comply. |

---

## 8. Attestation

This audit reflects the repository state on **2026-06-06**. It should be
re-run quarterly, or after any material change to access, deployment, or the
control environment, and the results reconciled against the CSI register.

> Re-audit checklist: re-pull access list, branch-protection state, PR
> review/merge pattern, workflow inventory, and secret-scanning status; update
> §3 evidence and the §4 RAG ratings; close or re-baseline corrective actions.
