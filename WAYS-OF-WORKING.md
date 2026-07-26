# Ways of working

How we do things in this repo. Lean for now — one design principle, the issue lifecycle, and the spec convention.

## Build for now, enable the future

Build the current feature; don't build the future. Every design decision keeps future work _reachable_ without _implementing_ it now.

Concretely:

- Solve the feature in front of you with the simplest correct design. Extra generality earns its place only when there is a second real consumer to shape it — one hypothetical consumer is not enough.
- Where the future is known (for example, this app will grow beyond lights to other entity domains), don't bake an assumption that would have to be unpicked later. Keep names and concepts neutral enough that extending is additive, not a rewrite.
- Prefer the change that a future feature can build _on top of_ over the change that a future feature would have to _tear out_. When unsure which a decision is, that uncertainty is the thing to resolve before committing.

The test for any decision: does it make the eventual feature cheaper to add, without paying for it today?

## Issue lifecycle

An issue's lifecycle label names the **state of the work** — how ready it is, and so what a contributor can do with it next. It names the state, not any particular tool or workflow: you read it and know whether the ticket still needs sanity-checking, needs its approach settled and written up, or is ready to build.

| Label | State | What you can do |
| --- | --- | --- |
| `unconfirmed` | Not yet vetted — may not be worth doing | Sanity-check it before anyone invests |
| `ready-to-spec` | Confirmed worth doing; approach not yet settled and written | Settle the approach and write the spec |
| `ready-to-build` | A spec exists — approach is decided and written down | Start implementing |

Settling the approach and writing it into a spec are one state, not two: a ticket is `ready-to-spec` until a spec exists, and reaching `ready-to-build` *means* the spec is written. However you get there — a long discussion, a quick decision — the label describes where the work stands, not the steps you took.

`blocked` is orthogonal (waiting on another issue) and can sit alongside any state. A closed issue is the terminal state: closed as *completed* means it shipped, closed as *not planned* means it won't be done — so there is no "done" label, the tracker carries it.

## Filing a spec

Once an issue's design has been discussed and settled, the outcome is written up as a **spec**. The spec is a separate, linked ticket — never edited into the original issue's body. The original body is the frozen record of what was asked; rewriting it taints that intent.

A spec ticket:

- **Is titled `Spec: <short description> (#N)`**, where `#N` is the issue it specs. The `Spec:` prefix is load-bearing (see _Labels_ below).
- **Is filed as a sub-issue of the original**, so the relationship is visible in GitHub's issue hierarchy.
- **Leaves the original body untouched.** A comment on the original links to the spec.

## Labels

- New issues are auto-labeled by the `Label new issues` Action:
  - A `Spec:`-titled issue gets **`spec`** (it captures a settled design, so it is not "unvetted").
  - Every other new issue gets **`unconfirmed`** — unvetted until a maintainer confirms it.
- Advancing through the lifecycle is manual, one label swap as each state is reached: vetting swaps `unconfirmed` → `ready-to-spec`; writing the spec swaps `ready-to-spec` → `ready-to-build`.

## What `ready-to-build` means

`ready-to-build` means **a spec artifact exists** for the issue — not that the spec has been accepted. The real acceptance gate is **code review on the pull request**. Keeping `ready-to-build` to the simple "a spec is available" meaning keeps the flow agile: work can start against a spec, and the PR is where the approach is finally judged.
