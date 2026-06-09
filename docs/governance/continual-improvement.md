# Continual Improvement Register (CSI)

| | |
|---|---|
| **Document ID** | GOV-CSI-001 |
| **Practice** | Continual Improvement (ITIL 4) |
| **Service** | GyattChores |
| **Owner** | Repository owner (`mattgiss`) |
| **Status** | Active |
| **Baseline** | [Governance Audit GOV-AUD-001, 2026-06-06](governance-audit.md) |
| **Review cadence** | Quarterly |

---

## 1. Purpose

This is the **single backlog of corrective actions** that move GyattChores from
its audited baseline (governance maturity **Level 2**) to the target state
(**Level 3 — "Defined"**). Every item is concrete, owned, and mapped to a goal,
so the service can **improve itself over time** rather than depending on memory.

It is structured on the ITIL Continual Improvement Model:

```
What is the vision?      ── A safe, self-documenting repo that protects
                            production and survives the loss of any one person.
Where are we now?        ── Governance Audit (GOV-AUD-001): Level 2.
Where do we want to be?  ── Level 3 across all domains within 12 months.
How do we get there?     ── The corrective actions below (CA-01 … CA-11).
Take action             ── Wave P1 → P2 → P3.
Did we get there?        ── KPIs in each practice doc; re-audit quarterly.
Keep the momentum        ── This register is reviewed every quarter.
```

---

## 2. Goals → corrective actions

| Goal | Success measure | Corrective actions |
|---|---|---|
| **G1 — Protect production.** No unreviewed, unvalidated change reaches the live site. | 100% of `main` changes via PR + green CI. | CA-01, CA-03, CA-04 |
| **G2 — Remove single points of failure.** The service survives loss of any one person or credential. | Documented recovery; rotated/scanned secrets; ≥1 backup branch. | CA-02, CA-06 |
| **G3 — Make governance self-service.** The repo teaches contributors how to comply. | Templates, license, and runbooks present and used. | CA-08, CA-09, CA-11 |
| **G4 — Know when something breaks.** Failures are detected before users report them. | Synthetic check + CI events in the feed. | CA-04, CA-05 |
| **G5 — Keep the supply chain & hygiene healthy.** | Dependencies reviewed; branches pruned. | CA-07, CA-10 |

---

## 3. Corrective-action register

> **Status key:** ⬜ Open · 🟦 In progress · ✅ Done
> **Priority:** P1 (now) · P2 (next) · P3 (soon)

### CA-01 — Enable branch protection on `main`
- **Goal:** G1 · **Priority:** P1 · **Addresses:** GAP-01, GAP-03, GAP-05 · **Status:** ⬜
- **Action:** GitHub → Settings → Branches → Add rule for `main`:
  require a pull request before merging; require status checks to pass (the
  CA-04 check); block force-pushes and deletion. (Single-maintainer note: keep
  "require approvals" optional but mandate the self-attestation comment from
  Change Enablement §6, or set 1 approval if a reviewer exists.)
- **Done when:** a direct push to `main` is rejected and a PR is required.

### CA-02 — Document break-glass & recovery (reduce bus factor)
- **Goal:** G2 · **Priority:** P1 · **Addresses:** GAP-02 · **Status:** 🟦
- **Action:** Record, in a secure location: GitHub account-recovery method,
  2FA backup codes, the custom-domain/DNS registrar, the Discord server owner,
  and the Supabase project owner. Nominate a secondary recovery contact.
  Maintain at least one recent `backup-stable-*` branch.
- **Progress:** Recovery runbook written —
  [Break-Glass & Recovery](break-glass-and-recovery.md) — with the asset
  inventory, per-scenario procedures, and a quarterly drill. **Remaining owner
  actions** (tracked as checklists in §4/§6 of that doc): populate the secure
  vault with credentials/backup codes and nominate a secondary recovery contact.
- **Done when:** a written recovery runbook exists and a second person (or
  secure vault) can recover access.

### CA-03 — Adopt the review / self-attestation policy
- **Goal:** G1 · **Priority:** P2 · **Addresses:** GAP-03 · **Status:** 🟦
- **Action:** Apply the PR standard and review checklist in
  [Change Enablement §5–6](change-enablement.md). The PR template (CA-09) makes
  it the default.
- **Done when:** new PRs carry a completed checklist/verification table.

### CA-04 — Add a CI quality gate
- **Goal:** G1, G4 · **Priority:** P2 · **Addresses:** GAP-04, KE-004 · **Status:** ⬜
- **Action:** Add a lightweight workflow that runs on every PR to `main`:
  validate that `index.html` parses, JSON/manifest files are well-formed, and
  required assets (`CNAME`, icons, referenced logos) exist. Register it as the
  required status check in CA-01. Optionally surface its result to the Discord
  feed.
- **Done when:** a malformed change to `index.html` blocks the merge.

