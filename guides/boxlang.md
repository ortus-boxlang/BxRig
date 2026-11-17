---
title: BoxLang and MatchBox
order: 6
summary: The BoxLang developer ecosystem on your machine.
---

# BoxLang and MatchBox

The installer puts in Java 21, **bvm** (BoxLang Version Manager), **mvm** (MatchBox Version Manager), BoxLang and MatchBox. `bxrig boxlang` sits on top of them.

```bash
bxrig boxlang status
bxrig boxlang use latest              # bvm: install if missing, then use
bxrig boxlang use snapshot
bxrig boxlang matchbox use latest     # mvm
bxrig boxlang matchbox status         # the MatchBox home, config, .env files and logs
bxrig boxlang matchbox log-level info --yes
bxrig boxlang matchbox env list       # the names in ~/.matchbox.env, never the values
bxrig boxlang modules list            # the live ForgeBox list
bxrig boxlang modules search ai
bxrig boxlang modules install bx-ai bx-sites
bxrig boxlang modules update
bxrig boxlang vscode                  # the BoxLang extension and developer pack
bxrig boxlang links                   # docs and sites
bxrig boxlang welcome                 # a getting-started page
```

Modules come from [ForgeBox](https://forgebox.io) and install with `bx-module`. VS Code is a default app; the wizard offers to add the BoxLang extension (`ortus-solutions.vscode-boxlang`) and the developer pack.

## The MatchBox home, `.env` files and logs

MatchBox follows the BoxLang CLI. On its first run it creates `~/.matchbox` (move it with `MATCHBOX_HOME`) holding `config/boxlang.json` and `logs/`. Every run also reads two `.env` files: `~/.matchbox.env` (yours) and `.env` in the directory you run from, where the project file wins. Scripts read the values with `getSystemSetting()`. BxRig is a MatchBox program, so it reads them too.

`bxrig boxlang matchbox status` shows where everything is. `log-level` changes `logging.rootLevel` in the home config and leaves its comments alone. `env set` writes one line to `~/.matchbox.env` (mode 600) and `env unset` removes it. The first command to change something prints a plan, and `--yes` applies it. Values are never printed.

```bash
bxrig boxlang matchbox env set OPENAI_API_KEY sk-... --yes
bxrig boxlang matchbox log-level debug --yes
```

These files and folders belong to MatchBox releases that have a runtime home. With an older MatchBox the commands still work on the files, but nothing reads them.

## Compile to a native binary

```bash
matchbox script.bxs
```

[MatchBox](https://matchbox.boxlang.io) compiles BoxLang to bytecode on a Rust runtime and can build standalone native binaries. BxRig itself is built this way.

## Links

[Try BoxLang](https://try.boxlang.io) · [Docs](https://boxlang.ortusbooks.com) · [BoxLang AI](https://ai.boxlang.io) · [BoxLang Agents](https://bxagents.ai) · [BoxLang Sites](https://bxsites.io) · [ForgeBox](https://forgebox.io) · [Skills](https://skills.boxlang.io)
