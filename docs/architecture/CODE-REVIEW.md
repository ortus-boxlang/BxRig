---
title: Code review, DRY and encapsulation
order: 92
hidden: true
summary: Developer reference. Where the same logic exists more than once, where a concept has no single home, and the plan to fix it.
---

# Code review: repeat yourself never, one home per concept

Read-only review of the tree on 2026-11-14 (HEAD `5beb9a1`, `development`). Nothing was changed except this file.
Numbers come from `grep` and `wc` over `src/`, `tests/`, `docs/`, `bootstrap/` and `.github/`; each can be re-run (appendix A).

Scope: `src/Main.bx` (1018 lines), `src/bxrig/*.bx` (137 classes, about 24,600 lines, of which about 3,850 are generated `*Data.bx`), 74 shell tests, 20 `.bxs` tests, 8 generators.

## Status of the refactor (updated 2026-11-14)

Phases 0 to 5 are done and pushed to `development` (commits `a106a30` for phases 0 and 1, `00ba305` for phases 2 to 5). The six partly done findings are now finished (F08 `ba6e1c4`, F13 `cec1e56`, F23 `7f387fb`, F24 `9ee26b8`, F25 `3950e71`, F27 `aee4e82`); the other deferred phases are listed below with their reasons. Behaviour is unchanged except for the bug fixes listed here, each with a test.

| Finding | Status | Where |
|---|---|---|
| F01 `Cli.say` / `Out` | **done**: 57 files migrated; `say` 54 to 2 definitions (`Cli`, `Out`), `fail` 17 to 2; the three text printers renamed `progress` (ConfigService, KeysService) and `flash` (TimeMachineApp). | `util/Cli.bx`, `util/Out.bx`, `out_test.bxs` |
| F02 `Proc` | **done**: `tryExec` 33 to 0, `has` 28 to 1 (`Proc`), `Installer.hasCommand` is now `command -v` (was `--version`, which ran the tool); `TuiSys.has` shell-string bug and the 5 run-myself paths are gone (`Proc.self`). Left for phase 8: direct `systemExecute` calls for interactive commands, `curl`, `pacman -Qq` and similar (see F09, F11). | `util/Proc.bx`, `proc_test.bxs`, `installer_test.bxs` |
| F03 `Env` | **done**: `home`/`env`/`self`/`dataHome` copies removed; one precedence rule; `XDG_CONFIG_HOME` is honoured by every config path (it was ignored by the config service); `dataHome` split into `data()` and `xdgData()`. | `util/Env.bx`, `env_test.bxs`, `paths-test.sh` |
| F04 `Mutation` | **done** (CR3 phase 6, `Out.plan`): `util/Mutation.bx` is the plan/dry-run/run protocol (plan exit 2, dry run exit 0, first failure exit 6) and the one place that words a plan: `show( title, data, asJson, dry, extra, hint )` prints "Plan: TITLE" (or "Dry run: TITLE"), the extra lines and "Nothing was changed. Add --yes to apply." (`hint` changes the last sentence: "to install", "to delete"); `banner( dry )` and `footer( dry, hint )` are its two parts for the plans a command builds line by line. `Out.plan( ... )` is the call (`variables.cli.scoped( cmd ).plan( ... )` where a class has no `Out`). The about 70 plan blocks of 43 commands (the `if ( !yes ) return say( ..., "plan", ... )` lines, the `lines.append( dry ? "Nothing was changed." : ... )` footers, the Java and Sdk blocks) call it; a ratchet forbids the hand-written footer. Wording changes: the Java and Sdk dry runs read "Dry run: TITLE" and "Nothing was changed." (they read "Plan: ..." and "Dry run: nothing was changed."), the dictation dry run sets `dry_run` in the JSON. Not done: the 15 "Run as a regular user" sentences (`SetupPlan` x10 and others: each has its own tail). | `util/Mutation.bx`, `util/Out.bx`, `util_plan_test.bxs`, `dry-test.sh` |
| F05 `JsonStore` | **done for the settings and state files** (CR3 phase 4): `util/JsonStore.bx` (`read` with defaults, `load`, `write` through the config service, so the files get a backup and a journal entry). The 8 direct writers (`Appearance`, `Display`, `Theme`, `Update`, `Skills`, `Nas` x2) and 13 readers use it; the `jsonDeserialize( fileRead(` ratchet went from 37 to 24. Left as they are: `Runner.load` (throws on bad JSON on purpose), `Editor`, the Theme and Setup file edits of other programs, BackupConfig/BackupTimeline readers. | `util/JsonStore.bx` |
| F06 entries, `SystemFile`, `SystemdUnit` | **done** (CR3 phase 4): `ConfigService.entry` and `writeText` existed (F27); `util/SystemFile.bx` spells `sudo install -Dm...` and makes the private temp files (11 sites in `Nas`, `Power`, `Security`, `Time`); `util/SystemdUnit.bx` renders unit text (10 builders: `Time`, `Cloud`, `MacExtras` x2, `Update` x2, `BackupData` x2, `Nas` x2, `Shortcuts`), byte for byte what they wrote before. Ratchets: no `"install", "-Dm` and no `"[Unit]"` literal outside `util`. Root files still have no journal (they are written with `sudo`). | `util/SystemFile.bx`, `util/SystemdUnit.bx` |
| F07 `Names` | **done** (CR3 phase 3): `util/Names.bx` (`valid( kind, value )`, `rule( kind )`; kinds slug, vm, theme, label, container, secret, package, model). The 9 `validName` and the 2 inline regexes are gone. **A bad name is now exit 2 everywhere** (it was 4 in `AiModels`, `AiSession`, `Cloud`, `Db`, `Secrets`, `Vm`, `Web`); tests updated (`ai-session`, `db`, `secrets`, `vm`, `web-vpn`). Format-specific checks that are not names stay in their class (`validPart`, `validUrl`, `validHost`, `validShare`, ...). | `util/Names.bx`, `util_misc_test.bxs` |
| F08 `Text` / `Fmt` | **done** (`ba6e1c4`): `Text.merge` replaces the last 3 copies (Pkg, Update, Vm); the 4th, `SystemState.merge`, did a different job and is now `startingAnswers`. `Fmt` is the one home for sizes and ages: `bytes` (was TuiKit.size and BackupConfig.human), `kb` (was Vm.humanKb), `age` (BackupTimeline), `ageShort` (DashboardPage), `span` (was TuiSys). The callers keep their method name and forward to it. | `util/Text.bx`, `util/Fmt.bx`, `text_test.bxs`, `fmt_test.bxs` |
| F09 `Pacman` and `Aur` | **done** (CR3 phase 2): `util/Pacman.bx` builds the argv (`installArgv`, `removeArgv`, `upgradeArgv`, `installLine`) and answers the queries (`installed`, `installedNames`, `explicit`, `foreign`, `isInstalled`, `known`, `info`, `search`, `searchNames`, `version`, `versions`); `util/Aur.bx` is the AUR helper (`installArgv`, `upgradeArgv`, `available`, `rpc`). 27 classes use them; the 70 spelled `pacman` and `yay` argv lists are gone. | `util/Pacman.bx`, `util/Aur.bx`, `util_tools_test.bxs` |
| F10 `Systemd` | **done** (CR3 phase 2): `util/Systemd.bx` (`enableArgv`, `disableArgv`, `stopArgv`, `reloadArgv`, `powerArgv`, `active` for `is-active --quiet`, `state` and `isActive` for the printed text, `enable`, `disable`, `stop`, `reload`). 16 classes use it. | `util/Systemd.bx`, `util_tools_test.bxs` |
| F11 `Http` | **done** (CR3 phase 2): `util/Http.bx` (`get`, `download`, `request` for a local service with its status code, `getArgv`, `downloadArgv`, `installerArgv` for vendor scripts). Mail, Skills, Update, Boxlang, Java, Sdk, Strata, Pkg (AUR RPC), Installer, SetupPlan use it. Two shell-script downloads stay on purpose: `ImageCache` (a detached background script with size and protocol limits). | `util/Http.bx`, `util_tools_test.bxs` |
| F12 desktop and engine detection | **done** (CR3 phase 3): `util/Desktop.bx` (`raw`, `name`, `session`, `inHyprland`, `inPlasma`, `shell`, `shellOf`) is the only reader of `XDG_CURRENT_DESKTOP`, `HYPRLAND_INSTANCE_SIGNATURE` and `XDG_SESSION_TYPE`; `BXRIG_DESKTOP` now steers every class (it steered two). `Resolver.detectShell` is gone. The container engine is asked of `Db` (`engineSetting`, `engineCli`); `Vm` and `SystemState` no longer read `db.json`. Ratchet in `dry-test.sh`. | `util/Desktop.bx`, `Db.bx` |
| F13 `CommandSpec` and `Options` | **done** (`cec1e56`): `cli.json` is the registry (93 commands, 246 flags with types). `CommandSpec` answers flags and usage; `Main.bx` checks every run's flags per command (unknown flag: exit 2, the usage line printed; `secrets run` passes through; the check only runs when there are flags) and the 122-entry global whitelist is gone. `gen-docs.sh` also writes `docs/reference/command-flags.md` for review and the small `CommandFlagData.bx` that the check reads, and fails when a usage line names a flag the command does not list. 117 of the 135 hand-written `"Usage: bxrig"` strings in `src/` now come from the registry (`new bxrig.CommandSpec().usage( "pkg remove" )`); 18 stay because they are built with `&` or carry an explanation in brackets. The nested usage lines of `backup`, `appearance`, `plasma` and `ai` were rewritten one variant per line so each carries its full prefix. | `CommandSpec.bx`, `CommandFlagData.bx`, `command_spec_test.bxs`, `command-spec-test.sh`, `tools/infer-command-flags.py`, `tools/use-command-spec-usage.py` |
| F14 Main logic | **done for the cases named** (CR3 phases 3 and 6): the `catalog` case moved to `CatalogCmd`, the `config` case to `ConfigCmd` (with `diff` through `Proc`), the `wizard` case to `WizardCmd`; the `version` case is `Brand.show( cli, version, asJson, terminal )` (logo, tagline, the JSON envelope) and `runner show` is `Runner.show( asJson )`. Not moved: `config list` still shows only what `Managed` lists; the rest of the `runner` case (list, doctor, select, set) is still in `Main`. | `CatalogCmd.bx`, `ConfigCmd.bx`, `WizardCmd.bx`, `Brand.bx`, `Runner.bx` |
| F15 version single source | **done** (CR3 phase 3): `bootstrap/gen-version.sh` writes `util/Version.bx` from `box.json` (`--check` in CI, run by `dev-build.sh`); `Main`, `SystemState` and `Cli.version()` use it; `native-smoke.sh` reads `box.json`. `bootstrap-test.sh` keeps its own fixture strings on purpose. | `util/Version.bx`, `bootstrap/gen-version.sh` |
| F16 page registry, `ProviderSpec` | **done** (CR3 phase 5): `ControlCenterPages.make( id, demo, dashboard )` builds the page of an id and `ControlCenter.buildPages` is a loop over the registry; `ProviderSpec` gives `live`, `refreshSeconds` and `detailLines` their defaults, so the 39 boilerplate lines are gone from the 14 providers (only `Packages` and `Mail` override). The old `return 0;`, `return 2;` of those lines had been turned into `Exit().ok()` and `usage()` by the F25 script: they are counts, not exit codes, and are plain numbers again. `TuiSys` was already gone (F27); `Launchers.folders` still names pages by string. | `ControlCenterPages.bx`, `ProviderSpec.bx`, `tui_helpers_test.bxs` |
| F17 `DesktopEntry` | **done**: 3 parsers to 1, 5 writers to `render`, one folder list (`BXRIG_APPS_DIRS`, older `BXRIG_DESKTOP_DIRS` still read); exact-case keys; the Apps page hides BxRig's launchers, the `apps` grid keeps them. | `util/DesktopEntry.bx`, `desktop_entry_test.bxs` |
| F18 `Props`, `Ini`, `Lua` | **done** (CR3 phase 6): `util/Props.bx` (`pairs`, `parse`, `unquote`, and `exports` for shell `export NAME='value'` text and .env files: `export ` dropped, `'\''` read as the shell does) replaces `Secrets.parseEnv` (Secrets only checks the names with `Names`). `util/Ini.bx` is the one reader of `[section]` files (`sections`, `values`, `get`, `last`, with `exact` for case-sensitive keys) and the one line editor (`set( lines, section, key, value )`): `Session.current` and `autologin`, the SDDM state-file rewrite in `SetupPlan` and `DesktopEntry.parse` use it (the three section walkers are gone). `util/Lua.bx` (`binds( text )`) is the scan of `hl.bind( ... )` lines that `KeysEditor.userBinds` had inline. Ini and Props now trim a key (`Name = x` reads as `Name`). | `util/Props.bx`, `util/Ini.bx`, `util/Lua.bx`, `util_misc_test.bxs` |
| F19 shortcut table completeness | **deferred on purpose**: the owner is deciding the Traditional and Mac key styles and the five Mac collisions (`Super+B/F/V/S/Comma`). Nothing in `Shortcuts.bx` or `KeysEditor.bx` changed except the generated Lua also reading `XDG_CONFIG_HOME`. | |
| F20 Shortcuts split | **deferred** (phase 10), after F19. | |
| F21 `Modal`, `KeyMap`, `IntentRunner` | **partly done** (CR3 phase 5): `Modal` holds the key rules of the confirm and text boxes (`answer`, `typed`, `lines`), used by `ControlCenterApp` and `TimeMachineApp`; `IntentRunner` holds what the Control Center does with an intent (`handle`, `runCli`, `withFlag`) and `TimeMachine.runCli` uses it. Not done: a `Modal` that holds the state itself (the two apps keep their own modes, which differ), and `KeyMap` (footer hints and dispatch from one table). | `Modal.bx`, `IntentRunner.bx`, `tui_helpers_test.bxs` |
| F22 view forwarders | **done** (CR3 phases 5 and 6): `TuiKit.starPositions` is the one star generator (Wizard 46 stars, Time Machine 40) and both views read the palette from `TuiKit.color`. The one-line forwarders of `WizardView` (`mix brand shimmer c put fillRect gtext wrap panel`) and `TimeMachineView` (`mix brand shimmer put fillRect gtext trunc hit size`) are gone: the 170 call sites use `variables.kit` directly (a ratchet forbids new ones). `hitAt` stays on the views because the run loop calls it. | `TuiKit.bx`, `WizardView.bx`, `TimeMachineView.bx`, `dry-test.sh` |
| F23 test harness | **done for the plain shape** (`7f387fb`): 70 of 75 shell tests source `tests/lib/harness.sh` (header, `fail`, `code`, `tmp` with its trap, the `BXRIG_TEST_LIB` path); `fail() { echo "FAIL` went from 67 copies to 4 (the harness, `native-package-integration.sh`, `web-install-test.sh` and the ratchet line). Not migrated: `bootstrap-test.sh`, `config-test.sh`, `package-manager-test.sh`, `web-install-test.sh` take no binary, and `dry-test.sh` is not a binary test. The three pty tests (`wizard`, `init`) wait for the first screen with `tests/lib/pty_ready.py` instead of a fixed sleep: native start is now 1.6 to 2.2 s, and the old 1.2 and 1.5 s waits made them fail. CR3 leftovers: `stub_id`, `stub_sudo` and `stub_sudo_log` in the harness replace 28 copies of the `id` and `sudo` fakes; the `pacman` fakes differ per test and stay. | `tests/lib/harness.sh`, `tests/lib/pty_ready.py`, `tools/migrate-test-to-harness.py` |
| F24 test discovery | **done** (`9ee26b8`): running and checking by discovery was already done; `tests/lib/Check.bx` is now the one kit of the 27 `.bxs` tests (`check`, `done`, `tmp`, `sh`, `text`, `touch`, `read`, `frame`), found as `new lib.Check()` from the script's folder. The variable that holds it is `testkit`: a variable named `T` collided with a test's own `t` (names are case-insensitive). A ratchet limits `function check( label, ok )` in tests. | `tests/lib/Check.bx`, `tests/dry-test.sh` |
| F25 named exit codes | **done** (`3950e71`, CR3 phase 6): `util/Exit.bx` holds the table (`ok negative usage plan timeout precondition official failed partial conflict internal update`). `Cli.say`, `Cli.fail`, `Out.say` and `Out.fail` take a name or a number (an unknown name throws); 859 `say`/`fail` call sites and 79 `CLIExit( N )` calls in `Main.bx` use names, plus 66 `return N;` in functions that return exit codes (`return new bxrig.Exit().usage();`). The numbers on the wire are unchanged. CR3 leftovers: the 25 `return 2;`, `3;`, `4;` that print and return an exit code now use the names (and a ratchet forbids new ones); CR3 phase 6 named the last ones that are exit codes: the 28 `return 0;` of `Menu` (every flow returns the exit code of the command it started), `Db.menu`, `Apps`, `Assets`, `Status`, `Setup.status`, `Packages.listApps`, `ControlCenter`, `TimeMachine.run`, `Dolphin` (failed) and the `return 8;`/`return 0;` of `ConfigService.configWrite` (conflict, ok). What remains are not exit codes: "no pick" and counts (`Runner.select`, `WizardApp` step helpers, `Power.meminfo`, `Vm.duKb`, `Notify`, `BackupTimeline`, `MailProvider.refreshSeconds`), and `130` (Ctrl+C); a ratchet in `dry-test.sh` fails on any new bare number as the code argument of `say`/`fail` and on `CLIExit( N )` (130 allowed). | `util/Exit.bx`, `util/Cli.bx`, `util/Out.bx`, `tools/name-exit-codes.py` |
| F26 `Urls`, `Env` names, icon names | **done** (CR3 phase 6): `util/Urls.bx` holds the first-party hosts (phase 3). `util/Env.bx` now lists every environment variable BxRig reads by a short name (`names()`; `named( "powerDir", fallback )`, an unknown short name throws): the 79 `getSystemSetting` calls and the `environ.get( "BXRIG_..." )` literals of 53 classes use it, and a ratchet allows `getSystemSetting` only in `Env`. Page icon names are `ControlCenterPages` (`icon( id )`); the 16 providers and pages ask it instead of spelling "cube", "coffee", ... (a ratchet forbids `function icon() { return "..."; }`). An empty variable now means the fallback everywhere (it used to mean "" for the direct reads). | `util/Env.bx`, `ControlCenterPages.bx`, `dry-test.sh` |
| F27 encapsulation leaks | **done** (`aee4e82`, item 7 in CR3 phase 5): 1. `Shortcuts` asks `Env` for its file. 2. `ConfigService.entry` and `writeText` replace the entry structs built in `KeysEditor`, `Ai` and `Secrets` (4 sites). 3. `TuiSys` is removed: `Proc.run` and `Proc.selfData`, `Fmt.span`; `AppsData` and the 12 providers use them. 4. `Managed.entries` owns the managed-file list that `Main.bx` built, and (CR3 phase 6) `Managed.components()` and `Managed.entriesFor( component, opts )` own the grouping of files by refresh component (starter configs, terminal starters, shell files): `Refresh` only turns those entries and its own commands into units. 5. 28 classes that used `Installer` only to get a `Proc` create a `Proc`; the 12 that used `Installer.exec` (which threw) now call `inst.proc().exec` (CR3 leftovers: 74 call sites, `Installer.exec` removed, `Installer.run` no longer crashes on a missing program). 6. `variables.cfgSvc` and `variables.cfg` are `variables.config` (8 classes). 7. `ControlCenter.handle` mutating the app and running processes is now `IntentRunner.handle` (CR3 phase 5). | `Managed.bx`, `ConfigService.bx`, `util/Proc.bx`, `util/Fmt.bx` |

