# Agent Instructions

<!-- bmad:context -->
<!-- Verified 2026-09-28 against initial state (no commits yet). Managed by bmad-project-context; edits inside this block are replaced on refresh. Keep anything you want preserved outside the markers. -->

## secure-data-and-inventory-system

Roblox secure-data + inventory system. Luau, Rojo 7.7.0 via aftman, stylua + selene. Planning lives in `skills/planning-artifacts/`, sprint/story tracking in `skills/implementation-artifacts/`.

## Policy

- All DataStore access is server-side only. The client never reads or writes player data — it sends RemoteEvent requests and the server validates before touching data.
- Never hand-edit `*.rbxlx`; it is a gitignored build output. Change `src/` and rebuild.

## Where things are

- Rojo mapping (source of truth: `default.project.json`): `src/shared` → ReplicatedStorage.Shared, `src/server` → ServerScriptService.Server, `src/client` → StarterPlayer.StarterPlayerScripts.Client.
- Entry points: `src/server/init.server.luau`, `src/client/init.client.luau`, `src/shared/Hello.luau`.

## Running and verifying

- `rojo`, `aftman`, `stylua`, `selene` live in `~/.aftman/bin`, which is NOT on PATH — prefix every invocation: `PATH="$HOME/.aftman/bin:$PATH" <cmd>`.
- Build: `rojo build default.project.json -o "secure-data-and-inventory-system.rbxlx"`.
- Format check `stylua --check src/` and lint `selene src/` must both pass before review.

## Conventions that differ from defaults

- Tab indentation, not spaces — run stylua rather than hand-formatting (`stylua.toml`).
- Requires are Roblox instance-based (`require(script.Parent.X)`); there is deliberately no `.luaurc`.

<!-- /bmad:context -->
