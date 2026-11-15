---
title: Port status
order: 90
hidden: true
---

# BxRig port status

State on 2026-11-15 (version 0.11.0-dev, MatchBox 0.14.0 from the `bxcachy` branch). The legacy v0.10.0 (Python and shell) tree is kept in `artifacts/legacy/` as a feature reference only.

## Built on `development`

- One native executable written in BoxLang (`src/Main.bx` plus 152 classes in `src/bxrig/`), compiled by MatchBox: 96 commands in 7 groups (`docs/reference/cli.json`), each with `--json`, `--yes` or `--dry-run` where it changes something, and the exit codes of the [command contract](COMMAND-CONTRACT.md).
- The desktop: `setup hyprland|plasma|terminal|shell|xremap`, the one shortcut table in two styles, the menu (`menu`), the runner abstraction, themes, appearance, display, power, time, screenshots, recording, clipboard, notifications, dictation, Quick Look.
- Install and update: the signed one-line installer, channels, `update`, `refresh`, `reinstall`.
- Developer tools: Java, BoxLang, MatchBox, databases and vector stores, virtual machines, containers, agent skills, the mail catcher, secrets.
- Data and safety: the catalog (289 apps), the config service with backup, journal and drift checks, BxRig setup snapshots, system snapshots, file backups, NAS, BxTimeMachine.
- The terminal UIs: the setup wizard and the Control Center on MatchBox's terminal canvas.
- Tests: 75 script tests with fake tools, 35 `.bxs` unit tests, a ratchet (`tests/dry-test.sh`), a real Arch container suite (`tests/arch/`), and CI that builds the binary and runs them.

## Not verified yet

Features that need real hardware or a live desktop are covered by tests against fake tools only: Hyprland and Noctalia on a running session (the generated Lua module, the quake workspace, the webcam window rule), HyprKwin and KWin scripting, xremap on both builds, KVM virtual machines, GPUs, the signed install from the download bucket, and a full run on a clean CachyOS machine. The contract lists them per feature. Nothing here claims a real-machine acceptance.

## Reference tree

`artifacts/legacy/original/` holds the v0.10.0 source (44 executables, 20 tests). The migration tracking table in `plan.md` section 17 is the 2026-11-08 audit; the native commands are listed in the reference, and a command-by-command parity audit against the legacy tree has not been redone since.
