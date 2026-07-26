# Contributing

Thanks for contributing. Bug reports, feature requests, and pull requests are all
welcome — whether it's a new entity type, a UI fix, or a docs improvement.

## Reporting bugs & requesting features

Open a GitHub issue. For bugs, include your watch model, its software version (on the
watch: Settings → System → About), the app version, the steps to reproduce, and what you
expected versus what actually happened. For feature requests, describe the capability and
why it's useful.

## Getting started

Install the Connect IQ SDK and either put its `bin/` directory on `PATH`, or point
`CIQ_SDK` at the SDK root:

```sh
export CIQ_SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/<version>"
```

A developer signing key is required to produce builds. Generate one once (git-ignored,
handled via `openssl` under the hood):

```sh
make key
```

## Build, run, test

All Makefile targets accept `DEVICE=<id>` to override the default (`venu3`).

```sh
make build   # compile a debug build for DEVICE
make lint    # compile with -l 3 -w and fail on any compiler warning
make sim     # launch the Connect IQ simulator (opens it, then returns)
make run     # build + launch the app in the running simulator
make test    # build + run unit tests in the running simulator
make clean   # remove build output
```

`make sim` opens the simulator and exits, so `make run` and `make test` can follow in the
same shell — they just need the simulator already open. Tests cover the pure logic that
doesn't require a network; networking is verified in the simulator or on-device instead.

## Continuous integration

`.github/workflows/ci.yml` runs on `ubuntu-latest` inside the
[`matco/connectiq-tester`](https://github.com/matco/connectiq-tester) container, which
bundles the Connect IQ SDK and runs a headless simulator via Xvfb — so the whole
build-and-test step runs on Linux with no Garmin login and no committed signing key (the
container generates a temporary self-signed certificate).

The **SDK version is pinned by the image tag** (baking SDK 9.2.0, matching what we develop
against), not `:latest` — bumping the SDK is a deliberate tag bump. No repository secrets
are required, so CI also runs on pull requests from forks.

## Workflow

Trunk-based: branch off `main`, open a PR, **squash-merge** back. One PR is one
commit on `main`.

## Commit messages and PR titles

Squash-merging means the PR title becomes the commit subject on `main`, so the
same rules apply to both. Write them for people to read — convey the *meaning*,
not the *how*.

- Imperative mood — "Add area menu", not "Added" or "Adds".
- Capitalize the first letter.
- No trailing period.
- Be meaningful — never a bare "Update" or "Fix".
- **No prefixes** — no `feat:` / `fix:`, no `platform:`, no `[tag]`.

There is no Conventional Commits requirement and no commit linter; these are held
up by review.

## Changelog

The changelog is compiled from hand-written fragments by
[changie](https://changie.dev) — `CHANGELOG.md` is generated, never edited by hand.

When your change is user-visible, add a fragment in the same PR:

```sh
changie new
```

It prompts for a **kind** (🎉 New / ✨ Improved / 🔧 Fixed) and a one-line
description, then writes a file under `.changes/unreleased/`. Commit that file
with your change. Fragments carry no commit hashes, so the changelog stays clean
and user-facing.

Purely internal changes (refactors, CI, docs) don't need a fragment.

## Releases

Releases are cut manually from the **Release** GitHub Actions workflow
(`workflow_dispatch`): pick the bump (patch / minor / major / auto) and run it.
It batches the fragments, compiles `CHANGELOG.md`, commits, tags `vX.Y.Z`, and
creates the GitHub Release.

Versioning is [SemVer](https://semver.org/). The git tag is the canonical version
of record. changie stores versions **unprefixed** (`0.2.0`); the `v` prefix is a
git-tag convention added only to the tag and Release.

### Publishing to the Connect IQ Store

The Store assigns the app version **at upload time** — you type it into the Store
dashboard per submission; the build carries no authoritative version. **Type the
version to match the git tag** (tag `v0.2.0` → enter `0.2.0`). Nothing enforces
this automatically.

#### Changelog vs. release notes

`CHANGELOG.md` and the Store's "what's new" are two different documents:

- The **changelog** accumulates one section per git release. Every
  `workflow_dispatch` run appends a version, so several git releases can pile up
  between two Store submissions.
- The **release notes** are the Store's "what's new" for a single submission. They
  cover *everything* shipped since the last Store release — often several
  changelog versions at once — consolidated into one clean, user-facing block.

So a Store submission isn't a copy of one changelog section. Compile the release
notes by consolidating every changelog entry from the last Store-published
version up to now: read those sections, merge overlapping items, drop anything
that only mattered to an intermediate git release, and rewrite the result as one
short "what's new". The changelog is the source; the release notes are an
editorial pass over a version range of it.

The start of that range is the last version actually published to the Store.
We'll likely mark Store releases with their own git tag so the range is
mechanical; until that convention lands, take the start version from the Store
dashboard.

## How we work

See [WAYS-OF-WORKING.md](WAYS-OF-WORKING.md) for the design principle we hold to, the
issue lifecycle (how a ticket moves from unconfirmed to spec-ready), and the spec-filing
convention.
