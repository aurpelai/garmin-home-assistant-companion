# Ways of working

How we do things in this repo. Lean for now — currently just the spec convention.

## Filing a spec

Once an issue's design has been discussed and settled, the outcome is written up as a
**spec**. The spec is a separate, linked ticket — never edited into the original issue's
body. The original body is the frozen record of what was asked; rewriting it taints that
intent.

A spec ticket:

- **Is titled `Spec: <short description> (#N)`**, where `#N` is the issue it specs. The
  `Spec:` prefix is load-bearing (see _Labels_ below).
- **Is filed as a sub-issue of the original**, so the relationship is visible in
  GitHub's issue hierarchy.
- **Leaves the original body untouched.** A comment on the original links to the spec.

## Labels

- New issues are auto-labeled by the `Label new issues` Action:
  - A `Spec:`-titled issue gets **`spec`** (it captures a settled design, so it is not
    "unvetted").
  - Every other new issue gets **`unconfirmed`** — unvetted until a maintainer confirms it.
- When a spec is filed, the person filing it promotes the **original** issue to
  **`spec-ready`** (remove `needs-spec`, add `spec-ready`). This is a manual step: the
  filer knows which issue the spec is for.

## What `spec-ready` means

`spec-ready` means **a spec artifact exists** for the issue — not that the spec has been
accepted. The real acceptance gate is **code review on the pull request**. Keeping
`spec-ready` to the simple "a spec is available" meaning keeps the flow agile: work can
start against a spec, and the PR is where the approach is finally judged.
