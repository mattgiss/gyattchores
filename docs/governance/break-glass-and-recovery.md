# Break-Glass & Recovery

| | |
|---|---|
| **Document ID** | GOV-BCR-001 |
| **Practices** | Service Continuity; Information Security (ITIL 4) |
| **Service** | GyattChores |
| **Owner** | Repository owner (`mattgiss`) |
| **Status** | Defined |
| **Review cadence** | Quarterly, and after any access change or recovery event |
| **Addresses** | GAP-02 (bus factor = 1) · CA-02 |

---

## 1. Purpose

This is the **recovery runbook** for GyattChores. It exists to remove the
single largest governance risk for the service: **bus factor = 1** — one person
holds all access, knowledge, and merge authority, with no documented way back in
if that access is lost.

It answers two questions:

1. **Where does every credential and account live**, so recovery is possible at
   all (§3, §4).
2. **What do you actually do** when a specific thing breaks or access is lost
   (§5).

> **This file is in a public repository. It contains NO secrets, codes, keys,
> passwords, or recovery tokens.** It only records *where* those are kept and
> *how* to use them. The actual material lives in the secure vault (§4).

---

## 2. Recovery objectives

Because the app is **local-first** (the source of truth is each device's
`localStorage` / `UserDefaults`), most "outages" do not lose data — the app keeps
working offline and re-syncs later. Recovery targets reflect that:

| Asset | If lost… | RTO (restore time) | RPO (data loss) |
|---|---|---|---|
| Live site (GitHub Pages) | App unreachable at the domain | Hours | None (code is in git) |
| Supabase sync backend | Cross-device sync stops; each device still works | Days (best-effort) | Only un-synced cross-device deltas |
| GitHub account/repo | Cannot deploy or change the app | Hours–days | None (clones exist locally) |
| Domain / DNS | App unreachable at `gyattchores.com` | Hours–days | None |
| Per-device data | That device's local history | N/A | That device only |

**Guiding principle:** never let a backend outage become a data-loss event. The
local-first design is the primary continuity control; everything below is
secondary.

---

## 3. Critical asset & access inventory

Every account/credential the service depends on. Keep this table current — it is
the map used during a recovery. **Values are intentionally not stored here;** see
the vault (§4).

| # | Asset | Identifier (non-secret) | Provider | Recovery method |
|---|---|---|---|---|
| A1 | GitHub account | `mattgiss` | GitHub | Account 2FA + backup codes; email recovery |
| A2 | Repository | `mattgiss/gyattchores` | GitHub | Owned by A1; mirrored by local clones |
| A3 | Custom domain | `gyattchores.com` (see `CNAME`) | Domain registrar | Registrar account login + 2FA |
| A4 | DNS records | `A`/`ALIAS` → GitHub Pages | Registrar / DNS host | Same as A3 |
| A5 | Hosting | GitHub Pages, served from `main` | GitHub | Re-enable in repo Settings → Pages |
| A6 | Sync backend | Supabase project `ukshxdoqgwoxobjdclpx` | Supabase | Supabase account login (A7) |
| A7 | Supabase account | Project owner login | Supabase | Email + 2FA + backup codes |
| A8 | Discord webhook | `DISCORD_WEBHOOK` (Actions secret) | Discord | Re-create webhook in the Discord channel |
| A9 | Discord server | Notification server/channel | Discord | Server-owner account |
| A10 | Admin PIN | `ADMIN_CODE_HASH` in `index.html` | In source (hashed) | Reset by changing the hash (§5.6) |

> The **anon Supabase key** and **admin PIN hash** live in `index.html` by
> design (see [`SECURITY.md`](../../SECURITY.md)); they are not secrets in the
> recovery sense. The **service-role** Supabase key must NEVER be in the client
> or this repo.

---

## 4. Where recovery material is stored (the vault)

All of the following must be recorded in a **secure password manager / vault**
(e.g. 1Password, Bitwarden) — **never in this repo, commit history, or chat.**

**Owner action — populate and keep current:**

- [ ] GitHub: login, 2FA method, **backup codes**, recovery email
- [ ] Domain registrar: which registrar, login, 2FA/backup codes, domain expiry date
- [ ] Supabase: account login, 2FA/backup codes, project name + region
- [ ] Discord: server-owner account, how to regenerate the webhook
- [ ] The current **admin PIN** (plaintext) and the value it hashes to
- [ ] A note pointing the **secondary contact** (§6) at this vault

**Done when:** a second trusted person, or a recoverable shared vault, can reach
every item in §3 without asking the owner.

---

## 5. Break-glass procedures

Each scenario is self-contained. Start from the symptom.

### 5.1 Live site is down (`gyattchores.com` not loading)