### The util package (CR3 phase 1)

Shared helpers live in `src/bxrig/util/` and are reached as `bxrig.util.NAME`: `Cli`, `Out`, `Exit`, `Proc`, `Env`, `Text`, `Fmt`, `DesktopEntry`. A command class (`bxrig.Pkg`, `bxrig.Time`, ...) never holds a helper's job; a helper never holds a command's job. Every new shared helper (`Pacman`, `Aur`, `Systemd`, `Http`, `Names`, `JsonStore`, `Mutation`, ...) goes into this folder. The move changed no behaviour: only the class path (`new bxrig.util.Proc()`); nested packages build and load under MatchBox (checked before the move).

Phase 2 (external tools) also adds a ratchet in `tests/dry-test.sh`: no argv list that starts `pacman`, `yay`, `curl` or `systemctl` outside `src/bxrig/util`.

### Behaviour changes made on purpose

- An unknown command exits 2 (it exited 0).
- `Installer.hasCommand` and every `has` mean `command -v`; a tool that has no `--version` is now found, and the tool is never run to find out.
- `XDG_CONFIG_HOME` is honoured everywhere (the config service, journal-free files, menus, nvim, strata, the generated Lua); `XDG_STATE_HOME` too. With neither set nothing moves.
- The Apps page (`bxrig tui apps`) reads `/usr/local/share/applications` as well as the other folders; `.desktop` type and keys are compared exact-case.
- `tests/capture-notify-test.sh` expected 38 lines in the key sheet; the sheet has 55 (17 unbound page rows are listed on purpose), so the expectation was fixed. It was already failing before this work.

### Test results

Full run of `tests/run-all.sh` on the final build: 97 of 99 pass. `bootstrap-test.sh` fails in this sandbox (no pacman, unrelated to this work: it fails the same way without the refactor) and `wizard-test.sh` fails here with the same answers (it types before the 1.4 s native start finishes; it failed identically on the build from before the refactor). Six tests first failed only because `run-all.sh` gave them no binary argument; fixed and rerun green. Startup of the native binary went from about 1.4 to 1.7 seconds per run (extra classes loaded at start: `Env`, `Proc`, `Out`); not investigated further.

### Verified (the three "verify" items of this review)

- The `default:` branch of `Main.bx` exited 0: **true**, fixed.
- Struct keys are case-insensitive on MatchBox: **true** (`s.A` and `s.a` are one key; `Foo` and `foo` are one key).
- A `.bxs` test resolves a helper class from its own folder (`new lib.Check()` next to the script works from any working directory): **true**. Classes under `src/` are reached as `bxrig.X` when the test runs from `src/` (the CI does).
- New quirks found: a class that `new`s its own class (`Out.sub` calling `new bxrig.Out`) overflows the stack when another class loads it; and a variable named like a function of the same class (`info = getFileInfo( path )` next to `function info()`) hides the function.
- The dead Hyprland binds under xremap were not run on a real machine (still unverified).


## 0. The short version

- The code is consistent in style, and that is the problem: the same 5 to 10 helper lines were pasted into 20 to 57 classes instead of living once. Counting definitions only, about 550 lines are pure copies. Counting call sites that depend on a copy (`say(` 788, `tryExec(` 314, `has(` 143, `fail(` 267) the coupling is much bigger than the line count.
- Five copies have already **diverged** and are now behaviour bugs, not style (section 2, marked BUG): `dataHome()` means two different directories, `XDG_CONFIG_HOME` is honoured by 4 classes and ignored by the config service, two `.desktop` parsers disagree on what is an app, `has()` has two meanings, and Main accepts any flag for any command.
- Main.bx is a 1018-line `switch` that is simultaneously the command registry, the flag whitelist, the usage text store, the arity checker and, in three places, domain logic. The command list already exists once as data (`docs/reference/cli.json`) and is only checked against Main, not used by it.
- Tests: 70 of 74 shell tests define the same `fail()`; 64 define the same `code()`; 20 of 20 `.bxs` tests define the same `check()`; every new test must be registered by hand in `ci.yml` twice, in `tests/arch/suite.sh` and in the `.bxs` list.

Findings: 27 (8 high, 15 medium, 4 low). Ranked top 15 is in section 9, the phased plan in section 10, the rules for contributing docs in section 11.

## 1. Constraints that shape every proposal

BoxLang on MatchBox has quirks recorded in this repo (`COMMAND-CONTRACT.md` 13.x, `MATCHBOX-PARITY.md`, comments in `AppsModel.bx`, `Main.bx`). Every abstraction below respects them:

