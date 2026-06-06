# Contributing to GyattChores

Thanks for helping improve GyattChores. This project is governed by a
lightweight, ITIL 4-aligned Service Management System in
[`docs/governance/`](docs/governance/README.md) — these are the short version
of those rules.

## Before you start

- A merge to `main` deploys **straight to production** ([gyattchores.com](https://gyattchores.com))
  via GitHub Pages. Treat every change accordingly.
- There is **no build step** — the web app is a single self-contained
  `index.html`.

## Making a change

1. **Branch** from the latest `main` (short-lived, one concern; `claude/` prefix
   for agent work, or a descriptive kebab-case name).
2. **Commit** focused changes with clear messages.
3. **Open a pull request** using the template. Fill in *What / Why / How*, a
   **Verification** table, and the self-attestation checklist.
4. **Validate** — ensure checks pass and run the smoke test (load the app,
   log a chore, approve it, reload to confirm persistence).
5. **Merge** once green and reviewed/self-attested. Delete the branch.

Full details: [Change Enablement](docs/governance/change-enablement.md).

## Reporting problems

- **Outage / "it's not working"** → open an **Incident** issue.
- **Defect** → open a **Bug report** issue.
- **Idea / feature** → open a **Change request** issue.
- **Security concern** → see [`SECURITY.md`](SECURITY.md).

## Rolling back

If a change breaks production, revert the merge commit — see
[Change Enablement §8](docs/governance/change-enablement.md#8-rollback-backout-procedure).

## Code of conduct

Be kind. This is a family project built for kids — keep contributions and
discussion respectful.
