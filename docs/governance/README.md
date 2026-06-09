# GyattChores — Service Management System (SMS)

| | |
|---|---|
| **Document ID** | GOV-IDX-001 |
| **Service** | GyattChores (Family Chore Tracker) |
| **Framework** | ITIL 4 |
| **Owner** | Repository owner (`mattgiss`) |
| **Established** | 2026-06-06 |
| **Review cadence** | Quarterly |

This directory is the **Service Management System** for GyattChores: a set of
professional, ITIL 4-aligned runbooks that let the service **govern, operate,
and improve itself** without relying on undocumented knowledge. It exists so
that anyone — the owner returning after months away, or a new contributor — can
understand *how this service is run* and *how to keep it healthy*.

---

## 1. How to use this SMS

| If you want to… | Read |
|---|---|
| See the current governance posture and gaps | [Governance Audit](governance-audit.md) |
| Make a change safely (branch → PR → deploy → rollback) | [Change Enablement & Deployment](change-enablement.md) |
| Respond to an outage or recurring fault | [Incident & Problem Management](incident-and-problem-management.md) |
| Recover lost access or a failed dependency | [Break-Glass & Recovery](break-glass-and-recovery.md) |
| Understand the Discord alerting & what events mean | [Monitoring & Event Management](monitoring-and-event-management.md) |
| Manage access, secrets, and supply chain | [Information Security Management](information-security-management.md) |
| See the prioritised improvement backlog | [Continual Improvement Register](continual-improvement.md) |
| Understand the app's data/threat model | [`SECURITY.md`](../../SECURITY.md) |

---

## 2. Service description

GyattChores is a gamified family chore tracker. Children tap to log chores, a
parent approves them with a PIN, and points roll up into a weekly competition.

| Attribute | Value |
|---|---|
| **Service type** | Public-facing static web app (PWA) + native SwiftUI app |
| **Live URL** | [gyattchores.com](https://gyattchores.com) |
| **Criticality** | Low (family/personal); **availability protected by local-first design** |
| **Users** | A single household |
| **Hours of service** | 24/7, best-effort |
| **Owner / accountable** | `mattgiss` |

---

## 3. The practices in this SMS

```
                       ┌─────────────────────────────┐
                       │   Continual Improvement     │  ← the engine: turns
                       │   (CSI register, GOV-CSI)   │    findings into action
                       └──────────────┬──────────────┘
                                      │ drives
   ┌──────────────┬───────────────────┼───────────────────┬──────────────┐
   ▼              ▼                   ▼                   ▼              ▼
 Change       Incident &          Monitoring &        Information     Governance
 Enablement   Problem Mgmt        Event Mgmt          Security        Audit
 (GOV-CHG)    (GOV-INC)           (GOV-MON)           (GOV-SEC)       (GOV-AUD)
   │              ▲                   │                                  ▲
   │ deploys      │ detects           │ feeds detection                 │ baselines
   └──────────────┴───────────────────┘                                 │
              production service ─────────────────────────────────────► │
```

Each practice is self-contained but cross-linked: the **audit** sets the
baseline, **continual improvement** prioritises the fixes, and the operational
practices (**change**, **incident**, **monitoring**, **security**) run the
service day to day.

---

## 4. Governance at a glance

From the [latest audit](governance-audit.md) (2026-06-06):

| Domain | RAG | Maturity |
|---|:---:|:---:|
| Change Enablement | 🔴 | 1 |
| Release & Deployment | 🟠 | 2 |
| Access & Identity | 🔴 | 1 |
| Monitoring & Event Mgmt | 🟢 | 3 |
| Incident & Problem Mgmt | 🟠 | 2 |
| Information Security | 🟠 | 2 |
| Configuration & Docs | 🟢 | 3 |

**Overall: Level 2 of 5.** Target: **Level 3** within 12 months via the
[CSI register](continual-improvement.md). Top priorities: protect `main`
(CA-01), document recovery (CA-02), secure secrets (CA-06).

---

## 5. Service configuration (CMDB-lite)

The configuration items (CIs) that make up the service. Keep this current — it
is the map used during incidents and changes.

| CI | Type | Location / identifier | Notes |
|---|---|---|---|
| Web application | Software | `index.html` | Entire SPA; no build step. |
| Hosting | Platform | GitHub Pages (from `main`) | Production deploy target. |
| Custom domain | DNS | `CNAME` → gyattchores.com | DNS managed at the registrar (record in CA-02). |
| Native app | Software | `GyattChoresApp/` | SwiftUI (iPhone + Watch); Xcode project not committed. |
| Optional sync backend | Service | Supabase (`simple_logs` table) | Best-effort; **anon** key in client. See KE-001. |
| Monitoring | Automation | `.github/workflows/discord-notify.yml` | Event notifications. |
| Notification destination | External | Discord **Forum** channel | Needs `thread_name` per post (KE-002). |
| Secret | Credential | `DISCORD_WEBHOOK` (Actions secret) | Rotate if exposed (CA-06). |
| Dependencies | Library | React 18.3.1, React-DOM 18.3.1, `@babel/standalone` 7.29.7 (unpkg, SRI-pinned); `@supabase/supabase-js` 2.108.0 (jsdelivr) | Pinned to exact versions; unpkg scripts carry `sha384` SRI. Review quarterly; recompute SRI on bump (CA-07). |
| Source of truth (data) | Data store | Browser `localStorage` / iOS `UserDefaults`, key `gyattchores_logs` | Local-first; per-device. |

---

## 6. Roles (RACI summary)

This is a single-maintainer service; ITIL roles **collapse onto the owner**, but
the SMS keeps the *decision points* distinct and recorded so accountability
survives even with one person.

| ITIL role | Held by | Responsibility |
|---|---|---|
| Service owner | `mattgiss` | Accountable for the service end to end. |
| Change authority | `mattgiss` | Approves merges to `main`. |
| Incident manager | `mattgiss` | Drives restoration during incidents. |
| Problem manager | `mattgiss` | Owns root-cause elimination & the KEDB. |
| Security officer | `mattgiss` | Owns access, secrets, and the threat model. |

> **Key-person risk** is the dominant governance risk for this service. See
> CA-02 (break-glass & recovery) — the single most important resilience action.

---

## 7. Review & maintenance of this SMS

- **Quarterly:** re-run the [audit](governance-audit.md), refresh the RAG table
  (§4), reconcile the [CSI register](continual-improvement.md), and complete the
  [security checklist](information-security-management.md#8-security-control-checklist-quarterly).
- **After every P1 incident:** complete a post-incident review and add resulting
  corrective actions to the CSI register.
- **On any material change** to access, deployment, or the control environment:
  update the affected practice doc and the CMDB (§5).

*Documentation is a control. Keeping it current is part of running the service.*
