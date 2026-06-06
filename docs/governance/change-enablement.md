# Change Enablement & Deployment Management

| | |
|---|---|
| **Document ID** | GOV-CHG-001 |
| **Practice** | Change Enablement; Release & Deployment Management (ITIL 4) |
| **Service** | GyattChores |
| **Owner** | Repository owner (`mattgiss`) |
| **Status** | Defined — adoption in progress (see [CSI register](continual-improvement.md)) |
| **Review cadence** | Quarterly |

---

## 1. Purpose

Ensure that **every change to the GyattChores production service is assessed,
recorded, and released in a controlled way** that maximises successful changes
while protecting the live experience for the family using the app.

The guiding ITIL principle: *a change is the addition, modification, or removal
of anything that could have a direct or indirect effect on the service.* For
this repository, **any merge to `main` is a production change**, because `main`
deploys automatically to GitHub Pages.

---

## 2. Scope

Applies to all modifications of:

- `index.html` (the entire web application)
- Deployment-affecting files: `CNAME`, PWA manifest/icons, workflows in
  `.github/`
- The native app sources under `GyattChoresApp/`
- Governance and documentation under `docs/` and repository-root policy files

---

## 3. Change model (standard path)

Because the service is low-risk and single-maintainer, one lightweight model
covers the majority of changes. **Normal** and **Emergency** variants handle
the exceptions.

```
 idea / issue
      │
      ▼
 feature branch ──►  commit(s)  ──►  Pull Request  ──►  validation  ──►  merge to main
 (claude/* or                        (what/why/how      (CI gate +        │
  descriptive name)                   + verification)    self/peer        ▼
                                                          review)     GitHub Pages
                                                                       deploy (auto)
                                                                          │
                                                                          ▼
                                                              Discord notification
                                                              (Event Management)
```

### 3.1 Change types

| Type | Definition | Authorisation | Example |
|---|---|---|---|
| **Standard** | Pre-approved, low-risk, follows this model. | Self-service via PR + green CI. | Add a chore, copy tweak, doc update, stat-pill change. |
| **Normal** | Higher-impact or architectural. | PR + explicit review checkpoint before merge; record rationale. | Re-introduce backend sync, change storage schema, alter deployment. |
| **Emergency** | Restores a broken production service. | May merge first to restore service, then **retrospectively** document within 24h. | Live site cannot log chores (see PR #8). |

---

## 4. Branching policy

| Rule | Standard |
|---|---|
| Production branch | `main` — always deployable; represents live. |
| Work branches | Short-lived, one concern each. Prefix `claude/` for agent-driven work or use a descriptive kebab-case name. |
| Direct commits to `main` | **Prohibited** once branch protection (CA-01) is enabled. |
| Branch lifespan | Delete after merge. Stale branches are reviewed at each quarterly cadence (CA-10). |
| Source of truth | Branch from latest `main`; rebase/merge `main` before requesting review. |

---

## 5. Pull request standard

Every PR is the **change record**. The repository's existing PR quality is a
strength — this codifies it. Required content (see
[`pull_request_template.md`](../../.github/pull_request_template.md)):

1. **What** — the change in one or two sentences.
2. **Why** — the driver (issue, incident, request).
3. **How** — implementation notes and any trade-offs.
4. **Verification** — a table of what was tested and the result.
5. **Risk & rollback** — blast radius and how to revert.

A change is **ready to merge** when: CI is green, the template is complete, and
the reviewer checkpoint (§6) is satisfied.

---

## 6. Review & authorisation (the control to add)

> **Current state (GAP-03):** 100% of PRs are self-authored and self-merged,
> often within ~2 minutes — review is not currently a control.

Target control, enforced by branch protection (CA-01):

- **Require a pull request** before merging to `main` (no direct pushes).
- **Require status checks** (the CI gate, CA-04) to pass.
- **Require the change author to self-attest** against a review checklist when
  no second reviewer is available (single-maintainer reality), OR request a
  reviewer when one exists. The self-attestation is recorded as a PR comment so
  the *decision* is auditable even if the *reviewer* is the same person.
- **`CODEOWNERS`** (CA-09) routes review requests automatically.

Self-attestation checklist (paste into the PR):

```
- [ ] Change tested locally (state how, in the Verification table)
- [ ] No secrets, keys, or PII added to the client or repo
- [ ] Rollback path identified
- [ ] Docs updated if behaviour or deployment changed
```

---

## 7. Release & deployment management

| Attribute | Detail |
|---|---|
| **Mechanism** | GitHub Pages builds and publishes `main` automatically. |
| **Release unit** | A merge commit to `main`. |
| **Environments** | Production only. *No staging today* (GAP-05) — see CA-05 for an optional preview environment. |
| **Deployment window** | None enforced; merges deploy immediately. Avoid merging high-risk Normal changes when the family is actively using the app. |
| **Verification of release** | (a) Discord deploy notification fires; (b) spot-check [gyattchores.com](https://gyattchores.com) loads and a chore can be logged. |
| **Deployment record** | The merge commit + PR + Discord event collectively form the deployment record (CA-05 formalises a one-line entry per production release). |

### 7.1 Post-deployment validation (smoke test)

After any production change to `index.html`:

1. Load the live site; confirm header, players, and chore grid render.
2. Select a player → log a chore → confirm the pending entry appears.
3. Enter the admin PIN → approve → confirm points roll into Today/This Week.
4. Reload → confirm persistence.

If any step fails → invoke [Incident Management](incident-and-problem-management.md).

---

## 8. Rollback (backout) procedure

Because each release is a single merge commit, rollback is fast:

```bash
# Identify the bad merge
git log --oneline -10 main

# Option A — revert the merge (preferred; keeps history)
git checkout main && git pull
git revert -m 1 <merge_commit_sha>
git push origin main         # redeploys the prior good state

# Option B — emergency: reset main to last-good (requires temporary
# protection bypass; use only when revert is not viable)
git reset --hard <last_good_sha>
git push --force-with-lease origin main
```

A known-good reference is preserved on the `backup-stable-*` branch line; keep
at least one recent stable backup branch at all times.

---

## 9. RACI

| Activity | Owner | Reviewer | Notes |
|---|:---:|:---:|---|
| Raise change (PR) | **R/A** | — | Author owns the record. |
| Validate (CI + smoke) | **R** | A | Automated gate + manual smoke test. |
| Authorise merge | **A** | R | Self-attest or peer review. |
| Deploy | — | — | Automated (GitHub Pages). |
| Confirm release | **R/A** | — | Discord event + live spot-check. |
| Roll back | **R/A** | — | Per §8. |

*(R = Responsible, A = Accountable. Single-maintainer: roles collapse onto the
owner but the **decision points remain distinct and recorded**.)*

---

## 10. Key performance indicators

| KPI | Definition | Target |
|---|---|---|
| Change success rate | Production changes not requiring rollback or an emergency fix. | ≥ 95% |
| Change lead time | First commit → live in production. | < 1 day for Standard |
| % changes via PR | Merges to `main` that went through a PR (vs. direct push). | 100% |
| % changes with verification | PRs containing a completed verification table. | 100% |
| Emergency change ratio | Emergency ÷ total changes. | < 10% |

These feed the [Continual Improvement](continual-improvement.md) review.
