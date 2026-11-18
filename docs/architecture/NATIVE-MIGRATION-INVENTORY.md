---
title: Native migration inventory
order: 91
hidden: true
---

# Native migration inventory (v0.10.0)

The legacy archive has 44 executables and 20 test files (`artifacts/legacy/original/`). The native program covers its areas with 96 commands; see [Port status](PORT-STATUS.md) for what is built and what has not run on a real machine.

## Workstreams and where they live now

1. Installer, provisioning, first run, menus and profiles: `bootstrap/install.sh`, `init` (the wizard), `menu`, `profile-*`, `install`.
2. App catalog, package manager, developer tools and extras: `catalog`, `install`, `pkg`, `apps`, `java`, `sdk`, `boxlang`, `toolchain`.
3. Desktop, themes, icons, keyboard shortcuts and desktop tools: `setup`, `keys`, `theme`, `appearance`, `display`, `runner`, `layout`, `assets`.
4. AI, databases, VMs, Podman and networking: `ai`, `secrets`, `db`, `vm`, `containers`, `dns`, `vpn`.
5. Cloud storage and backups: `cloud`, `backup`, `nas`, `timemachine`.
6. Quick Look, dictation and system integration: `quicklook`, `dolphin`, `dictation`, `system`, `security`, `power`, `time`.
7. Native MatchBox build, TestBox-style unit tests and Arch integration CI: `scripts/dev-build.sh`, `tests/`, `tests/arch/`.

## Acceptance gates

- No Python runtime is needed by any production command.
- Java 21, bvm, mvm and MatchBox are installed by the bootstrap; versions are named in `box.json`.
- CI compiles the executable, runs the tests against it and publishes it.
- A real clean CachyOS run is still the open gate.
