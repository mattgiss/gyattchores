# Incident & Problem Management

| | |
|---|---|
| **Document ID** | GOV-INC-001 |
| **Practices** | Incident Management; Problem Management (ITIL 4) |
| **Service** | GyattChores |
| **Owner** | Repository owner (`mattgiss`) |
| **Status** | Defined |
| **Review cadence** | Quarterly, and after every Priority-1 incident |

---

## 1. Purpose

- **Incident Management:** restore normal service operation as quickly as
  possible after an unplanned interruption, minimising disruption to the family
  using the app.
- **Problem Management:** reduce the *likelihood and impact* of incidents by
  finding and removing their underlying causes, and by maintaining a **Known
  Error Database (KEDB)** so recurring issues are resolved fast.

An **incident** is an unplanned interruption or quality reduction (e.g. "chores
won't save"). A **problem** is the underlying cause of one or more incidents
(e.g. "the backend project was deleted").

---

## 2. Severity & priority matrix

| Priority | Definition | Example | Target response | Target restore |
|:---:|---|---|---|---|
| **P1** | Core function unusable for all users. | Chores cannot be logged on the live site. | Immediate | < 4 hours |
| **P2** | Major feature degraded; workaround exists. | Cross-device sync down, but local logging works. | Same day | < 2 days |
| **P3** | Minor/cosmetic; limited impact. | A stat pill shows the wrong colour. | Next change cycle | Next release |

> The local-first architecture means most backend failures are **P2, not P1** —
> logging still works on-device. This is a deliberate availability control.

---

## 3. Incident lifecycle

```
 Detect ──► Log ──► Categorise/Prioritise ──► Diagnose ──► Resolve/Recover ──► Close ──► (Review)
   │                                                                                       │
 Discord event,                                                              feeds Problem Management
 smoke test, or                                                              if recurring or P1
 user report
```

### 3.1 Detect

Primary detection channels:

- **Monitoring & Event Management** — the Discord notification feed
  (see [monitoring doc](monitoring-and-event-management.md)). A failed
  deploy/workflow surfaces here first.
- **Post-deployment smoke test** (Change Enablement §7.1).
- **Direct report** from a family member ("it's not working").

### 3.2 Log

Open a GitHub Issue using the **Incident** template
([`.github/ISSUE_TEMPLATE/incident.md`](../../.github/ISSUE_TEMPLATE/incident.md)).
The issue *is* the incident record. Capture: what's broken, when it started,
who's affected, priority, and the detection source.

### 3.3 Diagnose & recover

Work the **triage runbook** (§4). Prefer the fastest safe path to restore
service — an **Emergency change** (Change Enablement §3.1) is authorised to
merge first and document after when service is down.

### 3.4 Close

Service is confirmed restored via the smoke test. Record the resolution and
root-cause hypothesis on the issue. If the incident was **P1 or recurring**,
raise a linked **Problem** record.

---

## 4. Triage runbook — "the app isn't working"

| Symptom | Likely cause | First action |
|---|---|---|
| Site won't load at all | Pages build failed, or DNS/`CNAME` issue. | Check the latest Actions run + GitHub Pages status; verify `CNAME`. |
| Loads, but chores won't save *with an error* | Regression in `index.html` write path. | Roll back the last merge (Change Enablement §8); reproduce locally. |
| Loads, "Offline — saved on this device" hint shows | Optional backend (Supabase) unreachable. | **Not P1** — local logging works. See **KE-001**. |
| Points don't appear after approval | Approval/status logic regression. | Check recent changes to `setStatus`/points calc; smoke test locally. |
| Discord notifications stopped | Workflow failure or webhook revoked. | See **KE-002** / **KE-003**. |
| Deploy didn't go live | Pages cache or workflow failure. | Re-run the workflow; hard-refresh; confirm merge landed on `main`. |

---

## 5. Problem Management

### 5.1 Triggers for raising a Problem

- Any **P1** incident.
- The **same incident type recurring** (≥ 2 occurrences).
- A **proactive** risk spotted during change or audit (e.g. "the anon key never
  rotates").

### 5.2 Workflow

1. **Record** the problem (GitHub Issue, label `problem`).
2. **Investigate** root cause — use the 5-Whys; capture evidence (logs, DNS,
   diffs) as PRs and incidents already do well.
3. **Known Error** — once the cause is understood but not yet permanently
   fixed, add it to the **KEDB** (§6) with a workaround.
4. **Resolve** — implement the permanent fix as a Normal change; link the PR.
5. **Review** — confirm the incident class stops recurring; close the problem.

---

## 6. Known Error Database (KEDB)

Documented causes with proven workarounds, so future incidents resolve in
minutes. Drawn from the service's real history.

### KE-001 — Optional backend (Supabase) unavailable
- **Symptom:** "Offline — saved on this device" hint; no cross-device sync.
- **Root cause:** the free-tier Supabase project is paused, deleted, or its
  table (`simple_logs`) is missing. *Historically the project hostname returned
  `NXDOMAIN` after deletion (PR #8), causing the original "Could not save —
  reconnecting" outage before the local-first redesign.*
- **Impact:** **P2.** Local logging is unaffected by design.
- **Workaround:** none needed for core use. To restore sync: confirm the project
  is running and run `simple-logs-schema.sql` in its SQL editor; verify
  `SUPABASE_URL`/`SUPABASE_ANON_KEY` in `index.html`.
- **Permanent fix:** local-first architecture already removes this as a P1
  class (the cloud is best-effort only).

### KE-002 — Discord notification rejected (HTTP 400, forum channel)
- **Symptom:** notification workflow fails; Discord returns
  `{"message": "Webhooks posted to forum channels must have a thread_name or thread_id", "code": 220001}`.
- **Root cause:** the target Discord channel is a **Forum** channel, which
  requires a `thread_name` (or `thread_id`) at the top level of every webhook
  payload.
- **Impact:** **P3** (observability gap, not a service outage).
- **Workaround / fix:** every payload in `discord-notify.yml` includes
  `thread_name`. Do not remove it. If switching to a text channel, `thread_name`
  becomes optional but harmless.

### KE-003 — Discord notifications silently absent
- **Symptom:** no notifications, but workflow shows success.
- **Root cause:** earlier the workflow used `curl -s` (silent), which **hid**
  non-2xx responses; or the `DISCORD_WEBHOOK` secret is unset/revoked.
- **Impact:** **P3.**
- **Workaround / fix:** the workflow now **captures the HTTP status** and fails
  loudly on anything other than `204`. Check the Actions log for
  `Discord HTTP: <code>`. If the webhook was revoked (e.g. rotated for hygiene),
  recreate it and update the `DISCORD_WEBHOOK` secret.

### KE-004 — Production regression reached live with no gate
- **Symptom:** a broken change is live because nothing validated it pre-merge.
- **Root cause:** no CI quality gate (GAP-04) and unprotected `main` (GAP-01).
- **Impact:** up to **P1**.
- **Workaround:** roll back per Change Enablement §8.
- **Permanent fix:** CA-01 (branch protection) + CA-04 (CI gate) in the
  [CSI register](continual-improvement.md).

---

## 7. Post-incident review (P1 only)

Within 48 hours of resolving a P1, complete a blameless review on the incident
issue:

1. **Timeline** — detection → restore, with timestamps.
2. **Impact** — who/what was affected and for how long.
3. **Root cause** — the underlying problem (link the Problem record).
4. **What worked / what didn't** — honestly.
5. **Corrective actions** — concrete items added to the
   [CSI register](continual-improvement.md), each with an owner and target date.

---

## 8. KPIs

| KPI | Definition | Target |
|---|---|---|
| Mean time to restore (P1) | Detect → service restored. | < 4 hours |
| Recurring-incident rate | Incidents matching an existing KEDB entry. | Decreasing QoQ |
| % P1s with a post-incident review | Reviews completed ÷ P1 incidents. | 100% |
| Problems with permanent fix | Closed problems ÷ raised problems. | ≥ 80% within 90 days |
