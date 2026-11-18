---
title: Getting started
order: 2
summary: Install BxRig, run the wizard, and find your way around.
---

# Getting started

## What you need

**Supported today: CachyOS and Arch Linux. Other distributions (Debian, Ubuntu, Fedora) are the direction, not yet supported.**

- CachyOS or Arch Linux (a system with `pacman`), x86_64.
- A normal user with `sudo`. The installer refuses to run as root.
- A network connection.

## Install

```bash
curl -fsSL {{ installUrl }} | bash
```

The installer:

1. checks the machine;
2. downloads the program and the install bundle for your [channel](guides/updates.md) and verifies their signature and SHA-256;
3. installs packages, toolchains (Java 21, `bvm`, `mvm`, BoxLang, MatchBox, Rust) and the core apps;
4. starts the [setup wizard](guides/wizard.md).

Its log is `~/.cache/bxrig/install.log`.

### Without anyone at the keyboard

```bash
curl -fsSL {{ installUrl }} | bash -s -- --yes --answers answers.json
```

`--yes` never asks (it needs passwordless sudo). Without `--answers`, the wizard's default answers are applied. More options: `--channel stable|beta`, `--no-wizard`, `--dry-run`, `--source` and `--matchbox-branch` (below).

### Which MatchBox builds the program

BxRig is compiled with MatchBox, taken from the `bxrig` branch of the MatchBox repository (`toolchain.matchbox` in `box.json`). The installer reads the branch head (`git ls-remote`, or the GitHub API when git is missing) and installs the build published for exactly that commit, `<version>-<commit>/` under `downloads.ortussolutions.com/ortussolutions/bxrig/matchbox/`. The older `version-latest.properties` pointer is not used, because it can lag a day behind the branch (a stale build lacks capabilities the modules need, and bx-image then fails to load).

- **The head is not published yet** (CI is still building it): the install stops with exit 1 and names the missing build. Try again in a few minutes, or install a build of your own with `BXRIG_MATCHBOX_FILE=PATH`, or build the head here with `--matchbox-from-source`.
- **The head cannot be read at all** (no network to GitHub): the build named in `version-latest.properties` is used, with a warning.
- **`--matchbox-branch REF`** (or `BXRIG_MATCHBOX_BRANCH`) picks another branch of the MatchBox repository (letters, digits and `. _ / @ + -`, no leading dash). Other branches have no published builds, so it needs `--matchbox-from-source`: the branch is cloned shallow and built with `cargo build --release --features bif-tui` (Rust is set up by the packages stage that runs before). Its version can differ from the one in `box.json`; the installer warns.
- Run again later and the installer replaces a MatchBox that is behind the branch head. `install.sh toolchains --yes [--matchbox-branch REF] [--matchbox-from-source]` re-runs just this stage.

### Testing a branch

```bash
curl -fsSL https://downloads.ortussolutions.com/ortussolutions/bxrig/install.sh | bash -s -- --source github:ortus-boxlang/BxRig@development --yes
```

`--source SPEC` (or `BXRIG_SOURCE`) says where BxRig comes from:

| SPEC | Meaning |
|---|---|
| `stable` | The default: the signed release |
| `beta` | The same as `--channel beta` |
| `github:OWNER/REPO@REF` | A branch, tag or commit of a GitHub repository. `github:@REF` and `github:REF` mean `ortus-boxlang/BxRig` |

A GitHub source is **unsigned**: no release signature and no checksum from the BxRig downloads. The installer prints a warning, and continues only with `--yes` or after you type the word `unsigned` (without either it stops with exit 2 and changes nothing). It downloads `https://codeload.github.com/OWNER/REPO/tar.gz/REF` (public repositories; for a private one set `GITHUB_TOKEN` or `GH_TOKEN`, which is sent to GitHub only as a request header and never printed or logged), unpacks it, and runs that tree's own `bootstrap/install.sh` stages: packages, toolchains, the program built from the tree's `src/Main.bx` with the MatchBox above, the core apps, then the wizard from the freshly built program. `--dry-run` downloads and unpacks the tree, prints the commit and the tree's plan (including the MatchBox build), and installs nothing.

The source (`github:OWNER/REPO@REF`) and the resolved commit are written to `~/.cache/bxrig/install.log` and to `~/.local/share/bxrig/install-source`. `bxrig update` does not read them: it compares the program with the channel's release, so after a GitHub install `bxrig update check` reports an update, and `bxrig update apply --yes` replaces your build with the stable (or beta) one. Skip `update apply` while you test the branch.

## After the install

| Do this | With |
|---|---|
| See what is set up | `bxrig status` |
| Change your choices | `bxrig init` |
| Open the control center | `Super+Space` or `bxrig menu` |
| See every shortcut | `Super+K` or `bxrig keys sheet` |
| Check for updates | `bxrig update check` |

New to BoxLang? Run `bxrig boxlang welcome` for a getting-started page, or open [Try BoxLang](https://try.boxlang.io).