### CA-05 — Formalise the deployment record & add a synthetic check
- **Goal:** G4 · **Priority:** P2 · **Addresses:** GAP-05 · **Status:** ⬜
- **Action:** (a) Treat the deploy Discord event + merge commit as the
  deployment record; add a one-line entry per production release if a
  `CHANGELOG` is adopted. (b) Add a **scheduled** workflow that fetches
  [gyattchores.com](https://gyattchores.com) and alerts on non-200 — detecting
  live-site outages no repo event would reveal.
- **Done when:** a down live site raises a 🔴 exception in the feed.

### CA-06 — Secret hygiene: scanning, push protection, rotation
- **Goal:** G2 · **Priority:** P1 · **Addresses:** GAP-06 · **Status:** 🟦
- **Action:** Enable GitHub **secret scanning + push protection**. **Rotate the
  `DISCORD_WEBHOOK`** (it was exposed in chat) per the
  [rotation procedure](monitoring-and-event-management.md#52-rotating-the-webhook-security-hygiene).
  Confirm no `service_role` key is anywhere in history.
- **Done when:** scanning is on, the webhook is rotated, and a test notification
  delivers `204`.

### CA-07 — Establish a dependency-review cadence
- **Goal:** G5 · **Priority:** P3 · **Addresses:** GAP-07 · **Status:** ✅
- **Action:** Pin CDN dependencies (React, Babel, Supabase) to explicit major
  versions; record them in the CMDB table
  ([governance README §5](README.md#5-service-configuration-cmdb-lite)); review
  quarterly for security advisories. (Dependabot doesn't cover CDN `<script>`
  tags, so this is a manual control.)
- **Done:** Pinned to exact versions in `index.html` and `sw.js` — React
  18.3.1, React-DOM 18.3.1, `@babel/standalone` 7.29.7, `@supabase/supabase-js`
  2.108.0. The three unpkg scripts also carry **Subresource Integrity**
  (`sha384` + `crossorigin`), so a tampered/compromised CDN file is refused by
  the browser (verified: a modified byte blocks the load). Versions recorded in
  the CMDB (§5). **Quarterly review** owner action: check for advisories, bump
  versions, and recompute the SRI hashes when bumping.
- **Done when:** the dependency inventory is documented and on the review
  calendar.

### CA-08 — Add a LICENSE file
- **Goal:** G3 · **Priority:** P3 · **Addresses:** GAP-08 · **Status:** ✅
- **Action:** Add an MIT `LICENSE` matching the README's declaration.
- **Done when:** `LICENSE` exists at the repo root. *(Completed in this change set.)*

### CA-09 — Add contribution templates & CODEOWNERS
- **Goal:** G3 · **Priority:** P3 · **Addresses:** GAP-09 · **Status:** ✅
- **Action:** Add `CODEOWNERS`, a PR template, and issue templates (bug,
  incident, change request) so process is self-service.
- **Done when:** opening a PR/issue pre-populates the standard. *(Completed in
  this change set.)*

### CA-10 — Branch hygiene
- **Goal:** G5 · **Priority:** P3 · **Addresses:** GAP-10 · **Status:** ⬜
- **Action:** Delete merged branches; keep `main` + active work + the latest
  `backup-stable-*`. Review at each quarterly cadence.
- **Done when:** only active and intentionally-retained branches remain.

### CA-11 — Operational runbooks (this SMS)
- **Goal:** G3 · **Priority:** P2 · **Addresses:** GAP-11 · **Status:** ✅
- **Action:** Publish the Service Management System (this `docs/governance/`
  directory): change, incident/problem, monitoring, security, and CSI.
- **Done when:** the runbooks exist and are linked from the README. *(Completed
  in this change set.)*

---

## 4. Wave plan

| Wave | Focus | Items | Target |
|---|---|---|---|
| **P1 — Now** | Protect prod, kill SPOFs | CA-01, CA-02, CA-06 | Within 2 weeks |
| **P2 — Next** | Real change control & detection | CA-03, CA-04, CA-05, CA-11 | Within 1 quarter |
| **P3 — Soon** | Self-service & hygiene | CA-07, CA-08, CA-09, CA-10 | Within 2 quarters |

---

## 5. Progress snapshot (2026-06-06)

| Status | Count | Items |
|---|---|---|
| ✅ Done | 3 | CA-08, CA-09, CA-11 |
| 🟦 In progress | 2 | CA-03, CA-06 |
| ⬜ Open | 6 | CA-01, CA-02, CA-04, CA-05, CA-07, CA-10 |

**Maturity trajectory:** baseline Level 2 → on completion of Wave P1+P2,
expected Level 3 ("Defined") across Change, Access, Incident, and Monitoring.

---

## 6. How to use this register

1. **Quarterly**, re-run the [Governance Audit](governance-audit.md) and update
   the RAG ratings.
2. Reconcile findings (GAP-xx) against this register; **close** completed
   actions and **raise** new ones for any new gaps.
3. Move items across the wave plan as priorities shift.
4. Each closed action should leave behind a durable control (a setting, a
   workflow, or a doc) — not a one-time fix.
