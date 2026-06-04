# Security

## Architecture & threat model

GyattChores is a **local-first client-side app** with an **optional** cloud sync layer:

- The source of truth is the browser's `localStorage` (web) or `UserDefaults` (iOS app), on the device.
- If configured, chore logs also sync to a **Supabase** table (`simple_logs`) so multiple devices can share data. This is best-effort: the app works fully without it and never depends on it to save a chore.
- The app is served as static files from GitHub Pages.

### About the Supabase sync

- The client uses the project's **public anon key**, which is embedded in `index.html` (this is the key Supabase designates as safe for browsers). Access is governed by the row-level-security policies in [`simple-logs-schema.sql`](simple-logs-schema.sql).
- Those policies are intentionally **permissive** (anon can read/insert/update `simple_logs`) because this is a private family app with non-sensitive data and no per-user login. **Do not store anything secret in this table**, and don't reuse these policies for an app with sensitive or multi-tenant data.
- The anon key only grants what RLS allows. Never put the **service_role** key in the client.
- If you fork this or rotate projects, update `SUPABASE_URL`/`SUPABASE_ANON_KEY` in `index.html`, and disable/rotate any keys for projects you no longer use.

## The admin PIN is not a security boundary

The "admin" PIN (the `ADMIN_CODE` constant in `index.html`) gates the approve/reject screen. It is a **convenience lock to keep kids from approving their own chores**, not real security:

- It is present in the client source and visible to anyone who views source.
- It protects only the local approval UI; it guards no sensitive data and authorizes no server action.

Treat it accordingly. If you fork this app, change the PIN, but don't rely on it to protect anything that actually matters.

## Data & privacy

- Chore data is always kept on the device; clearing browser storage erases the local copy.
- With sync enabled, the same chore logs (player name, chore name, points, status, timestamp) are also stored in your Supabase project. Only non-sensitive chore data is stored — no accounts, email, analytics, or third-party tracking.
- With sync disabled (or the backend unavailable), data stays local to each device.

## If you want stronger guarantees

This app is intentionally simple. If you adapt it for a context that needs real authentication or shared/synced data, you'd need to add a backend and move trust decisions server-side. At that point, standard practices apply: real auth, server-side authorization, secrets kept out of the client, and (for children's data) COPPA-style consent and retention policies.

## Reporting an issue

This is a small family project. If you find a security problem, please open an issue in the repository describing it. There is no formal disclosure program.
