# Agent Instructions

<!-- bmad:context -->
<!-- Verified 2026-09-29 (2 commits). Managed by bmad-project-context; edits inside this block are replaced on refresh. Keep anything you want preserved outside the markers. -->

## secure-data-and-inventory-system

Roblox secure-data + inventory system. Luau, Rojo 7.7.0 via aftman, stylua + selene. Planning lives in `skills/planning-artifacts/`, sprint/story tracking in `skills/implementation-artifacts/`.

## Policy

- All DataStore access is server-side only. The client never reads or writes player data — it sends RemoteEvent requests and the server validates before touching data.
- Never hand-edit `*.rbxlx`; it is a gitignored build output. Change `src/` and rebuild.

## Where things are

- Rojo mapping (source of truth: `default.project.json`): `src/shared` → ReplicatedStorage.Shared, `src/server` → ServerScriptService.Server, `src/client` → StarterPlayer.StarterPlayerScripts.Client.
- Entry points: `src/server/init.server.luau`, `src/client/init.client.luau`, `src/shared/Hello.luau`.

## Running and verifying

- Tools (`aftman`, `rojo`, `stylua`, `selene`, `wally`) are installed under `~/.aftman/bin`. That directory is on this machine's User PATH, so bare commands work in a freshly started shell — but any process started before the PATH entry existed (e.g. a long-running editor) inherits a stale environment. If a tool reports "command not found", prefix it: `PATH="$HOME/.aftman/bin:$PATH" <cmd>`.
- Build: `rojo build default.project.json -o "secure-data-and-inventory-system.rbxlx"`.
- Format check `stylua --check src/` and lint `selene src/` must both pass before review.
- `wally install` cannot run until Story 1.2 adds `wally.toml`; it currently fails with `failed to open file .\wally.toml`.

## Conventions that differ from defaults

- Tab indentation, not spaces — run stylua rather than hand-formatting (`stylua.toml`).
- Requires are Roblox instance-based (`require(script.Parent.X)`); there is deliberately no `.luaurc`.

<!-- /bmad:context -->

## Git workflow

Durable — deliberately outside the managed block above, which is regenerated on refresh.

- **Actual code changes go on a conventional branch**, e.g. `feat/`, `fix/`, `chore/`, `docs/` plus a short slug: `chore/story-1-2-wally-profilestore`.
- **Commit atomically** — one logical change per commit, Conventional Commits (`type: subject` with a bullet body), matching the existing history.
- Documentation- and tracking-only changes may land directly on the default branch.

## Windows / toolchain gotchas

Durable — these cost a real dev session on 2026-09-29; keep them where the next agent will look.

- **Stop `rojo serve` before running `aftman install`.** Aftman's `~/.aftman/bin/*.exe` entries are copies of `aftman.exe` that dispatch by filename, so `aftman install` rewrites all of them. A running `rojo serve` (e.g. the VS Code Rojo extension) holds `rojo.exe` open and the install dies with `os error 32`, aborting before later tools are even downloaded. Order: stop serve → `aftman install` → restart serve.
- **`.gitattributes` pins `eol=lf` on purpose.** `stylua.toml` requires Unix line endings; without this file, Windows' default `core.autocrlf=true` converts to CRLF on checkout and `stylua --check src/` fails (verified: exit 1) on any fresh clone.
- **Roblox Studio cannot be driven from an agent session.** `rojo build` output can be verified structurally (well-formed XML, expected instances, script sources), but "opens in Studio" is always a human confirmation step.
- **Regenerate `sourcemap.json` after adding modules, then Reload Window in VS Code.** The Luau extension resolves `require()` through `sourcemap.json`; a stale map makes every new require error (≈100 bogus Problems). Run `rojo sourcemap default.project.json -o sourcemap.json` (gitignored output, safe), then `Ctrl+Shift+P` → "Reload Window" — the editor holds the old map in memory until reloaded.
