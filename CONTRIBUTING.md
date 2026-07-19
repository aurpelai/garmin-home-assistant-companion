# Contributing

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

It prompts for a **kind** (Added / Changed / Fixed / Removed / Security) and a
one-line description, then writes a file under `.changes/unreleased/`. Commit that
file with your change. Fragments carry no commit hashes, so the changelog stays
clean enough to paste into the Connect IQ Store "what's new" field.

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
this automatically. Paste the matching `CHANGELOG.md` section into "what's new".
