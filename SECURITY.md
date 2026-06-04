# Security

## Architecture & threat model

GyattChores is a **fully client-side app**. There is no backend, no database, and no server that stores user data:

- All chore logs and points are kept in the browser's `localStorage` (web) or `UserDefaults` (iOS app), on the device only.
- Nothing is transmitted to or stored by GyattChores servers — there are none. The only network requests are to public CDNs (React, Babel, Google Fonts) to load the app itself.
- The app is served as static files from GitHub Pages.

Because there is no server and no shared data store, the classic web risks (credential leaks, SQL injection, broken access control, data breaches of a central database) **do not apply** here.

## The admin PIN is not a security boundary

The "admin" PIN (the `ADMIN_CODE` constant in `index.html`) gates the approve/reject screen. It is a **convenience lock to keep kids from approving their own chores**, not real security:

- It is present in the client source and visible to anyone who views source.
- It protects only the local approval UI; it guards no sensitive data and authorizes no server action.

Treat it accordingly. If you fork this app, change the PIN, but don't rely on it to protect anything that actually matters.

## Data & privacy

- Chore data never leaves the device. Clearing your browser storage (or deleting the app) erases all data.
- No accounts, no email, no analytics, no third-party tracking.
- Since data is local-only, there is no cross-device sync — each device keeps its own history.

## If you want stronger guarantees

This app is intentionally simple. If you adapt it for a context that needs real authentication or shared/synced data, you'd need to add a backend and move trust decisions server-side. At that point, standard practices apply: real auth, server-side authorization, secrets kept out of the client, and (for children's data) COPPA-style consent and retention policies.

## Reporting an issue

This is a small family project. If you find a security problem, please open an issue in the repository describing it. There is no formal disclosure program.