1. Triated per [Incident & Problem Management](incident-and-problem-management.md).
2. Check **GitHub Pages**: repo → Settings → Pages. Confirm it builds from
   `main` and the custom domain shows verified. Re-save the domain to force a
   re-publish if needed.
3. Check **GitHub status** ([githubstatus.com](https://www.githubstatus.com)).
   If Pages is degraded, it's an upstream outage — wait it out; the app still
   works on already-loaded devices and as an installed PWA (offline cache).
4. If Pages is healthy but the domain fails, go to **5.3 (DNS)**.
5. As a last resort, the app is a single static file — it can be served from any
   static host (or opened locally) from a clone while Pages is restored.

### 5.2 GitHub account / access lost

1. Recover the account via GitHub's flow using the **2FA backup codes** and
   recovery email from the vault (§4).
2. If unrecoverable: a full clone exists locally (the working copy) and on any
   machine that has pulled the repo — **no code is lost**. Create a new repo,
   push the clone, re-point Pages and the domain (§5.1, §5.3).
3. Re-create the `DISCORD_WEBHOOK` Actions secret (§5.5).

### 5.3 Domain / DNS problem

1. Log in to the **registrar** (vault, A3).
2. Confirm the domain has **not expired** (record the expiry; set a renewal
   reminder).
3. Verify DNS points at GitHub Pages (the `A`/`ALIAS` records GitHub documents
   for apex domains) and that the repo `CNAME` file contains `gyattchores.com`.
4. Allow for DNS propagation (up to a few hours).

### 5.4 Supabase project lost, reset, or data corrupted

The app **keeps working without Supabase** — this is a sync degradation, not an
outage. To restore sync:

1. If the project still exists: check it's not paused (free-tier projects pause
   when idle) — open the Supabase dashboard and resume it.
2. If the project/table is gone or must be rebuilt: in the Supabase **SQL
   Editor**, run [`simple-logs-schema.sql`](../../simple-logs-schema.sql) to
   recreate the `simple_logs` table, indexes, and RLS policies exactly.
3. If you created a **new** project, update `SUPABASE_URL` and
   `SUPABASE_ANON_KEY` in `index.html` (via PR), and disable/rotate keys on the
   old project.
4. Devices re-push their local logs on next sync; the
   [`scripts/supabase-audit.sql`](../../scripts/supabase-audit.sql) and
   `points-recovery` workflow can help reconcile (see KEDB / points recovery).

**Backups:** periodically export `simple_logs` (Supabase dashboard → Table →
Export CSV) and keep the file with the vault. Each device's `localStorage` is an
independent copy of that device's history.

### 5.5 Discord webhook compromised or broken

1. In the Discord channel: **delete** the old webhook and **create** a new one.
2. Update the **`DISCORD_WEBHOOK`** secret: repo → Settings → Secrets and
   variables → Actions → update `DISCORD_WEBHOOK`.
3. Trigger `discord-notify` (push to `main` or **Run workflow**) to confirm a
   `204` post. Rotate immediately if the URL ever appeared in a log or PR
   (CA-06).

### 5.6 Reset the admin PIN

The PIN is a convenience lock, not a security boundary
([`SECURITY.md`](../../SECURITY.md)). To change it:

1. Compute the FNV-1a hash of the new PIN (the `hashCode` function in
   `index.html` is the reference implementation).
2. Update `ADMIN_CODE_HASH` in `index.html` via PR; record the new PIN in the
   vault (§4).

---

## 6. Reducing bus factor

- **Secondary recovery contact:** nominate one trusted person who can reach the
  vault (§4) and, ideally, has collaborator access to the repo. Record who, in
  the vault.
  - [ ] *Owner action: nominate and record the secondary contact.*
- **Backup branch:** keep at least one recent `backup-stable-YYYYMMDD` branch
  (e.g. `backup-stable-20251206`) as a known-good restore point that is never
  force-updated.
- **Local clones are backups:** every machine with a clone holds the full
  history. Pull periodically on a second device.

---

## 7. Recovery drill (quarterly)

Prove the runbook works before you need it:

- [ ] Confirm every vault item in §4 is present and current.
- [ ] Confirm the domain expiry date and renewal reminder exist.
- [ ] Verify a fresh `git clone` builds the site locally and loads.
- [ ] Re-run `simple-logs-schema.sql` against a scratch Supabase project and
      confirm it creates cleanly (validates the recovery SQL).
- [ ] Confirm the secondary contact (§6) can still reach the vault.
- [ ] Take a fresh `simple_logs` CSV export and store it with the vault.

Record the drill date in the [Continual Improvement Register](continual-improvement.md)
and refresh this document's review date.

---

*Documentation is a control. A recovery plan no one has tested is a guess —
run the drill (§7).*
