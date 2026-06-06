# Production Readiness Check — GyattChores

You are running a production readiness audit for GyattChores, a family chore tracker targeting the Apple App of the Year 2027. This is a living production system — not a proof of concept. Treat every finding as a real risk to real users.

## Your job

Run each check below in sequence. For each one, use the appropriate tool (Bash, GitHub MCP, WebFetch, Grep, Read) to gather real evidence. Do not guess or assume — only report what you can verify. Mark each item ✅ PASS, ⚠️ WARN, or ❌ FAIL with a one-line reason and a concrete corrective action.

At the end, output a Production Score (0–100), a RAG (Red/Amber/Green) rating, and a prioritised punch list of the top 5 actions needed before the next release.

---

## Check 1 — Live site uptime

Fetch https://gyattchores.com and confirm:
- Returns HTTP 200
- Page title contains "GyattChores"
- The `<div id="root">` is present (app shell rendered)

If the site is unreachable: ❌ FAIL — invoke the incident triage runbook in `docs/governance/incident-and-problem-management.md`.

---

## Check 2 — Branch protection on `main`

Use `mcp__github__list_branches` or the GitHub API to check if `main` has branch protection enabled (require PR, required status checks, block force-push).

If unprotected: ❌ FAIL — CA-01 in `docs/governance/continual-improvement.md`. Direct pushes to production are not acceptable for a production service.

---

## Check 3 — CI/CD health (last 5 runs)

Use GitHub MCP to list the last 5 runs of `.github/workflows/discord-notify.yml`. Check:
- All recent runs succeed
- No failures on the `main` branch
- Failure rate < 10%

If CI is failing: ❌ FAIL with run IDs and failure reasons.

---

## Check 4 — Secret hygiene

Check:
- `DISCORD_WEBHOOK` secret exists in Actions (infer from CI run success)
- No raw secrets present in `index.html` beyond the documented anon key and admin PIN
- `SECURITY.md` accurately describes the current threat model

Run: `grep -n "service_role\|password\|secret\|token" /home/user/gyattchores/index.html | grep -v "ADMIN_CODE\|ANON_KEY\|anon\|#"` to verify no accidental leaks.

---

## Check 5 — Data integrity (Supabase)

Query the Supabase REST API:
```
GET https://ukshxdoqgwoxobjdclpx.supabase.co/rest/v1/simple_logs?select=player_name,status,created_at&order=created_at.asc
```
Headers: `apikey: <SUPABASE_ANON_KEY from index.html>`, `Authorization: Bearer <same>`

Report:
- Total log count by status (approved / rejected / pending)
- Date range of all records (first → last)
- Any gaps > 7 days with zero logs (potential data loss periods)
- Pending logs older than 24h (stuck approvals)
- Logs per player to detect anomalies

If Supabase is unreachable: ⚠️ WARN (app works offline but sync is down). Check KE-001 in the KEDB.

---

## Check 6 — Stale branches

Use GitHub MCP to list all branches. Flag any that:
- Are more than 30 days old without recent commits
- Have "claude/" prefix and are already merged

Report count and list names. Corrective action: CA-10.

---

## Check 7 — iOS app build readiness

Check `GyattChoresApp/` sources for:
- All Swift files compile cleanly (no obvious syntax errors — `grep -r "TODO\|FIXME\|HACK\|fatalError" GyattChoresApp/`)
- `Info.plist` or App Store metadata files present
- Privacy manifest (`PrivacyInfo.xcprivacy`) present (required since iOS 17.4 for App Store)
- App icon set complete (`Assets.xcassets/AppIcon.appiconset/`)

---

## Check 8 — Governance documentation current

Verify:
- `docs/governance/governance-audit.md` exists and has a review date within the last 90 days
- `docs/governance/continual-improvement.md` has open P1 items (CA-01, CA-02, CA-06) and flag them as blockers
- `SECURITY.md` exists and is accurate
- `LICENSE` exists

---

## Check 9 — PWA completeness

Grep `index.html` for:
- `manifest` link tag
- `service-worker` or `serviceWorker` registration
- `apple-touch-icon` meta tag
- `theme-color` meta tag
- `viewport` meta tag with `width=device-width`

These are required for full iOS/Android PWA installability and App Store web clip support.

---

## Check 10 — Performance and accessibility basics

Grep `index.html` for:
- `alt=` attributes on all `<img>` tags
- `aria-label` on icon-only buttons
- Font loading (system font stack preferred — no external font CDN latency)
- React version (should be 18+, confirm CDN URL)
- Babel standalone warning note (acceptable for now; flag as P3 for production build pipeline)

---

## Output format

After all checks, produce:

```
## Production Readiness Report — GyattChores
Date: <today>
Auditor: Claude Code (/prod-check)

### Check results
| # | Check | Status | Finding |
|---|-------|--------|---------|
| 1 | Live site | ✅/⚠️/❌ | ... |
...

### Production Score: XX/100
### RAG: 🟢/🟡/🔴

### Top 5 actions before next release
1. [BLOCKER] ...
2. [HIGH] ...
3. [MEDIUM] ...
4. ...
5. ...

### App of the Year 2027 gap summary
<2-3 sentences on the biggest delta between current state and award-quality>
```

Be direct. This is a production system. If something is broken, say it is broken and say exactly how to fix it.
