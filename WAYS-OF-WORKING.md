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

An issue moves through four stages, each named by the label it carries and the action it needs next. The label names the action, so landing on a ticket tells you which step to run:

| Label | State | Next action |
| --- | --- | --- |
| `unconfirmed` | Authored, not yet human-vetted | vet it (is it real / worth doing?) |
| `needs-grilling` | Vetted; design not yet grilled | grill it (stress-test the design) |
| `needs-spec` | Grilled; design settled, spec not yet filed | write the spec |
| `spec-ready` | Spec filed | implement |

`blocked` is orthogonal (waiting on another issue) and can sit alongside any stage. An issue with no lifecycle label is ready with nothing pending. The stages are distinct steps — grilling settles the design, then a spec writes it up — so a ticket sits at `needs-spec` only after it has actually been grilled.

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
- Advancing through the lifecycle is manual, one label swap per stage as its step is done:
  vetting swaps `unconfirmed` → `needs-grilling`; grilling swaps `needs-grilling` →
  `needs-spec`; filing the spec swaps `needs-spec` → `spec-ready`.

## What `spec-ready` means

`spec-ready` means **a spec artifact exists** for the issue — not that the spec has been
accepted. The real acceptance gate is **code review on the pull request**. Keeping
`spec-ready` to the simple "a spec is available" meaning keeps the flow agile: work can
start against a spec, and the PR is where the approach is finally judged.
