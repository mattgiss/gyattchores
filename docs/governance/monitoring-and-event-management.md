# Monitoring & Event Management

| | |
|---|---|
| **Document ID** | GOV-MON-001 |
| **Practice** | Monitoring & Event Management (ITIL 4) |
| **Service** | GyattChores |
| **Owner** | Repository owner (`mattgiss`) |
| **Status** | Operational |
| **Implementation** | `.github/workflows/discord-notify.yml` |
| **Review cadence** | Quarterly |

---

## 1. Purpose

Systematically **observe the repository, detect events that matter, and route
them to a channel where they can be acted on.** This practice is the service's
primary early-warning system and the first detection source for
[Incident Management](incident-and-problem-management.md).

An **event** is any change of state significant to the management of the
service. This practice classifies events and decides which require action.

---

## 2. What is monitored

A single GitHub Actions workflow listens to repository events and posts a
formatted notification to a Discord channel. Coverage:

| Event source | Trigger conditions | Notification |
|---|---|---|
| **Push** | Any branch | "Deployed to main" (green) for `main`; "Push to <branch>" (purple) otherwise. |
| **Pull request** | opened, closed, reopened, synchronize, review_requested | Colour-coded by outcome: opened (blue), merged (green), closed (red), updated, review-requested. |
| **PR review** | submitted | approved (green), changes requested (red), commented. |
| **Issues** | opened, closed, reopened, assigned | Colour-coded by action. |
| **Branch / tag** | create, delete | Created (blue) / deleted (grey). |
| **Manual** | `workflow_dispatch` | "Notifications Active" test message. |

---

## 3. Event classification (ITIL model)

Events are triaged into three classes. The workflow encodes this with colour
and title so the human reader triages at a glance.

| Class | Meaning | Examples | Action |
|---|---|---|---|
| 🟢 **Informational** | Normal operation; recorded, no action. | Push to a feature branch; PR opened; branch created. | Awareness only. |
| 🟡 **Warning** | Approaching a threshold or needs attention. | Changes requested on a PR; PR closed unmerged; deploy to `main` (validate it!). | Review; run smoke test if it touched production. |
| 🔴 **Exception** | Something is wrong; act now. | Workflow run **failed**; Discord returned non-`204`; expected deploy notification missing. | Enter the [incident triage runbook](incident-and-problem-management.md#4-triage-runbook--the-app-isnt-working). |

> **Deploy-to-`main` is intentionally a 🟡 Warning-class signal**, not merely
> informational: it is a production release and should prompt the
> post-deployment smoke test.

---

## 4. Detection of failures (self-monitoring)

The monitoring system monitors **itself**. Each notification step:

1. Captures the **HTTP status** returned by Discord
   (`curl -s -o … -w "%{http_code}"`).
2. Logs `Discord HTTP: <code>` to the Actions run.
3. **Fails the job** on any status other than `204`, emitting a GitHub
   `::error::` annotation.

This means a delivery failure is itself a detectable event (a failed workflow
run), closing the classic monitoring blind spot of "the alerter silently
stopped alerting." See **KE-002** and **KE-003** in the KEDB for the two
failure modes this guards against (forum-channel `thread_name` requirement; the
prior silent `curl -s` behaviour).

---

## 5. Configuration

| Item | Value / location |
|---|---|
| Workflow | `.github/workflows/discord-notify.yml` |
| Secret | `DISCORD_WEBHOOK` (GitHub → Settings → Secrets and variables → Actions) |
| Destination | Discord **Forum** channel (requires `thread_name` per post — see KE-002) |
| Delivery contract | Success = HTTP **204**. Anything else fails the run. |

### 5.1 Test procedure

Use the manual trigger to verify the pipeline end-to-end without waiting for a
real event:

1. GitHub → **Actions** → **Discord Notifications** → **Run workflow**.
2. Confirm the test embed appears in Discord.
3. Confirm the Actions log shows `Discord HTTP: 204`.

(If `workflow_dispatch` is unavailable to the runner identity, any push to a
branch exercises the same delivery path.)

### 5.2 Rotating the webhook (security hygiene)

The webhook URL is a credential. If it is exposed (e.g. pasted into chat):

1. Discord → Server Settings → Integrations → Webhooks → **Regenerate** (or
   delete and recreate).
2. Update the `DISCORD_WEBHOOK` repository secret with the new URL.
3. Trigger a test (§5.1) to confirm.

This is corrective action **CA-06** in the [CSI register](continual-improvement.md).

---

## 6. Roadmap — toward proactive monitoring

Current coverage is **reactive to repository events**. Maturity improvements
(tracked in the [CSI register](continual-improvement.md)):

| Enhancement | Value | Reference |
|---|---|---|
| **Synthetic uptime check** of [gyattchores.com](https://gyattchores.com) on a schedule | Detects a *live-site* outage that no repo event would reveal (e.g. DNS/Pages failure). | CA-05 / CA-11 |
| **CI status as an event** | Surfaces failing quality gates directly in the feed. | CA-04 |
| **Scheduled secret-scanning summary** | Periodic assurance that no secret leaked. | CA-06 |

---

## 7. KPIs

| KPI | Definition | Target |
|---|---|---|
| Notification delivery rate | Successful (`204`) deliveries ÷ attempts. | ≥ 99% |
| Mean detection lead | Event occurs → visible in Discord. | < 1 minute |
| Self-monitoring coverage | Notification steps that fail-loud on error. | 100% (achieved) |
| Exception acknowledgement | 🔴 events triaged within target. | Same day |
