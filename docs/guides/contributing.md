---
title: Contributing and docs versions
order: 11
summary: How these docs are built, versioned and released.
---

# Contributing and docs versions

BxRig is written in BoxLang and compiled with MatchBox. The code is in `src/`, tests in `tests/`, and every command is described in the [command contract](../architecture/COMMAND-CONTRACT.md).

## These docs

The docs are built with [bxSites](https://bxsites.io) from `docs/` and `bxsites.yaml` and published to GitHub Pages at <https://bxcachy.boxlang.io> by `.github/workflows/docs.yml` on every push to `development`.

```bash
bx-module install bx-sites
boxlang bxSites serve           # build and serve with live reload
boxlang bxSites build           # build to site/
```

## Versions

`docs/` is the version being written, **{{ version }}**. When it ships:

```bash
boxlang bxSites version:new --name=1.0.x      # freeze a copy in docs/versions/1.0.x
```

Then set `versions.default: "1.0.x"` in `bxsites.yaml`: the release is served at the root and `docs/` becomes `/next/`. Every theme gets a version switcher. Patch releases edit `docs/versions/1.0.x/` in place; a new minor or major cuts a new version.

## Languages

English only for now. Add one with `boxlang bxSites i18n:new --code=es` and list it under `i18n.locales` in `bxsites.yaml`; `i18n:status` reports coverage.

## Releases

Pushes to `development` publish the `beta` channel; a `v*` tag publishes `stable`. See [Updates and channels](updates.md) and [Security](security.md).

## Writing code that stays DRY

The code review of 2026-11-14 (`docs/architecture/CODE-REVIEW.md`) found the same helper pasted into 20 to 57 classes. These rules keep it from coming back. `tests/dry-test.sh` enforces the ones marked (ratchet): each banned pattern has a maximum count that only goes down.

1. **One home per concept.** Before writing a helper, `grep -rn "function NAME" src/`. If it exists anywhere, use it or move it; never paste it.
2. **A command class never defines `say`, `fail`, `tryExec`, `has`, `env`, `home`, `self` or `merge`** (ratchet). Use `Cli`/`Out` for output, `Proc` for processes, `Env` for paths and variables, `Text` for strings.
3. **Never read `HOME`, `XDG_*` or `BXRIG_*_HOME` directly.** Ask `Env` (`xdgConfig`, `xdgData`, `config`, `data`, `state`, `cache`). One precedence rule everywhere: `BXRIG_*_HOME`, then `XDG_*_HOME`, then the default under `$HOME`. A new override for tests is added to `Env` and listed in `docs/reference/config-files.md`.
4. **Run programs only through `Proc`**, with an argv array, never `sh -c` plus a concatenated name. "Is it installed" is `Proc.has` (`command -v`); `Proc.works` is only for version checks.
5. **Parse each format once.** `.desktop` files through `DesktopEntry` (parse, folders, entries, render). Compare exact-case keys with `compare()`, never `==`: strings compare case-insensitively on MatchBox.
6. **Name exit codes by intent** (`out.usage` 2, `out.precondition` 4, `out.failed` 6) and do not invent new ones; the table in the command contract is the only list. An unknown command or flag exits 2.
7. **Every file BxRig writes goes through `ConfigService`** (backup, atomic replace, journal), and the config folder comes from `Env`.
8. **Respect the MatchBox quirks in shared code:** no base classes (compose and delegate), a class must not `new` its own class (stack overflow at load), no closures that call class methods, no postfix operators on indexes, build large struct literals stepwise, check a JSON key exists before reading it, and never name a variable like a function of the same class (`info = ...` hides `function info`).
9. **Tests source `tests/lib/harness.sh`** and do not define `fail`, `code` or the temp-dir trap again (ratchet). Tests are found by name; `tests/run-all.sh` runs them all and `tests/dry-test.sh` fails when a test file is not listed in `.github/workflows/ci.yml`.
10. **Data files are resources, a few files are generated.** The catalog, templates, themes, skills, wizard pages, brand images and `cli.json` are packed into the binary from `src/resources/` (links to the real folders): edit the file, nothing to regenerate. `Version.bx`, `WallpaperData.bx`, `CommandFlagData.bx`, `docs/reference/commands.md` and `command-flags.md` are generated: change the source (`docs/reference/cli.json` is the curated one), run the `bootstrap/gen-*.sh`, commit both; CI runs them with `--check`.
11. **One format, automated.** Tabs for indentation (shown 4 wide), LF, one final newline, no trailing spaces; JSON in the standard layout with tabs. Run `bash scripts/format.sh` before every commit and make sure `bash scripts/format.sh --check` passes: it is the first thing CI job 1 runs, a failure there skips every other job (`tests/dry-test.sh` runs the same check, and `git config core.hooksPath .githooks` installs a pre-commit hook that does). YAML keeps spaces (YAML does not allow tabs) and Markdown keeps its indentation. Your editor picks the settings up from `.editorconfig`.
12. **A new command is an entry in `docs/reference/cli.json`** (summary, usage, examples, flags with types, whether it needs `--yes`) and a `case` in `src/Main.bx`; `gen-docs.sh` fails when the two disagree. Usage text is `new bxrig.CommandSpec().usage( "name" )`, never a string.
13. **Plans and dry runs are `Out.plan`** (`util/Mutation`): no wording of "Nothing was changed" outside it (ratchet). A command that changes none of your files and only starts a program or flips your own setting acts at once and documents it.
14. **A key is a row of the one table in `Shortcuts.bx`**, with a Traditional and a Mac key; then run `keys conflicts` in both styles (`tests/shortcuts_test.bxs` does). A key that runs a command is `bx( ... )` with the words after `bxrig`, so `keys run ID` and the runner can run it, and the command gets a runner entry in `MenuTree`.
15. **Start a program in the background with `Proc.detach`**, not another `setsid` string.

The shared helpers are in `src/bxrig/util/`: `Cli`, `Out`, `Exit`, `Mutation`, `Proc`, `Env`, `Text`, `Fmt`, `Names`, `JsonStore`, `SystemFile`, `SystemdUnit`, `Systemd`, `Pacman`, `Aur`, `Http`, `Urls`, `Desktop`, `DesktopEntry`, `Ini`, `Props`, `Lua`, `Version`. The TUI helpers are `Modal`, `KeyMap` and `IntentRunner`. All of them are built; copy what they do, not the old copies.

## Local setup

BxRig needs a MatchBox that has the fixes from the MatchBox `bxrig` branch. One script sets it up:

```bash
scripts/setup-local.sh                      # asks which MatchBox to use
scripts/setup-local.sh --matchbox edge      # or pick one without the question
```

| Choice | What it does | Needs |
|---|---|---|
| `stable` | Installs the released MatchBox with `mvm install latest`. It cannot build BxRig until the `bxrig` fixes ship. | `mvm` |
| `edge` | Downloads the `bxrig` branch build CI publishes (`scripts/get-matchbox.sh`) into `.cache/matchbox/`. | `curl`, `jq` |
| `source` | Clones `../matchbox` on branch `bxrig`, or reuses it, and builds it with `cargo build --features bif-tui`. A clean `bxrig` checkout is pulled first; any other branch or local changes are built as they are. | `git`, Rust |

The script saves the choice in `.cache/dev.env` (gitignored), builds `dist/bxrig` and runs a smoke test. `--no-build` only saves the choice. Run it again to switch. `scripts/dev-build.sh` and `tests/run-all.sh` read `.cache/dev.env`; a `MATCHBOX=/path/to/matchbox` variable overrides it.

Use `source` when you also work on MatchBox: change `../matchbox`, rebuild it with `cargo build --features bif-tui`, then rebuild BxRig.

### Testing with another MatchBox branch

To try a MatchBox pull request, a fork or any other branch, name it. The script clones that branch shallow (depth 1) into its own folder and builds it, so your `../matchbox` working tree is never touched:

```bash
scripts/setup-local.sh --matchbox-branch develop                         # ortus-boxlang/matchbox, branch develop
scripts/setup-local.sh --matchbox-branch feature/x --matchbox-repo someone/matchbox   # a fork (owner/name or a full https URL)
scripts/setup-local.sh --matchbox-branch v0.14.0 --release                # a tag, release build
scripts/setup-local.sh --matchbox-branch 0123456789abcdef0123456789abcdef01234567    # a commit: the full 40 character id
BXRIG_MATCHBOX_BRANCH=develop scripts/setup-local.sh                      # the same, from the environment
```

- `--matchbox-branch REF` takes anything `git clone --branch` accepts (branch or tag); a full commit id is fetched by itself. `--matchbox-repo REPO` is `owner/name` on GitHub or a full `https://` URL and defaults to `toolchain.matchbox.repo` in `box.json`. `BXRIG_MATCHBOX_BRANCH` and `BXRIG_MATCHBOX_REPO` do the same; the flags win. Values may contain only letters, digits and `. _ / @ + -` (a repo URL also `:` after `https`), may not start with a dash and are passed to git as arguments, never through a shell.
- A branch other than the one in `box.json` (`bxrig`) or a repo other than the manifest repo means a source build. The clone lives in `.cache/matchbox-src/<repo>-<ref>` (for example `ortus-boxlang-matchbox-develop`) and is refreshed with a shallow fetch when it exists. Pass `--release` for an optimized MatchBox (the default is a debug build, as for `source`); both are built with `--features bif-tui`.
- `--matchbox edge` is the published build of the `bxrig` branch only; combined with another branch or repo it stops with an explanation. `--matchbox source` without a branch is still `../matchbox`.
- `.cache/dev.env` records `MATCHBOX` (the path), `MATCHBOX_REPO`, `MATCHBOX_REF` and `MATCHBOX_COMMIT`, which `scripts/dev-build.sh` and `tests/run-all.sh` use. Switch back with `scripts/setup-local.sh --matchbox edge`.
- A branch can report another version than `box.json` (`toolchain.matchbox.version`). For a branch build that is a warning naming both versions, from `setup-local.sh` and `scripts/dev-build.sh`, and the build goes on. The published `edge` path still refuses a MatchBox with the wrong version.
- `scripts/get-matchbox.sh DEST --ref REF --repo REPO` does the same for scripts and CI: it builds that ref from source (release, no `--locked`) and writes `DEST` and `DEST.info` (with a `repo=` line). Without those options it behaves as before.
- Asked without any option, the script offers a fourth choice, `any GitHub branch`, and asks for the repo and the branch.

## Running the tests

```bash
scripts/dev-build.sh                      # rebuild dist/bxrig after a change
tests/run-all.sh                          # every shell and .bxs test (JOBS=3 by default)
tests/run-all.sh dist/bxrig theme         # only the tests whose name contains "theme"
bash tests/time-test.sh dist/bxrig        # one shell test
tests/run-all.sh dist/bxrig init_plan     # one .bxs test (runs from source, no build needed)
bash tests/dry-test.sh                    # the ratchet: banned patterns and the CI list
```

Shell tests (`*-test.sh`) run the binary against fake tools and need no root, so rebuild before running them. The `.bxs` unit tests run from `src/` and need no build. `wizard-test` is timing sensitive; run it alone with `JOBS=1` if it fails. Try a command by hand with `dist/bxrig COMMAND --dry-run`.
