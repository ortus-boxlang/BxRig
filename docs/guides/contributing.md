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
10. **Generated files stay generated** (`*Data.bx`, `HelpData.bx`, `CommandFlagData.bx`, `docs/reference/commands.md`, `command-flags.md`, `TemplateData.bx`): change the source (`docs/reference/cli.json` is the curated one), run the `bootstrap/gen-*.sh`, commit both; CI runs them with `--check`.
11. **A new command is an entry in `docs/reference/cli.json`** (summary, usage, examples, flags with types, whether it needs `--yes`) and a `case` in `src/Main.bx`; `gen-docs.sh` fails when the two disagree. Usage text is `new bxrig.CommandSpec().usage( "name" )`, never a string.
12. **Plans and dry runs are `Out.plan`** (`util/Mutation`): no wording of "Nothing was changed" outside it (ratchet). A command that changes none of your files and only starts a program or flips your own setting acts at once and documents it.
13. **A key is a row of the one table in `Shortcuts.bx`**, with a Traditional and a Mac key; then run `keys conflicts` in both styles (`tests/shortcuts_test.bxs` does). A key that runs a command is `bx( ... )` with the words after `bxrig`, so `keys run ID` and the runner can run it, and the command gets a runner entry in `MenuTree`.
14. **Start a program in the background with `Proc.detach`**, not another `setsid` string.

The shared helpers are in `src/bxrig/util/`: `Cli`, `Out`, `Exit`, `Mutation`, `Proc`, `Env`, `Text`, `Fmt`, `Names`, `JsonStore`, `SystemFile`, `SystemdUnit`, `Systemd`, `Pacman`, `Aur`, `Http`, `Urls`, `Desktop`, `DesktopEntry`, `Ini`, `Props`, `Lua`, `Version`. The TUI helpers are `Modal`, `KeyMap` and `IntentRunner`. All of them are built; copy what they do, not the old copies.

## Running the tests

```bash
bash scripts/dev-build.sh                 # build dist/bxrig with the local MatchBox
bash tests/run-all.sh                     # every shell and .bxs test (the `.bxs` ones run from `src/` with `matchbox ../tests/NAME_test.bxs` and need no native build) (JOBS=3 by default; wizard-test is timing sensitive, run it alone if it fails)
bash tests/time-test.sh dist/bxrig        # one test
bash tests/dry-test.sh                    # the ratchet: banned patterns and the CI list
```