| Quirk | Consequence for the design |
|---|---|
| `==` on strings is case-insensitive | Anything keyed by exact case (desktop entry keys, key names `q` vs `Q`) must use `compare( a, b ) == 0`. Shared helpers must hide that, so callers cannot get it wrong (finding F17, F21). |
| Struct keys are case-insensitive (assumed from the same rule; verify on MatchBox before relying on it) | A generic INI or properties parser must not return a plain struct for case-distinct keys. Return an array of `{ key, value }` pairs plus a `get( section, key )` that uses `compare`. |
| Closures cannot call class methods | Shared helpers are called outside `.map( function ... )` bodies, or the closure receives everything it needs as arguments. No design below needs a closure to call `variables.x.y()`. Callbacks stored in structs (`ask.make`, provider `actions[].run`) already work and stay. |
| No postfix operators on indexes (`a[ i ]++`) | Counters are written `a[ i ] = a[ i ] + 1`. Relevant to `Options` (flag counting) and `Keys`. |
| Big struct literals are built stepwise | `CommandSpec` and `ProviderSpec` are assembled with `s = {}; s.yes = ...`, not one 60-key literal. The generator writes it that way (it already does for `HelpData`). |
| `extends` is used 0 times in `src/`; mixins do not exist | **No base class design.** Shared behaviour comes from small collaborator classes held in `variables.*` plus one-line delegates, the pattern `KeysService.say` and `BackupMove.fail` already use. |
| No static members | Utilities are tiny classes instantiated where used (`new bxrig.Text()`), as `new bxrig.Shortcuts()` and `new bxrig.Brand()` are today. |
| `var` declared in one `case` is not visible in another (#159) | A registry refactor of Main must give each route its own function or scope, not rely on the un-`var`ed globals Main uses today (`pk`, `cat`, `st` leak between cases). |
| A missing key of a parsed JSON struct inside `try` in a nested function panicked the native runner | `JsonStore.read` checks `structKeyExists` before every access and never reads a missing key inside its `try`. |
| `arguments.x` prefix is used everywhere | New classes keep the convention, so a sed-based migration stays mechanical. |

Unverified and needing a one-day spike before Phase 7 of the plan: whether a `.bxs` under `tests/` can resolve a helper class (script discovery looks only in the script's own directory, `MATCHBOX-PARITY.md` section 3), and whether `invoke( obj, "name", args )` works in a native build (needed only for the optional full-registry dispatch in F13).

## 2. Findings

Severity: **High** = copies have diverged (bug) or there are more than 30; **Medium** = 8 to 30 copies or a missing owner; **Low** = small, mostly cosmetic. Effort: S (under a day), M (1 to 3 days), L (a week).

### A. Plumbing copied into every command class

#### F01 (High, effort M): `say` / `fail` / envelope building, 57 files

What: Each command class re-declares how to print a result: the `--json` envelope or the human lines, then return the exit code. `Cli.envelope` is the only shared part, so every class still writes the `if ( asJson ) println( envelope ) else for lines println` branch itself.

Where (counts from `grep -h "function say"`):
- `function say( command, code, data, asJson, lines = [] )` 16 files (`Launchers.bx:67`, `Web.bx:19`, `Apps.bx`, `Menu.bx`, ...)
- `function say( code, data, asJson, lines = [], dry = false )` 14 files (`Time.bx:32`, `Appearance.bx:33`, ...)
- `...lines = [], dryRun = false` 11 files (`Vm.bx:37`, `Mail.bx:31`, ...), plus 5 more variants. 54 definitions, 8 signatures, 2 argument orders (command first or code first).
- Inline envelope without a helper: `variables.cli.envelope(` in 66 files, 96 sites; 15 in `Main.bx`.
- `fail`: 17 files, 5 shapes: `Time.bx:37`, `Appearance.bx:39`, `Mail.bx:37` (command first), `Pkg.bx:25`, `Vm.bx:43`, `BackupMove.bx:19` (delegates to another class).
- `error: ` prefix hand-written 147 times.

```
// Time.bx:32, identical in 13 other classes except the signature
function say( code, data, asJson, lines = [], dry = false ) {
    if ( arguments.asJson ) println( variables.cli.envelope( "time", arguments.code, arguments.data, arguments.dry ) );
    else for ( var l in arguments.lines ) println( l );
    return arguments.code;
}
```

Single home: `util/Cli.bx` (already injected into 71 classes as `variables.cli`; no new constructor wiring) plus a tiny bound facade `Out`.

```
class Cli {   // existing, extended
    function say( command, code, data, asJson, lines = [], dry = false )   // returns code
    function fail( command, code, msg, asJson )                            // { error: msg } and "error: msg"
    function scoped( command )                                             // -> Out bound to a command name
}
class Out {
    function say( code, data, asJson, lines = [], dry = false )
    function fail( code, msg, asJson )
    function usage( msg, asJson )          // code 2
    function precondition( msg, asJson )   // code 4
    function failed( msg, asJson )         // code 6 (see F25)
    function sub( command )                // keys set, keys reset: same class, other command string
}
```

Replaces: 54 `say` definitions, 17 `fail`, 96 inline envelope sites. Migration keeps call sites untouched by leaving a **one-line delegate** per class (`function say( ... ) { return variables.out.say( ... ); }`), removed by sed in a later step. `Cli.emitMap` stays.

Quirk limits: no base class, so every class still holds `variables.out`; the two argument orders need both `Out.say( code, ... )` and `Cli.say( command, code, ... )`. Closures never call `say`, checked.

Risk: low, output is covered by about 300 `--json | jq` assertions (`grep -c "\-\-json | jq" tests/*.sh`). The only trap is `Time.say` and others bind a constant command string while `Launchers` passes it per call.

#### F02 (High, effort M): process execution, `tryExec`, `has`, `isRoot`, run-myself, 33 + 28 files

What: "run an argv, never throw, give `{ exitCode, output }`" is written 33 times; "is this command installed" 28 times; "run `bxrig` itself" 5 ways. The class that really owns process execution is called `Installer`, so 57 files `new bxrig.Installer( runner )` just to call `.exec`.

Where:
- `tryExec`: 33 files, 5 different default timeouts (20, 30, 60, 120, 600), 2 shapes (`Pkg.bx:30` adds `timeout: false`, the others do not, so `r.timeout` is undefined in 32 classes). 42 `exitCode: 127` fallbacks in 39 files.
- `has`: 25 byte-identical lines `function has( name ) { return tryExec( [ "sh", "-c", 'command -v "$1"', "_", arguments.name ], 10 ).exitCode == 0; }` (`Time.bx:31`, `Power.bx:26`, `Nas.bx:34`, ... ); `Menu.bx:99` without try; `Sdk.bx:43`, `TuiSys.bx:22` different.
- **BUG (semantics)**: `Installer.hasCommand` runs `name --version` (30 call sites in 12 files: `Pkg`, `Packages`, `Setup` x4, `Assets`, `Time`, `Tiling`, `KeysService`, `Session`). `has` uses `command -v`. A tool with no `--version` is "missing" in one and present in the other, and the first one **executes the tool**. Test stubs are shaped by it (`time-test.sh` sudo stub answers `--version`).
- **BUG (contract 2.9)**: `TuiSys.bx:23` builds a shell string: `run( "sh", [ "-c", "command -v " & arguments.cmd ], 5 )`. Command name is concatenated unquoted; the 25 other copies pass it as `$1`.
- Run-myself: `ControlCenter.bx:58 runCli`, `TimeMachine.bx:18 runCli` (identical), `TuiSys.bx:6 bx`, `DashboardData.bx:79,90` direct `systemExecute( self(), ... )`, `ControlCenter.bx:70 runArgv`. Five paths, three different timeouts (1800, 120, 40).
- `self()`: 9 identical copies (`getSystemSetting( "BXRIG_SELF", "bxrig" )`).

Single home: `util/Proc.bx`. `Installer` keeps only `steps()` / `run()` and receives a `Proc`.

```
class Proc {
    function init( runner = "" )                       // the same injectable runner Installer has today (tests rely on it)
    function exec( argv, timeout = 30 )                // -> { exitCode, output, timeout }; 127 + message when it cannot start; never throws
    function has( name )                               // `command -v` through argv, never a shell string
    function works( name )                             // `name --version` exit 0, only where that is the actual question
    function isRoot()
    function self( args, timeout = 1800 )              // runs bxrig itself (BXRIG_SELF)
    function selfData( args )                          // `bxrig ARGS --json` -> data struct or {}  (TuiSys.bx today)
}
```

Replaces: 33 `tryExec`, 28 `has`, `Installer.exec/isRoot/hasCommand`, 9 `self`, 5 run-myself paths, `TuiSys.run/has/bx/self`. `variables.inst.exec` has 112 call sites in 55 files; keep `Installer.exec` as a deprecated forwarder for one release so the batch can be mechanical.

Decision needed from the owner: pick one meaning for "has". Proposal: `has` = `command -v` everywhere, `works` kept for the 6 places that really check a version (`Sdk`, `Java`, `Setup.hasYay`). Then the test stubs for `sudo` and `yay` no longer need a `--version` branch.

Quirk limits: injectable runner is stored in `variables` and called as `variables.custom( argv, timeout )`; works since MatchBox #158.

Risk: medium for the `has` semantic change (it touches the stubs of 21 tests); everything else is mechanical. Guards: all `*-test.sh` that stub binaries, `installer_test.bxs`.

#### F03 (High, effort S then M): environment, home and path helpers, BUG

What: the "where do my files live" question is answered 40 times in 6 flavours, and the answers disagree.

Where:
- `home()` 17 files (14 identical), `env( name, fallback )` 11 files, `dataHome()` 8 files, `cfg()`/`cfgHome()` 8, `appsDir()` 2, `cacheDir()` 2.
- **BUG, `dataHome()` means two things**: `Db.bx:21`, `Vm.bx:21`, `Dotfiles.bx:24`, `BackupConfig.bx:26`, `Secrets.bx:44` return `$BXRIG_DATA_HOME or ~/.local/share/bxrig`; `Launchers.bx:24` returns `$XDG_DATA_HOME or ~/.local/share` (no `bxrig`). Same name, different directory, so a reader or a sed can swap them silently.
- **BUG, split brain on config home**: `ConfigService.bx:16` = `$BXRIG_CONFIG_HOME or ~/.config` (ignores `XDG_CONFIG_HOME`). `Launchers.bx:31`, `Editor.bx:37`, `Strata.bx:20`, `IconTheme.bx:21` honour `XDG_CONFIG_HOME` and ignore `BXRIG_CONFIG_HOME`. A user with `XDG_CONFIG_HOME=~/cfg` gets `bxrig.lua` in `~/.config/hypr` and the Neovim starter in `~/cfg/nvim`. Tests never set `XDG_CONFIG_HOME`, so no test sees it.
- Cache: `AppsData.bx:42` and `ImageCache.bx:31` each spell the `BXRIG_CACHE_HOME`, `XDG_CACHE_HOME`, `~/.cache/bxrig` chain.
- Path literals: `/bxrig/*.json` appears in 17 classes; 97 hits for `.config` or `/bxrig/` strings.
- State home exists only in `ConfigService.stateDir` (`BXRIG_STATE_HOME`, `XDG_STATE_HOME` ignored).

Single home: `util/Env.bx`, one precedence rule for everything: `BXRIG_*_HOME` override, then `XDG_*_HOME`, then `$HOME` default.

```
class Env {
    function init( home = "" )                         // test override, replaces the `variables.opts.home` hack in IconTheme
    function get( name, fallback = "" )                // getSystemSetting with empty -> fallback (the 11 `env` copies)
    function home()
    function config( sub = "" )                        // ~/.config[/bxrig/sub]  : BXRIG_CONFIG_HOME > XDG_CONFIG_HOME > ~/.config
    function data( sub = "" )                          // ~/.local/share/bxrig[/sub]
    function xdgData( sub = "" )                       // ~/.local/share[/sub]   (desktop entries, icons; Launchers, Web, Installer)
    function cache( sub = "" )  function state( sub = "" )
    function self()                                    // BXRIG_SELF
}
```

Replaces: 17 `home`, 11 `env`, 8 `dataHome`, 8 `cfg*`, 9 `self`, cache copies, and `ConfigService.cfgHome/stateDir` (they delegate). Two distinct method names (`data` vs `xdgData`) remove the `dataHome` ambiguity.

Quirk limits: none (pure functions of `getSystemSetting`). Keep `arguments.` prefix.

Risk: the XDG fix is a deliberate behaviour change for users who set `XDG_CONFIG_HOME`; document it in `config-files.md`. Add one test that sets it. Guards: `config-test.sh`, `launchers-test.sh`, `editor-test.sh`, `strata-test.sh`, `icon_theme_test.bxs`.

#### F04 (High, effort M): the mutation protocol (plan, `--yes`, `--dry-run`, root guard), 44 files

What: `COMMAND-CONTRACT.md` section 2 defines one protocol for every mutating verb. It is re-implemented by hand per command.

Where (counts):
- "Nothing was changed" 89 times in 44 files; "Add --yes to apply" 80; `arguments.yes` 175 uses in 44 files; "Plan:"/"Dry run" banners 103 in 52 files.
- Three local plan runners with the same shape and different details: `Tweaks.bx:31 runPlan( cmd, title, cmds, yes, dry, asJson, data )` (timeout 900, exit 6 on the first failure), `Time.bx:93 runPlan( title, cmds, yes, dry, asJson, data )`, `BackupData.bx:128 plan( title, lines, yes, dry, asJson, data )`; `Security.bx:146 sudoCmd`, `Power`, `Nas`, `Containers`, `Cloud` each have a variant inline.
- Root guard: the sentence "Run as a regular user" is written 15 times (`SetupPlan.bx` x8, `Launchers.bx:167`, `Refresh.bx:109`, `Tiling.bx:59`, `Assets.bx:57`, `Time.bx:160`, `Pkg.bx:188`). 19 files put `"sudo"` into argv (71 refs) but only 12 check `isRoot()`; the contract rule 4 and rule 5 are enforced by convention.
- Which exit code a plan without `--yes` returns: 2 in all copies checked, but nothing enforces it.

Single home: `Mutation.bx`, a plan object that renders itself and runs itself.

```
class Mutation {
    function init( out, proc, title )                       // out: the Out of F01, proc: F02
    function step( argv, timeout = 900, label = "" )        // add one argv command (sudo stays visible in the plan)
    function note( line )  function data( key, value )
    function needUser()                                     // sets the "Run as a regular user" precondition once
    function run( yes, dry, asJson )                        // no --yes: plan, exit 2; --dry-run: plan, exit 0; else run, first failure -> 6
}
```

Replaces: `Tweaks.runPlan`, `Time.runPlan`, `BackupData.plan`, the inline plan blocks in about 40 commands, 15 root-guard sentences. `SetupPlan`/`InitPlan` already return `{ steps: [ { commands: [ argv ] } ] }`; `Mutation` takes that shape as input, so the pure planners stay.

Quirk limits: the plan holds argv arrays only (rule 9), no closures needed. Steps that run in a loop use `var` inside the loop body, not shared across `case`s.

Risk: medium. Output text is asserted by many tests (`grep -q 'Nothing was changed'`). Keep the wording byte-identical in the first version; unify wording later.

#### F05 (Medium, effort M): JSON settings files read and written by hand, 37 sites

What: 37 sites do `jsonDeserialize( fileRead( x ) )`, 24 of them inside their own `try { } catch ( any e ) { return {}; }`, then a merge into defaults, then (for 8 classes) a direct `fileWrite`.

Where:
- Readers: `Appearance.bx:84`, `Display.bx:48`, `BackupData.bx:57`, `Nas.bx:60,411`, `Db.bx:26,149`, `Vm.bx:34` (reads `db.json` too), `Mail.bx:40`, `Skills.bx:52`, `Update.bx`, `Shortcuts.bx:18`, `SystemState.bx:41`, `Runner.bx:57`, `Init.bx:19`, `Setup.bx:163,175`, `Editor.bx:68`, `Secrets.bx:87`, ...
- Direct writers: `Appearance.bx:93`, `Display.bx:55`, `Theme.bx:114`, `BackupData.bx:71`, `Nas.bx:66,414`, `Skills.bx:58`, `Update.bx:47`: `directoryCreate( getDirectoryFromPath( f ), true, true ); fileWrite( f, jsonSerialize( s ) & chr( 10 ) );`.
- **BUG (contract 2.6)**: "Every config file touched goes through the config service (backup, atomic replace, journal). No direct writes." The 8 writers above bypass it (no backup, no journal, no atomic move, no `config history`). `Ai.bx:57`, `Secrets.bx:98`, `KeysEditor.bx:86` do it right.
- 34 `fileWrite(` in 20 files in total; 47 `directoryCreate(` in 24 files.

Single home: `JsonStore.bx`, the only class that reads and writes a BxRig settings JSON.

```
class JsonStore {
    function init( config, name, file, defaults = {}, mode = "644" )   // config: the ConfigService
    function read()                                // defaults merged with the file; {} + defaults when missing or invalid; never throws
    function get( key, fallback = "" )             // structKeyExists first (the native-runner panic quirk)
    function write( data, reason = "apply" )       // ConfigService.configWrite: backup, atomic, journal
}
```

Replaces: 37 read sites, 8 direct writers, the `settingsFile()`/`stateFile()` helpers (7 files, each concatenating `cfg() & "/bxrig/NAME.json"`).

Quirk limits: no key read inside `try` for a missing key; `read()` validates with `isStruct`. Keys are lower-case by convention, so struct case-insensitivity is harmless here.

Risk: medium, because writes now create journal entries and backups (new files under the state dir). Tests that count files in `$tmp/cfg/bxrig/` may need an update. Guards: `appearance-test.sh`, `display-test.sh`, `theme-test.sh`, `nas-test.sh`, `backup-data-test.sh`, `skills-test.sh`, `update-test.sh`.

#### F06 (Medium, effort M): config entries built by hand; root-owned files bypass the service

What: the entry `{ name, target, mode, content }` is a struct literal in 51 places (19 files). Files owned by root are written with `fileWrite` to a temp file then `sudo install -Dm644`, which has no backup or journal at all.

Where:
- Entry literals: `Ai.bx:57`, `Secrets.bx:98,321`, `KeysEditor.bx:86`, `MacExtras.bx:157,249`, `Update.bx:177,178`, `Shortcuts.bx:259-263`, `Theme.bx:134`, `Main.bx:184`, ...
- Root file writes: `Nas.bx:235,310,311`, `Power.bx:120`, `Security.bx:117,125`, `Time.bx:151`, `Update.bx:82` (writes temp, then installs): 9 `sudo install -Dm` sites in 4 files. Each re-derives the temp path (`getTempDirectory()` 16 uses in 12 files, `createUUID()` 26 uses).
- Hand-written systemd unit text: `Time.bx:44`, `MacExtras.bx:157,249`, `Update.bx:177`, `Cloud.bx:62`, `Nas.bx:295,297`, `Shortcuts.bx:274`, `BackupData.bx` (8 places).
- `Installer.writeFile:60` and `AppIcons.bx:157` implement a third and fourth "write temp then move".

Single home: add `ConfigService.entry()` and a root variant `SystemFile`; `SystemdUnit` renders unit text.

```
class ConfigService {       // existing, extended
    function entry( name, target, content, mode = "644" )          // the one place the shape is spelled
}
class SystemFile {
    function init( proc, config )
    function step( entry )          // -> argv steps: write temp, `sudo install -Dm<mode>`, plus a backup copy step so `config history` knows it
}
class SystemdUnit {
    function render( sections )     // sections: array of { name, lines } (ordered, because struct key order is not promised)
}
```

Replaces: 51 literals, 9 `sudo install` sites, 8 unit text builders, 3 temp-then-move helpers.

Quirk limits: `render` takes an array of sections (not a struct) to keep order and to avoid case-insensitive keys; build entries stepwise.

Risk: medium for the root files (journal for files the user cannot read back as a normal user: decide whether `config diff` may use `sudo cat`). Guards: `nas-test.sh`, `power-test.sh`, `security-test.sh`, `time-test.sh`, `update-test.sh`, `config-test.sh`.

#### F07 (Medium, effort S): `validName` x9, each with its own regex and its own exit code

Where (`grep -n "function validName"`): `BackupData.bx:74` and `Nas.bx:52` `^[a-z][a-z0-9-]{0,30}$` (exit **2**), `Cloud.bx:30` and `Web.bx:27` `^[A-Za-z0-9_-]{1,40}$` (exit **4**), `Db.bx:31` `^[a-zA-Z0-9-]{1,40}$`, `Vm.bx:27` `^[a-z0-9][a-z0-9-]{0,30}$` (exit 4), `Theme.bx:364` `{0,40}`, `Secrets.bx:27` `^[A-Z_][A-Z0-9_]{0,63}$` (exit 4), `Pkg.bx:37` `^[a-z0-9@._+-]{1,100}$`; the same pacman regex pasted inline twice in `AppsData.bx:403,419`. Bad input exits 2 in 3 classes and 4 in 5 (contract: 2 is usage).

Single home: `Names.bx`.

```
class Names {
    function kind( kind, value )          // kind: "slug", "remote", "container", "vm", "theme", "secret", "package" -> true/false
    function rule( kind )                 // the human sentence for the error message (also used by help text)
}
```

Replaces: 9 definitions, 2 inline regex, 11 hand-written error sentences. Exit code for a bad name becomes a decision made once (propose 2).

Risk: low. Behaviour change in the exit code for 5 classes; update their tests (`vm-test.sh`, `secrets-test.sh`, `runtime-cloud-test.sh`, `web-vpn-test.sh`).

#### F08 (Medium, effort S): small text and format helpers copied around

- `merge( base, extra )`: 10 byte-identical copies (`Db.bx:41`, `Cloud.bx:92`, `Layout.bx:88`, `Record.bx:45`, `Vm.bx:420`, `Web.bx:98`, `Dotfiles.bx:312`, `AiSession.bx:74`, `Pkg.bx:239`, `Update.bx:164`).
- Byte sizes: `TuiKit.bx:213 size`, `BackupConfig.bx:96 human`, `Vm.bx:97 humanKb`, plus forwarders (`TimeMachineView.bx:285`). Three formats ("1.5 MB", "1.5 MB" with rounding by `/104857.6`, "2 GB").
- Durations: `TuiSys.bx span` ("5m"), `DashboardPage.bx:51 ago` ("5 min ago"), `BackupTimeline.bx:62 ago` ("5 minutes ago", "yesterday", weeks, months). Three ladders with different thresholds.
- Padding: `AppsPage.bx:40 pad/padLeft`, `ListPage.bx:122 padText`, `Help.bx:16 pad` (the first two byte-identical).
- Lines: `listToArray( ..., chr( 10 ) )` 98 times (45 on command output), `trim( x.output )` 201 times in 59 files, `chr( 10 )` 295 times, a local `nl()` in 7 files.
- Timestamps: `dateTimeFormat( now(), "yyyy-MM-dd'T'HH:mm:ss" )` in `ConfigService.bx:43`, `BackupConfig.bx:128`, `BackupTimeline.bx:48`.

Single home: `util/Text.bx` (strings) and `util/Fmt.bx` (human formatting).

```
class Text { function merge( a, b )  function lines( s )  function pad( s, w )  function padLeft( s, w )  function nl() }
class Fmt  { function bytes( n )  function kb( n )  function ago( seconds, style = "long" )  function span( seconds )  function stamp() }
```

Quirk limits: closures cannot call these (`rows.map( function ... )` in `Launchers`, `Shortcuts`). Where a closure needs `ago`, compute the strings in a plain loop before; the existing code already does that in most places.

Risk: low. Keep each style as a named option so every existing test string stays identical.

### B. External tools called from many places

#### F09 (Medium, effort M): pacman / AUR / flatpak call sites, 22 files

Where:
- The literal `"sudo", "pacman", "-S", "--needed", "--noconfirm"` appears 16 times in 11 files (`SetupPlan.bx` x4, `BackupSnapshots` x2, `Security` x2, `BackupConfig`, `Containers`, `Dotfiles`, `Editor`, `Nas`, `Power`, `Secrets`, `Tweaks`). `Installer.bx:114` already builds the same argv properly (root-aware).
- "Set of installed package names" (`pacman -Qq` then split lines then trim): `Pkg.bx:42`, `AppsData.bx:237`, `Packages.bx:15`, `Tweaks.bx:121`, `MacExtras.bx:179`, `BackupConfig.bx:240`, `Dolphin.bx:19`: 7 parsers, 3 timeouts (15, 30, 60).
- "Is package X installed": `Containers.bx:26 pacmanHas`, `Editor.bx:116`, `Setup.bx:15`.
- `yay`: `Installer.bx:93`, `SetupPlan.bx:289`, `Update.bx:193`, `Packages.bx:145`, `Pkg.bx:189` (each with its own "yay is not installed" sentence); flatpak: `AppsData.bx:245`, `AppsModel.bx:292`.
- Package-name regex pasted into `Pkg.bx:37`, `AppsData.bx:403,419` (F07).

Single home: `Pacman.bx`, next to `Installer` (which becomes its main client).

```
class Pacman {
    function init( proc )
    function installed()                                     // struct set of every installed name
    function has( pkg )
    function installArgv( pkgs, asRoot = false )             // [ "sudo", "pacman", "-S", "--needed", "--noconfirm", ... ]
    function removeArgv( pkgs, asRoot = false, recursive = true )
    function aurArgv( pkgs )                                 // [ "yay", "-S", ... ]
    function search( text )  function info( name )
}
```

Replaces: 16 literals, 7 installed-set parsers, 3 `has` checks. `Installer.steps` and the four `SetupPlan` blocks call `installArgv`.

Quirk limits: argv arrays only, returned as new arrays each call (callers `append` to them; sharing one array would alias, see `Installer.steps` building `pac` per call).

Risk: low to medium. Tests assert on the logged argv (`grep -q "pacman -S --needed --noconfirm"` in fake-binary logs), so the exact flag order must not change.

#### F10 (Medium, effort M): systemctl and units, 16 files, 47 refs

Where:
- "enable now": `daemon-reload` then `enable --now UNIT`: `Cloud.bx:86-87`, `MacExtras.bx:160-161,252-253`, `Update.bx:180-181`, `BackupData.bx:385`, `SetupPlan.bx:304`, `Nas.bx:312-313`, `Time.bx:151`: 8 times.
- "is active" two idioms: output equals `"active"` (`Cloud.bx:123`, `Containers.bx:45`, `MacExtras.bx:138,146,240`, `MacKeys.bx:23`, `AiModels.bx:67`) versus `--quiet` exit code (`BackupSnapshots.bx:54`, `Power.bx:70`, `Time.bx:79`, `Security.bx:169`). Local wrapper names: `active`, `autoActive`, `serviceActive`.
- `--user` and system variants mixed; `sudo systemctl` 9 times in `Nas`, `Security`, `Power`, `BackupSnapshots`.
- Unit names are string literals scattered (`bxrig-update-check.timer`, `bxrig-wlsunset.service`, `bxrig-airplay.service`, `bxrig-snooze.timer`, `bxrig-backup.timer`, `automatic-timezoned.service`, `xremap.service`): 28 occurrences, no list.

Single home: `Systemd.bx`.

```
class Systemd {
    function init( proc, user = true )
    function isActive( unit )                    // one idiom
    function enableNowArgv( unit )               // [ [ "systemctl", "--user", "daemon-reload" ], [ ..., "enable", "--now", unit ] ]
    function disableNowArgv( unit )
    function restartArgv( unit )
    function sudo()                              // same API with `sudo systemctl` (system units)
}
```

Replaces: 8 enable sequences, 11 `is-active` wrappers. Unit names move to one `UnitNames` map next to the unit renderer of F06.

Risk: low. Guards: `macextras-test.sh`, `nas-test.sh`, `update-test.sh`, `runtime-cloud-test.sh`, `power-test.sh`, `time-test.sh`.

#### F11 (Medium, effort M): curl and download call sites, 11 files, 17 refs

Where:
- `Boxlang.bx:101` `curl -fsSL --max-time 30`, `Pkg.bx:75` `-fsS -m 20`, `Sdk.bx:66` `-fsSL --max-time 25`, `Skills.bx:63` `-fsSL --max-time 30`, `Skills.bx:138` `-sSL ... -X POST`, `Update.bx:92,97,153,154` `--max-time` 30/600, `Strata.bx:58` `-fsSL` no timeout flag (only the process timeout 120), `SetupPlan.bx:215` `-fsSL -m 120`, `Java.bx:97` direct `systemExecute( "curl", args, 600 )`, `Mail.bx:58`.
- Spelling `-m` vs `--max-time`, `-fsSL` vs `-sSL` (Skills POST drops `-f`, so HTTP errors look like success), 4 error styles: return `""` (`Sdk`), return the raw result (`Java`, `Mail`), `throw`, or a struct with `exitCode`.
- Process timeout and curl `--max-time` are set independently (`Skills.bx:63` 30 vs 60, `Update.bx:153` 600 vs 700): two clocks to keep in step.
- External installer scripts (contract 2.8): `Installer.bx:104` pipes curl to shell inside `bash -c`; `SetupPlan.bx:215` downloads to a file first. Two code paths for the same rule.

Single home: `Http.bx`.

```
class Http {
    function init( proc )
    function get( url, timeout = 30 )                       // -> { ok, status, body, error }
    function post( url, json, timeout = 30 )
    function download( url, dest, timeout = 120 )           // temp then move; returns { ok, sha256 }
    function script( url )                                  // contract 2.8: download to temp, print url and sha256, caller runs it as the user
}
```

One place sets `-fsSL`, `--max-time`, `--connect-timeout`, a `User-Agent: bxrig/VERSION`, and derives the process timeout as `timeout + 10`.

Risk: low. Tests fake `curl` on `PATH` (3 test files) and match argument text; keep `-fsSL --max-time N` as the argv spelling.

#### F12 (Medium, effort S): desktop detection and container-engine choice

- Desktop: `Resolver.detectShell( text )` exists, yet 12 files read `XDG_CURRENT_DESKTOP` themselves (`AiShell.bx:30`, `Display.bx:32`, `Layout.bx:27`, `MacExtras.bx:36`, `Screenshot.bx:30`, `Secrets.bx:487`, `Runner.bx:41,98`, `Packages.bx:49`, ...) with `findNoCase( "KDE", ... )`, `lCase( ... ) == "hyprland"` and similar. Only `MacExtras` and `Screenshot` honour the `BXRIG_DESKTOP` override, so tests cannot steer the other 10. Home: `Env.desktop()` returning `"hyprland" | "plasma" | ""`, implemented on `Resolver.detectShell`.
- Container engine: `Db.bx:26`, `Vm.bx:34` (reads `db.json` again), `SystemState.bx:85` each decide podman or docker from the same file and defaults. Home: `Db.engine()`; `Vm` and `SystemState` ask `Db`.

Risk: low.

### C. Command registry and Main.bx

#### F13 (High, effort L, staged): the command registry does not exist; Main.bx is it

What: a command's facts are spelled in 7 places that nothing forces to agree.

| Where the name or flag list lives | What it holds | Checked against the others? |
|---|---|---|
| `Main.bx` `case "x":` (93 cases) | routing, arity (`p.len() == N`, 149 times), usage text (56 `"Usage: bxrig ..."` strings) | gen-docs checks names |
| `Main.bx:18` flag whitelist | 130 entries, 122 distinct, 8 duplicated (`overwrite`, `default`, `out`, `type`, `region`, `from`, `tag`, `mode`) | no |
| `Main.bx` catalog case (~line 118) | a second, local whitelist | no |
| `docs/reference/cli.json` | summary, `usage[]`, `examples[]`, group | `gen-docs.sh` checks names, first word of usage and example commands only; usage text is **not** compared with Main's `"Usage:"` string |
| `src/bxrig/HelpData.bx` | generated copy of cli.json | `gen-docs.sh --check` |
| `MenuTree.bx`, `Launchers.bx`, `Shortcuts.bx` (`execBxrig( "record toggle" )`) | argv strings that must name real commands | `menu-test.sh` partly |
| `tests/help-test.sh`, `cli-contract-test.sh`, `native-smoke.sh` | expected lists | self |

Problems that follow:
- **BUG (looseness)**: the whitelist is global. `bxrig version --ram=4` passes the flag check, because `ram` is valid for `vm`. Every command accepts every flag of every other command. Only `catalog` re-checks. The contract says "unknown flags are usage errors".
- **BUG (contract 1)**: the `default:` branch (`Main.bx:1013`) prints "Unsupported command" and falls out of `main` with no `CLIExit( 2 )`; it exits 0 (verify), while `help nonsense` exits 2.
- `structKeyExists( args.options, "yes" )` 66 times, `"dry-run"` 53, 129 option reads in total, 26 `args.options.x ?: ""`.
- Usage text duplicated: when a flag is added, Main's string, cli.json and the whitelist must all be edited by hand (3 edits, no test ties the first to the other two).

Single home: `docs/reference/cli.json` becomes the registry (it is already data, already generated into `HelpData`, already reviewed). Extend each command with `flags` and `subs`, generate `CommandSpec.bx`, and let one class validate.

```
// cli.json command: { name, group, summary, usage[], examples[], flags: [ { name, kind: "bool"|"value", for: [ "install", "remove" ] } ], subs: [ { path: "key set", args: 2 } ] }
class CommandSpec {            // GENERATED by bootstrap/gen-docs.sh (stepwise literal, as HelpData is)
    function names()           function flagsFor( command )     function usage( command )
}
class Options {                // wraps args.options once
    function init( raw )  function yes()  function dry()  function has( name )  function str( name, fallback = "" )
    function unknown( allowed )                  // -> first flag not allowed, or ""
}
class Router {                 // phase 2
    function check( command, positionals, options )    // flags + arity from the spec; returns "" or the usage line
}
```

Staging (each stage shippable):
1. Put `flags` into `cli.json`; `gen-docs.sh` emits `CommandSpec`; Main's global whitelist is replaced by `CommandSpec.flagsFor( cmd )`. New test: `tests/flags-test.sh` walks every command and asserts a foreign flag exits 2.
2. Replace the 56 `"Usage:..."` literals by `CommandSpec.usage( cmd )`, remove them from Main; `gen-docs.sh` already guarantees usage text exists.
3. Replace `structKeyExists( args.options, "yes" )` (129 sites) by `opts.yes()` etc.
4. Optional: each command class gets `run( words, opts, asJson )`; Main case becomes one line (`CLIExit( new bxrig.Time( cli ).run( p, opts, asJson ) )`). Arity moves from `p.len() == 3` conditions into the class, or into `subs`. Full dispatch by name would need `invoke()`; the plain `switch` stays until that is verified.

Quirk limits: the generated class is a stepwise literal (quirk), `switch` cases keep their own scope (#159), no closures call methods.

Risk: stage 1 is the only one that can break users (a script that passes a stray flag now gets exit 2); that is the documented behaviour. Guards: `cli-contract-test.sh`, `help-test.sh`, `native-smoke.sh` (`usage_exit2`, `expect_error`), plus the new `flags-test.sh`.

#### F14 (Medium, effort M): Main.bx holds domain logic

- `config` case (`Main.bx:174-230`): builds the list of managed files itself: an inline `bxrig.json` literal (line 184), `Shortcuts.entries` (185), `Starter.entries` (186). `Refresh.bx:39` has a second list of "what is owned by whom". `config diff` writes a temp file and shells out to `diff` (`Main.bx:213-215`). Home: `ManagedConfigs.all( config )` in `ConfigService`'s neighbourhood, and `ConfigService.diff( entry )`. Any new managed file (Theme, Appearance, Display, Editor, Terminal, Shell entries are `configWrite`d but NOT in `config list`) is invisible to `bxrig config list` until someone edits Main. 8 classes write entries that `config list` does not know.
- `catalog` case (about 70 lines, `Main.bx:97-170`): list filtering, grouping and printing; belongs to `Catalog`.
- `version` case prints the logo and tagline (`Main.bx:31-37`); `wizard` case (`Main.bx:908-934`) reads answers, writes `--out`.
- `runner show` prints `rnCfg` itself.

Single home: each belongs to its domain class; `Main` only routes. Effort M because each is a move, not a rewrite.

#### F15 (Low, effort S): the version string, 6 places

`Main.bx:5`, `:11`, `:35`, `box.json:4`, `tests/native-smoke.sh:5`, `tests/bootstrap-test.sh:43,84,533`, and `SystemState.bx:56` builds `new bxrig.Cli( "0" )` (a version that is a lie). `Update` cannot ask `Cli` for the running version because `Cli.version` has no getter.

Home: `Cli.version()`, set once from a generated `Version.bx` (`gen-version.sh` reads `box.json`, same `--check` pattern as the other 8 generators). Tests read `box.json` with `jq`.

#### F16 (Medium, effort M): Control Center page registry in three places; provider boilerplate

- Page identity is spelled in `ControlCenterPages.list()` (`id`, `title`, `icon`, 17 rows), in each provider (`id()`, `title()`, `icon()` in 14 providers), in `ControlCenter.buildPages()` (order must match), in `Launchers.folders()` (page-id lists as strings, `Launchers.bx:41`). `control_center_test.bxs` checks they agree; the shape is still four sources of truth.
- 13 of 14 providers define the identical constants `refreshSeconds() { return 0; }`, `live() { return false; }`, `detailLines() { return 2; }` (39 lines), and each carries a `variables.demo` branch (28 refs) with inline fixtures. `DashboardDemo` and `TimeMachineDemo` already show the better shape (fixtures in a `*Demo` class); the 14 providers do not follow it.
- Every provider does `variables.sys = new bxrig.TuiSys()` (13 times).

Home: `ControlCenterPages` becomes the one registry with a `make( id, demo )` factory (a `switch` on id, quirk-safe) and `ListPage` reads missing provider methods from a defaults struct:

```
class ListPage { function init( provider ) { variables.spec = new bxrig.ProviderSpec( arguments.provider ); } }   // spec.live(), spec.detailLines(): provider value or default
class ControlCenterPages { function list()  function make( id, demo = false )  function folderOf( id ) }
```

Risk: low. Guards: `control_center_test.bxs`, `app_pages_test.bxs`, `tui-test.sh`.

### D. Parsers

#### F17 (High, effort M): two and a half `.desktop` parsers and two directory lists, BUG

What: three classes parse `[Desktop Entry]` differently, and five classes write desktop entries by string concatenation.

Where:
- `Apps.bx:27-45 parse` compares with `==` (`key == "Name"`): **case-insensitive** (`name=` or `NAME=` would match; localized keys such as `Name[de]` are skipped only because the full key text differs). `AppsData.bx:55-78 parseDesktop` uses `compare( key, "Name" ) == 0`: case-sensitive and correct. `AppIcons.bx:53-60` is a third, reading only `Icon=`.
- Same 20 lines of loop body (`inEntry`, `find( "=", line )`, `left`/`mid`) in all three.
- **Behaviour divergence**: `AppsData` hides `X-BxRig-Launcher` entries (commit `d6a0678` fixed it there); `Apps.bx:46-50` does not, so `bxrig apps` / `apps list` can list BxRig's own launchers. `AppsData` keeps entries with an empty `Exec`; `Apps.bx` drops them. `AppsData` reads `Comment` and `Categories`; `Apps.bx` does not.
- Two directory lists and two env overrides: `Apps.bx:21 dirs()` = `/usr/share/applications`, `~/.local/share/applications`, `/var/lib/flatpak/exports/share/applications`, override `BXRIG_APPS_DIRS`; `AppsData.bx:46 desktopDirs()` = `/usr/share/applications`, `/usr/local/share/applications`, `~/.local/share/applications` (no flatpak exports), override `BXRIG_DESKTOP_DIRS`. The same screen can show different app sets depending on which command asked.
- `cleanExec`: byte-identical in `Apps.bx:48` and `AppsData.bx:33`.
- Writers: `Installer.bx:53 launcherFile`, `Launchers.bx:85,95`, `Web.bx:59`, `Vm.bx:412`, `PlasmaPanels.bx:143` all concatenate `"[Desktop Entry]" & chr( 10 ) & "Type=Application" ...`. Five spellings of the same file, with `Terminal=false`, `Categories=`, comments in different orders.

Single home: `util/DesktopEntry.bx`.

```
class DesktopEntry {
    function parse( text )                          // -> { name, exec, icon, type, hidden, comment, categories, keys: [ { key, value } ] }; compare() on keys
    function read( file )                           // fileRead + parse; never throws
    function dirs()                                 // one list, one env override BXRIG_DESKTOP_DIRS (BXRIG_APPS_DIRS kept as alias for tests)
    function all()                                  // visible applications, later folder wins, X-BxRig-Launcher hidden unless asked
    function cleanExec( exec )
    function render( entry )                        // text for [ { key, value } ] in a fixed order; Terminal, Categories optional
}
```

Replaces: `Apps.parse/cleanExec/dirs/all`, `AppsData.parseDesktop/cleanExec/desktopDirs/desktopEntries`, `AppIcons` icon read, five writers.

Quirk limits: `compare()` for keys (the only reason `AppsData` is right and `Apps` is wrong); entries returned as arrays of pairs when exact key case matters, with named fields filled for the known keys.

Risk: medium (the app list shown by `apps` changes: flatpak apps appear in the Control Center page, BxRig launchers disappear from `apps`). Guards: `apps-test.sh`, `apps-manager-test.sh`, `apps_manager_test.bxs`, `app_icons_test.bxs`, `launchers-test.sh`, `web-vpn-test.sh`, `vm-test.sh`, `plasma-panels-test.sh`; add `desktop_entry_test.bxs` with `name=` lower-case, `Name[de]`, `NoDisplay`, `X-BxRig-Launcher`.

#### F18 (Medium, effort S): other small parsers

- `key=value` lines: `Update.bx:104` (properties file: `listFirst`/`listRest`), `BackupData.bx:171` (`--keys-file`), `IconTheme.bx:51` (`gtk-icon-theme-name=` with quote stripping), `Secrets.bx:412`, `Time.bx:62` (`timedatectl show`). Five implementations, two of them using `listFirst( line, "=" )` (breaks when the key is empty; `listToArray` drops empty items by default and these calls do not pass `includeEmpty`).
- `[section]` walkers: `Apps`, `AppsData`, `AppIcons` (F17) and the `kglobalshortcutsrc` reads in `KeysService` through `kreadconfig6`.
- Lua scraping: `KeysEditor.bx:27-57 userBinds` parses `hl.bind(` lines by hand (the header says "not a Lua parser"). It must stay best-effort, but it duplicates the key-name rules of `Shortcuts.parseKeys` (F20).

Single home: `Props.bx` (key=value, `#` comments, quote strip, `compare`-based `get`) and the `DesktopEntry` section reader reused as `Ini.parse( text )` returning arrays of pairs.

Risk: low.

### E. Shortcuts

#### F19 (High, effort M): the shared table is incomplete, so conflict scanning is blind, BUG-class

What: `Shortcuts.table()` is billed as the single source for xremap, Hyprland and Plasma, but 4 Hyprland binds are written as plain Lua text inside `hyprland()`, and the starter template carries about 30 more. `keys show`, the cheat sheet (`KeySheet`), `keys set` and `keys conflicts` read only the table.

Where:
- `Shortcuts.bx:196-203` hand-written: `Super+Space` (launcher), `Super+S` (control-center panel), `Super+comma` (settings), `Alt+Tab` (window switcher). None is a row, so none is listed by `keys sheet`, none can be changed with `keys set`, none is seen by the conflict scan.
- `templates/hyprland.lua` (embedded as `TemplateData.bx:154-179`): `Super+Q/Return/B/E/F/V/J`, arrows, workspaces 1 to 9. Not in the table either.
- `KeysEditor.bx:59-72 scan()` compares only `editable()` rows (`kind != "remap"`) with each other and with user files. It never compares **remap sources with binds**.
- Probable dead binds (verify on a machine): xremap rewrites `Super+S` to `Ctrl+S` (`mac-s`), `Super+comma` to `Ctrl+comma` (`mac-comma`), `Super+V` to `Ctrl+V` (`paste`), `Super+F` and `Super+B` likewise, before Hyprland sees them. The hand-written `mainMod .. "+S"` (control center) and `mainMod .. "+comma"` and the starter's `Super+V` (float) and `Super+F` (fullscreen) can then never fire. A scan over remaps plus binds would have said so.
- `ShortcutsProvider.bx:25` has its own demo rows for the same data (a second table, demo only).

Single home: still `Shortcuts`, but complete: add `kind: "hypr-fixed"` rows (listed, conflict-checked, not editable) for the 4 hand-written binds and the starter binds (generated from `templates/hyprland.lua` by a small reader, or declared once in the table and rendered into both files).

```
// Shortcuts
function table()                 // + fixed rows: { id, keys, action, kind: "hypr-fixed", dispatch }
function conflicts()             // -> { within: [...], remapShadows: [ { id, combo, remap } ], user: [...] }   (used by KeysEditor.scan and KeySheet)
```

Risk: low for the table; the conflict rule may report existing real clashes (that is the point). Guards: `shortcuts_test.bxs` (`show lists every row` counts 55, will change), `keys-test.sh`, `keys-editor-test.sh`, `keys-apply-test.sh`, `xremap-test.sh`, `hyprland-setup-test.sh`.

#### F20 (Medium, effort M): `Shortcuts.bx` mixes four jobs; Lua text is hand-assembled

What: one 278-line class holds key-combo parsing (`parseKeys`, `normalize`, `hyprExpr`, `qtKeys`), the data table, three renderers (xremap YAML, Hyprland Lua, Plasma ini) and the managed-file entries.

Where:
- `Shortcuts.bx:210-235`: the same Lua block (`local cfgdir = os.getenv( "BXRIG_CONFIG_HOME" ) or ...; local ok, X = pcall( dofile, cfgdir .. "/bxrig/theme/NAME.lua" )`) is pasted 3 times for `hypr.lua`, `look.lua`, `monitors.lua`. The producers of those files are in three other classes (`Theme.bx:134`, `Appearance.bx:30 lookFile`, `Display.bx:24 monitorsFile`); the file names exist as string literals on both sides (6 places) and in `Refresh.bx:39,67-68`.
- `xremap()` rebuilds the source key as `"Super-" & lcase( listLast( r.keys, "+" ) )`: it assumes every remap starts with `Super+`, ignoring the `parseKeys` it already has. The Plasma value is `qtKeys( r.keys ) & "," & r.plasmaTail` computed inside `table()` as a side effect on the row.
- `table()` is rebuilt (and `ControlCenterPages().list()` re-instantiated) on every call; `setKeys` calls it 3 times and normalises every row each time.

Single home: split by job, keep `Shortcuts` as the facade so callers do not change.

```
class KeyCombo   { function parse( text )  function normal()  function hypr()  function qt()  function xremap() }        // pure, tested alone
class LuaModule  { function optional( file, variable, apply )  function bind( combo, dispatch ) }                         // the 3 pasted blocks become 3 calls
class ShortcutRenderers { function xremap( rows )  function hyprland( rows )  function plasma( rows ) }
class Shortcuts  { function table()  function entries( cfgHome )  function render( target ) }                             // facade, unchanged API
```

Plus constants for the module names (`ThemeFiles.hypr()`, `look()`, `monitors()`), used by Theme, Appearance, Display and `LuaModule`.

Quirk limits: `KeyCombo.parse` keeps `compare` for `Enter` vs `enter` handling (today `lcase( raw ) == "enter"`, safe because both sides are lowered).

Risk: low; `shortcuts_test.bxs` already asserts rendered text, keep it as the golden test.

### F. TUI layer

#### F21 (Medium, effort M): plan / ask / result state machine written twice; key tables written twice

What: `ControlCenterApp` and `TimeMachineApp` each carry the same modal state (`{ title, lines, intent }`, modes `confirm` and `result`, `y`/`n`/`Escape`/`Enter` handling), and `ControlCenterApp` adds the text-entry `ask` mode that `WizardApp` and `ListPage` (filter input) and `AppsModel.typeChar` re-implement.

Where:
- `ControlCenterApp.bx:68-69` `showPlan`/`showResult` and `onKey` 82-110 (confirm: `y Y Enter` runs, `n N Escape q` cancels; result: any key; ask: Backspace/Space/printable). `TimeMachineApp.bx:168-178` `showPlan`/`showResult`, `onKey` 191-206 and `leaveConfirm`, with lines split from text (`listToArray( text, chr( 10 ), true )`) where Control Center receives an array.
- Intent execution: `ControlCenter.bx:76-104 handle` and `TimeMachine.bx:47 handle` both run "dry-run, show plan, on `y` run with `--yes`, show result", with `runCli` twice (F02).
- Case-sensitive key compares: `compare( k, "q" ) == 0` 32 times in 5 files (`AppsModel` 10, `ControlCenterApp` 6, `DashboardPage` 5, `ListPage` 3, `AppsData` 8; the `AppsData` ones are not keys). It exists only because `==` is case-insensitive and `q` and `Q` are different keys. Each author must remember it.
- Footer hints and handlers are separate lists: `DashboardPage.keys()` (line 29) vs `onKey` (31), `AppsPage.keys()` (28) vs `AppsModel.onKey` (340-396), `ListPage.keys()` (37) vs `onKey` (84). `ListPage` provider `actions()` (`{ key, label, run }`) already shows the right shape: one list drives both.
- Printing: `ControlCenterApp` modal and `TimeMachineView.modalBox`, `ControlCenterView` modal, `TuiKit.modal/confirmModal` (the kit has the drawing).

Single home: two small classes next to `TuiList`.

```
class Modal   {                                   // state only, no drawing
    function plan( title, lines, intent )  function result( title, lines )  function ask( title, prompt, make )
    function onKey( key )                         // -> { done: true|false, intent, confirmed } ; y/n/Escape/Enter/Backspace/printable in one place
}
class KeyMap  {                                   // one table: key, label, intent; drives footer and dispatch
    function add( key, label, run )  function hints()  function dispatch( key )   // compare() inside
}
class IntentRunner { function init( proc )  function handle( app, intent ) }   // ControlCenter.handle and TimeMachine.handle merged
```

Quirk limits: `KeyMap.dispatch` returns the stored closure's result; closures in `run` capture data, never call methods (as `provider.actions()[].run` does today). `Modal.onKey` is a plain method called from the app, not from a closure.

Risk: medium (key handling is dense; many tests send keys). Guards: `control_center_test.bxs`, `time_machine_test.bxs`, `app_pages_test.bxs`, `wizard_app_test.bxs`, `tui-test.sh`, `timeline-test.sh`, `pty-frame.py` runs.

#### F22 (Low, effort S): view forwarders, palette copies, starfield

- `WizardView.bx:29-37` (9 one-line forwarders `mix`, `brand`, `shimmer`, `c`, `put`, `fillRect`, `gtext`, `wrap`, `panel`) and `TimeMachineView.bx:24-41` (12) re-export `TuiKit` methods; `ControlCenterView` and the pages call the kit directly.
- The Catppuccin and brand palette is declared again in `WizardView.bx:14-18` and `TimeMachineView.bx:14` (50 `variables.BASE` style uses) although `TuiKit.color( "BASE" )` has it (`TuiKit.bx:15`).
- Starfield: `WizardView.bx:94 starfield` (46 stars) and `TimeMachineView.bx:101 stars` (40 stars) share the same LCG constants (`2654435769`, `1664525`, `1013904223`) and logic, differing in avoid-rect and glyphs.
- `TuiSys` is a data and process helper but is named for the TUI, and `AppsData.bx:18` (documented as reusable by "a future desktop app") depends on it. Fixed by F02.

Home: `TuiKit.starfield( count, avoid, tick, style )`; views call `variables.kit.x()` directly; palette read from `kit.color()`.

Risk: low, covered by `tui_kit_test.bxs`, `wizard_view_test.bxs`, `time_machine_test.bxs` (they render frames).

### G. Tests

#### F23 (High, effort M): the shell test harness is copy-pasted 70 times

Counts over `tests/*.sh` (74 files, 5,876 lines):
- `fail() { echo "FAIL: $*" >&2; exit 1; }` in **70**, byte-identical.
- `code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }` in 53 (four more spellings in 11 files).
- `run() { env HOME=... BXRIG_CONFIG_HOME=... PATH="$tmp/bin:$PATH" LOG=... "$@"; }` in 61, with at least 8 different environment sets (the 5 most common appear 2 to 3 times each, the rest once).
- `tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT` in 69; `binary="$(realpath "${1:?native executable required}")"` in 65.
- 58 `cat > "$tmp/bin/NAME"` fake-binary heredocs: `pacman` 13 times in 23 files, `sudo` stub in 21, `id` stub in 22, `systemctl` in 10, `curl` x3, `git` x3, `hyprctl` x3, `restic` x3.
- `grep -q ... "$LOG" || fail ...` 145 times; `jq -e` 351 times, 322 of them on the same envelope fields (`.ok`, `.exit`, `.schema == 1`, `.data...`).
- `native-smoke.sh` has its own `has()`, `usage_exit2()`, `expect_error()`.

Single home: `tests/lib/harness.sh`, sourced by every test.

```
# tests/lib/harness.sh
fail() { ...; }                       # one definition
bx_init BINARY_ARG                    # binary, tmp, trap, home, cfg, data, state, LOG; exports the standard env list
bx_run ARGS...                        # env HOME BXRIG_CONFIG_HOME ... PATH="$tmp/bin:$PATH" LOG ... "$@"
bx_code ARGS...                       # exit code only
bx_stub NAME 'BODY'                   # writes $tmp/bin/NAME logging "NAME $*" to $LOG, exit 0; bx_stub_sudo, bx_stub_id, bx_stub_pacman, bx_stub_systemctl
bx_log_has 'text'  bx_log_lacks 'text'
bx_json ARGS... -- 'jq filter'        # runs with --json and asserts jq -e
```

Replaces about 450 lines of preamble (70 files x 6 to 7 lines) and the 58 fake-binary blocks that are repeats; makes F02's `has` change a one-file edit (the `--version` branch of the `sudo` stub lives once).

Quirk limits: none (bash). `set -euo pipefail` stays in each test (a sourced file cannot set it for the caller reliably); `fail` must exit the caller.

Risk: low, but large diff; do it per test group (tests of one subsystem at a time) with the guard being the test itself.

#### F24 (Medium, effort S): `.bxs` harness and test registration

- `function check( label, ok ) { if ( ok ) println( "ok   " & label ); else { println( "FAIL " & label ); failures++; } }` plus `failures = 0` in all 20 `.bxs` tests; `sh()` x3, `text()` x2, `touch()`, `shot()` x2 (render a frame) repeated.
- Registration is by hand in 4 lists: `.github/workflows/ci.yml` names every shell test **twice** (the `bash -n` syntax line and the run list, 74 mentions) and every `.bxs` once (`ci.yml:139-...`); `tests/arch/suite.sh` lists 48 steps by hand (46 of 74 shell tests and all 19 `.bxs` tests are not in it); adding a test means 2 to 3 edits. Forgetting one means the test silently never runs in that environment.

Home: `tests/lib/Check.bx` (a class: `check`, `done`, `tmp`, `text`, `touch`, `frame`) and a loop in CI:

```
for t in tests/*-test.sh; do bash "$t" "$candidate"; done      # discovery, with an explicit skip file for the 5 that need other args
for t in tests/*_test.bxs; do ( cd src && matchbox "../$t" ); done
```

Quirk limits: `.bxs` helper resolution (section 1). Spike first: put `tests/Application.bx` with `this.mappings = { "/lib": ... }`, or run with `cd tests`.

Risk: low. Gain: a new test cannot be forgotten.

### H. Constants and leaks

#### F25 (Medium, effort S with F01): exit codes are numeric literals

404 literals: `say( ..., 4, ...)` 156, `0` 135, `6` 63, `2` 51; `CLIExit( 2 )` 78 in Main; `return N;` 162. The contract table (section 3) is the only definition; a typo (`5` for `6`, or the `Installer.exitCode` 5/6/7 logic) is invisible. F07 shows the symptom: the same condition (bad name) exits 2 in 3 classes and 4 in 5.

Home: name by intent, not by number, in the `Out` of F01 (`out.usage`, `out.precondition`, `out.failed`, `out.partial`, `out.drift`), because BoxLang has no constants and a `new bxrig.Exit().USAGE()` call is noisier than the number it replaces. Keep a single `Exit` class with `describe( code )` for help and the contract test (the table in `COMMAND-CONTRACT.md` section 3 is generated from it).

#### F26 (Low, effort S): strings that should be named once

- `BXRIG_*` environment names: 63 distinct, 143 references; `BXRIG_SELF` 16 times, `BXRIG_TTY_IN` 11, `BXRIG_POWER_DIR` 6. A typo returns the fallback silently. Home: names are method names on `Env` (`Env.configHome()`), listed in `docs/reference/config-files.md` by a check that greps `util/Env.bx`.
- Unit names (28 refs, F10), theme module file names (6, F20), page ids (F16), icon names (`ControlCenterPages` 17, provider `icon()` 14, `Launchers.folders` freedesktop names, `MenuTree.themeIcon` 4, `TuiKit.glyphs` 24), URLs (`https://github.com` 118 refs, `www.icloud.com` 16, `downloads.ortussolutions.com`, `skills.boxlang.io`, `try.boxlang.io` repeated in `Update`, `Skills`, `Boxlang`, `MenuTree`, `Boxlang.welcomeHtml`). Home: `Urls.bx` for first-party hosts; page and icon names through the registry of F16.
- Path literals `/.local/share/applications`, `~/.config/bxrig/*.json`: through `Env` (F03).

#### F27 (Low, effort S): encapsulation leaks, short list

1. `Shortcuts.bx:13` builds a `ConfigService` to learn the config directory; a pure data class depends on a file service. After F03 it calls `Env.config()`.
2. `KeysEditor.bx:84-88`, `Ai.bx:57`, `Secrets.bx:98,321` build the config entry struct themselves (F06, `ConfigService.entry`).
3. `AppsData.bx:18` and 13 providers use `TuiSys` for non-UI work (F02, F22).
4. `Main.bx:184-186` knows which classes own managed files (F14); `Refresh.bx:39` knows it a second time.
5. `Installer` is the process runner and the install planner; its name hides the first job (57 files `new Installer` only for `.exec`). Rename role: `Proc` (F02).
6. The same collaborator has three field names: `variables.config` (25 classes), `variables.cfgSvc` (7), `variables.cfg` (1); `variables.inst` (56) holds the runner. A reader cannot grep for "who uses ConfigService".
7. `ControlCenter.handle` mutates the app through `showPlan`/`showResult` and runs processes; the app and the runner know each other (F21 `IntentRunner` fixes the direction).

## 3. Test coverage of the review itself

This review ran no tests. Every phase below names its guards (section 10) and adds a failing-first test.

## 4. What is already good (keep it)

- Pure planners (`SetupPlan`, `InitPlan`, `Resolver`) take `facts` and return steps; they are the model for `Mutation` input.
- The injectable runner (`init( cli, runner = "" )`, 65 classes) is the right seam; F02 keeps it.
- `ConfigService` is a real service (atomic write, journal, drift); F05 and F06 route more traffic to it rather than replacing it.
- Generated data classes with `--check` in CI (8 generators) catch stale copies; F13 and F15 reuse that pattern.
- `ListPage` plus provider `actions()` is the right shape for key tables (F21 generalises it).
- `Cli.envelope` is already the single envelope builder.

## 5. Where Main.bx and cli.json overlap today (detail for F13)

`bootstrap/gen-docs.sh` already parses `case "x":` from `Main.bx` with a regex, so Main is treated as data by the build. The generator checks: every route has a cli.json entry, no stray entries, usage starts with the command name, examples start with a real route, summaries end with a full stop. It does not check: flags, arity, or that `usage` equals what Main prints. Moving those into the spec (stage 1 and 2 of F13) keeps the generator, only richer.

## 6. Counts table (single list, for tracking progress)

| Item | Now | Target |
|---|---|---|
| `function say(` definitions | 54 in 57 files | 0 (1 in `Cli`) |
| `function fail(` | 17 | 0 |
| `function tryExec(` | 33 | 0 |
| `function has(` (`command -v`) | 28 | 0 |
| `function env(` / `home()` / `self()` / `dataHome()` | 11 / 17 / 9 / 8 | 0 |
| `function merge(` | 10 | 0 |
| `function validName(` | 9 | 1 (`Names`) |
| `"pacman", "-S", "--needed", "--noconfirm"` literals | 16 in 11 files | 1 |
| `.desktop` parsers / writers | 3 / 5 | 1 / 1 |
| `jsonDeserialize( fileRead(` | 37 | 1 |
| direct `fileWrite` of settings JSON | 8 | 0 |
| `"Usage: bxrig` literals in Main | 56 | 0 |
| flag whitelist entries (duplicates) | 130 (8) | per command |
| `structKeyExists( args.options, "yes" )` | 66 | 0 |
| `fail()` in shell tests | 70 | 1 |
| `check()` in `.bxs` tests | 20 | 1 |
| test registration places | 3 | 0 (discovery) |
| numeric exit literals | 404 | 0 |

## 7. Order of operations that keeps risk low

1. Add the new class, with its own unit test, and change nothing else.
2. Migrate 2 to 3 pilot classes whose tests are strongest.
3. Mechanical migration in batches of about 10 files; each batch run against that batch's tests.
4. Delete the one-line delegates.
5. Add a **ratchet test** (`tests/dry-test.sh`, a grep script) that fails when a banned pattern reappears, with the current count as the allowed maximum; lower the maximum each batch.

## 8. Ratchet checks to add (cheap, no new framework)

```
# tests/dry-test.sh   (each line: pattern, allowed maximum; maximum goes down to the target in section 6)
count 'function say('            src/bxrig  0
count 'function tryExec('        src/bxrig  0
count 'function validName('      src/bxrig  1
count '"Usage: bxrig'            src/Main.bx 0
count 'fail() {'                 tests      1
count 'jsonDeserialize( fileRead(' src/bxrig 1
count 'getSystemSetting( "HOME"' src/bxrig  1
```

## 9. Ranked top 15 by payoff

Payoff weighs: defects it removes now, breadth (files touched), how much it unblocks, and risk/effort. "BUG" means a divergence that changes behaviour today.

| # | Finding | Why first | Effort | Risk |
|---|---|---|---|---|
| 1 | F01 `Cli.say` / `Out` | 57 files, 788 call sites, unlocks F04, F25; low risk | M | low |
| 2 | F02 `Proc` (exec, has, isRoot, run-myself) | 33+28 files; fixes a contract-2.9 shell string and the two meanings of `has` (BUG) | M | med |
| 3 | F03 `Env` paths | BUG: `dataHome` ambiguity and `XDG_CONFIG_HOME` split; tiny first step | S | low |
| 4 | F17 `DesktopEntry` | BUG: `==` parser, two dir lists, BxRig launchers leak into `apps` | M | med |
| 5 | F13 `CommandSpec` + `Options` | BUG: any flag accepted anywhere; removes the 3-way edit per flag | L | med |
| 6 | F19 shortcut table completeness and remap-shadow scan | BUG-class: likely dead binds, invisible to every tool | M | low |
| 7 | F23 shell test harness | 70 copies; makes every other phase cheaper to test | M | low |
| 8 | F04 `Mutation` plan protocol | 44 files, 89+80 hand-written plan texts, root guard enforced by hand | M | med |
| 9 | F05 `JsonStore` | BUG: 8 writers bypass the config service; 37 read sites | M | med |
| 10 | F09 `Pacman` | 16 literals, 7 installed-set parsers; one place for the `--needed --noconfirm` rule | M | low |
| 11 | F06 `ConfigService.entry` + `SystemFile` + `SystemdUnit` | 51 literals, root files with no backup, 8 hand-written unit texts | M | med |
| 12 | F10 `Systemd` | 47 refs, two `is-active` idioms, 28 unit-name literals | M | low |
| 13 | F21 `Modal` / `KeyMap` / `IntentRunner` | two copies of the confirm/ask/result machine, 32 case-sensitive key compares | M | med |
| 14 | F11 `Http` | 11 files, `-f` missing on a POST, two timeout clocks | M | low |
| 15 | F24 test discovery and `Check` | a new test can no longer be forgotten; 20 copies of `check()` | S | low |

Next in line: F14 (Main logic), F16 (page registry), F20 (Shortcuts split), F07 (names), F08 (text), F12 (desktop and engine), F18 (props), F25 (exit names, rides with F01), F15 (version), F22, F26, F27.

## 10. Phased refactor plan

Each phase is one pull request (or a short series), shippable alone, leaves `development` green, and ends with the ratchet line from section 8 lowered. "Guards" are existing tests that must stay green; "New" are tests written first.

**Phase 0: guard rails (S, 1 day)**
- Add `tests/lib/harness.sh` (F23) and migrate 5 pilot tests: `time-test.sh`, `power-test.sh`, `security-test.sh`, `help-test.sh`, `keys-test.sh`. Add `tests/dry-test.sh` (section 8) with today's counts.
- Spike `.bxs` helper resolution (F24); write `tests/lib/Check.bx` if it works.
- Guards: the 5 migrated tests, `bash -n` line in CI. New: `dry-test.sh`.

**Phase 1: foundations, no behaviour change (M, 3 days)**
- Add `Cli.say/fail/scoped` and `Out` (F01), `Proc` (F02, with `Installer.exec` forwarding), `Env` (F03, but `data()` and `xdgData()` reproduce today's two behaviours exactly), `Text`/`Fmt` (F08). Each with a `.bxs` unit test.
- Migrate `Time`, `Power`, `Security` fully as pilots.
- Guards: `time-test.sh`, `power-test.sh`, `security-test.sh`, `cli-contract-test.sh`, `installer_test.bxs`. New: `out_test.bxs`, `proc_test.bxs`, `env_test.bxs`, `text_test.bxs`.

**Phase 2: mechanical migration of the helpers (M, 3 days, 4 PRs of about 10 classes)**
- Replace the 54 `say`, 17 `fail`, 33 `tryExec`, 28 `has`, 11 `env`, 17 `home`, 9 `self`, 10 `merge` definitions with delegates, then delete the delegates. Mostly sed on exact-match lines.
- Guards: the test of each batch's classes (each batch lists them); `dry-test.sh` counts must fall.

**Phase 3: the two path bugs (S, 1 day)**
- Launchers, Editor, Strata, IconTheme use `Env.config()` and `Env.xdgData()`; `ConfigService.cfgHome` honours `XDG_CONFIG_HOME` after `BXRIG_CONFIG_HOME`. Document in `config-files.md`.
- Guards: `config-test.sh`, `launchers-test.sh`, `editor-test.sh`, `strata-test.sh`, `icon_theme_test.bxs`, `refresh-test.sh`. New: `paths-test.sh` (run with `XDG_CONFIG_HOME` and `BXRIG_CONFIG_HOME` set, assert every managed file lands under the same root).

**Phase 4: `has` meaning and run-myself (S, 1 day)**
- Decide `has` = `command -v`; switch the 30 `hasCommand` sites; keep `works()` for version checks; fix `TuiSys.has`; merge the 5 run-myself paths into `Proc.self`.
- Guards: `setup-test.sh`, `pkg-test.sh`, `packages-test.sh`, `tiling-test.sh`, `session-test.sh`, `keys-apply-test.sh`, `tui-test.sh`, `timeline-test.sh`, `control_center_test.bxs`. New: a stub-without-`--version` case in `setup-test.sh`.

**Phase 5: `DesktopEntry` (M, 2 days)**
- Add `DesktopEntry`, migrate `Apps`, `AppsData`, `AppIcons`, then the 5 writers.
- Guards: `apps-test.sh`, `apps-manager-test.sh`, `apps_manager_test.bxs`, `app_icons_test.bxs`, `app_pages_test.bxs`, `launchers-test.sh`, `web-vpn-test.sh`, `vm-test.sh`, `plasma-panels-test.sh`, `web-install-test.sh`. New: `desktop_entry_test.bxs` (lower-case key, `Name[de]`, hidden, launcher, flatpak dir).

**Phase 6: flags, usage, options (M then M, 2 PRs)**
- 6a: `flags` in `cli.json`, `gen-docs.sh` emits `CommandSpec`, Main validates per command, default branch exits 2.
- 6b: usage strings from the spec, `Options` replaces 129 `structKeyExists` reads.
- Guards: `help-test.sh`, `cli-contract-test.sh`, `native-smoke.sh`, `gen-docs.sh --check`. New: `flags-test.sh`.

**Phase 7: mutation protocol (M, 3 days, 2 PRs)**
- `Mutation` with the existing wording; migrate `Tweaks`, `Time`, `Power`, `Security`, `Nas`, `Containers`, `Cloud`, `BackupData.plan`, then the rest.
- Guards: the test of each class; `system-actions-test.sh`; `init-test.sh` (uses `InitPlan` output). New: `mutation_test.bxs` (no `--yes` exits 2, `--dry-run` exits 0 and runs nothing, first failure exits 6).

**Phase 8: tools (M, 3 days, one PR per class)**
- `Pacman` (F09), `Systemd` (F10), `Http` (F11). Each replaces call sites and lowers its ratchet line.
- Guards: tests that log fake `pacman`, `systemctl`, `curl` argv (grep for `--needed --noconfirm`, `enable --now`, `--max-time`): `containers-test.sh`, `nas-test.sh`, `macextras-test.sh`, `update-test.sh`, `skills-test.sh`, `sdk-test.sh`, `java-test.sh`, `mail-test.sh`, `strata-test.sh`, `boxlang-test.sh`.

**Phase 9: config traffic through the service (M, 3 days)**
- `JsonStore` (F05), `ConfigService.entry`, `SystemFile`, `SystemdUnit` (F06); add the missing managed files to `config list` and move the managed list out of Main (F14).
- Guards: `config-test.sh`, `config-native-test.sh`, `appearance-test.sh`, `display-test.sh`, `theme-test.sh`, `nas-test.sh`, `backup-data-test.sh`, `skills-test.sh`, `update-test.sh`, `refresh-test.sh`. New: `config-list-test.sh` (every managed file written by any command appears in `config list`).

**Phase 10: shortcuts (M, 3 days)**
- F19 first (fixed rows, remap-shadow scan), then F20 (`KeyCombo`, `LuaModule`, renderers).
- Guards: `shortcuts_test.bxs`, `keys-test.sh`, `keys-editor-test.sh`, `keys-apply-test.sh`, `xremap-test.sh`, `hyprland-setup-test.sh`, `noctalia-config-test.sh`, `theme-test.sh`, `appearance-test.sh`, `display-test.sh`. New: `remap_shadow` case in `shortcuts_test.bxs`.

**Phase 11: TUI (M, 4 days)**
- `Modal`, `KeyMap`, `IntentRunner`, `TuiKit.starfield`, remove view forwarders, page registry and `ProviderSpec` (F16, F21, F22).
- Guards: `tui_kit_test.bxs`, `wizard_app_test.bxs`, `wizard_view_test.bxs`, `time_machine_test.bxs`, `control_center_test.bxs`, `app_pages_test.bxs`, `tui-test.sh`, `timeline-test.sh`, `wizard-test.sh`, the `pty-frame.py` runs.

**Phase 12: finish (S, 1 day each)**
- Test discovery in CI and `suite.sh` (F24), version single source (F15), `Names` (F07), `Urls` (F26), the 7 leaks of F27, move Main's remaining logic (F14).
- Guards: `ci.yml` itself on a branch; `gen-*.sh --check`.

Order rationale: phases 0 to 4 are small, low-risk and make every later phase cheaper; phases 3 and 5 fix real bugs early; phase 6 is the largest user-visible change and comes after the helpers are stable.

## 11. Rules for the contributing docs (add to `docs/guides/contributing.md`)

1. **One home per concept.** Before writing a helper, `grep -rn "function NAME" src/`. If it exists anywhere, use or move it; never paste it.
2. **A command class never defines `say`, `fail`, `tryExec`, `has`, `env`, `home`, `self`, `merge` or `validName`.** Use `Cli`/`Out`, `Proc`, `Env`, `Text`, `Names`. `tests/dry-test.sh` enforces it.
3. **Never read `HOME`, `XDG_*` or `BXRIG_*_HOME` directly.** Ask `Env`. New environment overrides for tests are added to `Env` and listed in `docs/reference/config-files.md`.
4. **Run programs only through `Proc`**, with an argv array, never `sh -c` plus concatenation. A command is "present" if `Proc.has` says so; `Proc.works` is for version checks only.
5. **External tools have one wrapper each**: `Pacman` for pacman, yay and flatpak, `Systemd` for systemctl and units, `Http` for curl. No new literal `"pacman", "-S"` or `"curl"` outside them.
6. **Every mutating verb is a `Mutation`.** No `--yes` prints the plan and exits 2; `--dry-run` prints it and exits 0; the first failed step exits 6. Do not write the sentences again.
7. **Every file BxRig writes goes through `ConfigService`** (user files) or `SystemFile` (root files): backup, atomic replace, journal. Settings JSON goes through `JsonStore`. No bare `fileWrite` outside those classes.
8. **A new command is one edit in `docs/reference/cli.json`** (name, flags, usage, examples) plus its class. Main routes, validates flags and prints usage from the generated spec; do not add a flag to a whitelist or a `"Usage:"` string in Main.
9. **Name exit codes by intent** (`out.usage`, `out.precondition`, `out.failed`), never a bare number, and do not invent new codes; the table in the contract is the only list.
10. **Shortcuts, pages, units, theme module files, icon names and URLs are declared once** (`Shortcuts.table`, `ControlCenterPages`, `UnitNames`, `ThemeFiles`, `Urls`) and generated into every other place. A hand-written bind, page list or unit name outside them needs a reason in the PR.
11. **Parse each format once.** `.desktop` through `DesktopEntry`, `key=value` through `Props`, JSON through `JsonStore`. Compare exact-case keys with `compare()`, never `==` (strings compare case-insensitively on MatchBox).
12. **Respect the MatchBox quirks in shared code:** no base classes (compose and delegate), no closures that call class methods, no postfix operators on indexes, build large struct literals stepwise, check a JSON key exists before reading it.
13. **TUI screens paint with `TuiKit` and use `Modal`, `KeyMap` and `IntentRunner`.** Footer hints and key handlers come from the same `KeyMap`; do not keep two lists. Fixtures live in a `*Demo` class, not in the provider.
14. **Tests source `tests/lib/harness.sh` and `tests/lib/Check.bx`.** Do not define `fail`, `run`, `code` or `check` again. Stubs of `sudo`, `id`, `pacman`, `systemctl` come from the library. Tests are discovered by name (`*-test.sh`, `*_test.bxs`); do not edit CI lists.
15. **Generated files stay generated** (`*Data.bx`, `CommandSpec.bx`, `Version.bx`): change the source, run the generator, commit both, and CI `--check` keeps them honest.
16. **Version, command names and flags are written once.** A release bump edits `box.json` only.

## Appendix A: how the numbers were produced

Run from `/home/user/bxcachy`:

```
grep -h "function say" src/bxrig/*.bx | sed 's/^ *//' | sort | uniq -c | sort -rn      # say variants
grep -c "function has(" src/bxrig/*.bx | awk -F: '$2>0'                                  # has copies
grep -n "function dataHome\|function cfgHome\|function home()" src/bxrig/*.bx           # path helpers
grep -c "jsonDeserialize( fileRead(" src/bxrig/*.bx                                      # settings reads
grep -n '"pacman", "-S", "--needed", "--noconfirm"' src/bxrig/*.bx                      # install literal
grep -c "^fail()" tests/*.sh | awk -F: '$2>0' | wc -l                                    # test harness copies
python3 -c "import re;s=open('src/Main.bx').read();..."                                  # flag whitelist: 130 entries, 122 distinct
```

Counts are line-based and can over- or under-count by a few where a definition spans lines; none of the conclusions depends on an exact number. Behavioural claims marked "verify" (default branch exit code, dead Hyprland binds under xremap, case-insensitive struct keys) were read from code, not run.
