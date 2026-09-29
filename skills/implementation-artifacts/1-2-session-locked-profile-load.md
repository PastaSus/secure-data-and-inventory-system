# Story 1.2: Session-Locked Profile Load

Status: ready-for-dev

## Story

As a player,
I want my collection stored in a session-locked profile that loads with forward-only migration,
so that my data survives rejoins and can never be silently reset.

## Acceptance Criteria

1. **AC1 — Pinned toolchain resolves.** Given Wally `0.3.2` is installed and `wally.toml` pins ProfileStore `1.0.3`, when the dev runs `wally install`, then `wally.lock` exists and the ProfileStore package is vendored on disk (no failed-open `wally.toml` error). [Source: epics.md#Story 1.2]
2. **AC2 — Session lock before gameplay.** When the server starts a session for a joining player, `DataService.startSession` obtains a ProfileStore session lock before any gameplay begins (returns success/failure; it does NOT itself kick, snapshot, or release into gameplay — that wiring is Story 1.3). [Source: epics.md#Story 1.2; game-architecture.md#Session Load Gate]
3. **AC3 — Forward-only migration.** Profile data carries a `schemaVersion`; migration runs forward-only and never decreases it. Fresh profiles get current defaults; older-schema profiles migrate up with existing items preserved. [Source: epics.md#Story 1.2]
4. **AC4 — Minimal schema (data created only when required).** The profile schema includes ONLY what this story needs: `schemaVersion`, vault items (with provenance fields), and vault capacity (start 8). `tradeReceipts` / pending-trade state is NOT created here — Story 4.1 creates it at first use. (`setsCompleted` is likewise deferred; later stories add fields via forward migration.) [Source: epics.md#Story 1.2; implementation-readiness-report-2026-09-28.md#Major Issues]
5. **AC5 — No synchronous saves on the player path (NFR2).** No synchronous `SetAsync` occurs on the player-facing path; persistence is ProfileStore-owned (session + auto-save ~300s + BindToClose flush). Never call `DataStoreService` directly. [Source: epics.md#Story 1.2; game-architecture.md#Data Persistence]
6. **AC6 — Migration is TestEZ-covered.** TestEZ covers the migration function for a fresh profile and an older-schema profile. [Source: epics.md#Story 1.2]

## Tasks / Subtasks

- [ ] Task 1 — Pin and vendor dependencies (AC: 1)
  - [ ] 1.1 Add `wally.toml` (`[dependencies] ProfileStore = "lm-loleris/profilestore@1.0.3"`, TestEZ as dev-dependency — see Library section for the 0.4.2/0.4.1 caveat)
  - [ ] 1.2 Run `wally install`; verify `wally.lock` + vendored package dir on disk
  - [ ] 1.3 Wire the SMALLEST Rojo mapping that makes ProfileStore requirable from `src/server` only (never replicate server packages to the client); document the mapping choice in the File List
- [ ] Task 2 — Minimal profile schema + pure migration (AC: 3, 4)
  - [ ] 2.1 Create `src/shared/Config/GameConfig.luau` with ONLY `startCapacity = 8` (no pack size, trade timeout, rarity — later stories)
  - [ ] 2.2 Create `src/shared/Types.luau` with ONLY v1 needs: `ProfileData` (`schemaVersion`, `vault: {[number]: number}`, `provenance: {ProvenanceEntry}`, `capacity: number`) + `ProvenanceEntry`; no trade types
  - [ ] 2.3 Create pure migration module `src/shared/Schema.luau` (`CURRENT_SCHEMA_VERSION = 1`, `defaultProfile()`, `migrate(data)` — pure, no DataStore/game services, `--!strict`, tabs); never decreases `schemaVersion`, preserves existing vault entries
- [ ] Task 3 — `DataService.startSession` session lock (AC: 2, 5)
  - [ ] 3.1 Create `src/server/Services/DataService.luau` (module singleton, `--!strict`): `startSession(player): boolean`, key `Player_<UserId>`, `pcall` around the ProfileStore boundary, `Migrate/Schema.run` after lock acquisition, store profile in module table keyed by `UserId`
  - [ ] 3.2 `startSession` returns `(true)` on lock+migrate success, `(false)` on any failure — NO kick, NO snapshot push, NO gameplay release (Story 1.3 owns all three); NO `SetAsync`, NO direct `DataStoreService`
  - [ ] 3.3 Do NOT touch `init.server.luau` wiring beyond making the module requirable (no auto-start on PlayerAdded yet — Story 1.3)
- [ ] Task 4 — TestEZ coverage + gates (AC: 6)
  - [ ] 4.1 Add `tests/project.json` (test-only Rojo map, NOT in the production place) + `tests/Schema.spec.luau`: fresh-profile case (defaults, version 1, capacity 8) and older-schema case (v0/missing version → migrated up, items preserved, version never decreases)
  - [ ] 4.2 Run full gates: `rojo build default.project.json -o "secure-data-and-inventory-system.rbxlx"`, `stylua --check src/`, `selene src/` — all green; record TestEZ run method/result in Completion Notes (Studio runner; no CI exists)
- [ ] Task 5 — Close-out
  - [ ] 5.1 Update Dev Agent Record (model, debug log, completion notes), File List, Change Log; set Status `review`; set `sprint-status.yaml` `1-2-session-locked-profile-load: review`
## Dev Notes

### Technical Requirements

- Luau, `--!strict` on every NEW ModuleScript; tab indentation (run stylua, never hand-format); `task.wait/spawn/defer` only (never `wait()/spawn()/delay()`).
- Requires are Roblox instance-based (`require(script.Parent.X)`); there is deliberately no `.luaurc`.
- `DataService` pattern to follow (from architecture — adapt names to real ProfileStore v1 API read from the vendored package, NOT from memory):
```luau
function DataService.startSession(player: Player): boolean
	local profile, err = ProfileStore:StartSessionAsync(PROFILE_KEY(player), ...)
	if not profile then return false end
	Migrate.run(profile.Data)
	_profiles[player.UserId] = profile
	return true
end
```
- Migration MUST run before the first snapshot reaches the client (Story 1.3 sends the snapshot; this story guarantees the data it will send is already migrated).
- 4MB/key discipline starts here: compact `{[itemDefId]: count}` + bounded provenance (cap 50, oldest rotates out per ADR-004). No per-item blobs.

### Library / Framework Requirements

- `aftman.toml` already pins `wally = "UpliftGames/wally@0.3.2"` (Story 1.1). If `wally` reports command-not-found, the shell has a stale PATH (VS Code started before the User-PATH entry existed): restart VS Code or prefix `PATH="$HOME/.aftman/bin:$PATH"`.
- ProfileStore: `lm-loleris/profilestore@1.0.3` — scope is `lm-loleris`, NOT `madstudioroblox` (that string is only the GitHub org URL in the brief addendum; the Wally scope is `lm-loleris`, registry-verified).
- TestEZ version caveat (measured 2026-09-29): architecture says `roblox/testez@0.4.2`, but the Wally registry publishes only `0.4.1` (upstream tagged v0.4.2 without publishing). Attempt `0.4.2` first; on registry 404 fall back to `0.4.1` and record the actual pinned version in the File List + Completion Notes. Do NOT vendor TestEZ by hand.
- Wally is realm-aware and ProfileStore's realm is `server`: after `wally install`, check whether it created `Packages/` or `ServerPackages/` and map accordingly (server-side only). Never hand-edit vendored packages.
- STOP `rojo serve` before `aftman install` on Windows (file-lock `os error 32`), then restart serve. `wally install` does NOT need serve stopped; `rojo build` is unaffected by serve either way.

### File Structure Requirements

```
wally.toml / wally.lock              # NEW (this story)
src/shared/Config/GameConfig.luau    # NEW — only startCapacity = 8
src/shared/Types.luau                # NEW — ProfileData (minimal v1) + ProvenanceEntry only
src/shared/Schema.luau               # NEW — CURRENT_SCHEMA_VERSION, defaultProfile(), migrate()
src/server/Services/DataService.luau # NEW — startSession only
tests/project.json                   # NEW — test-only map, excluded from production place
tests/Schema.spec.luau               # NEW — fresh + older-schema cases
```

- Do NOT create: `Log.luau`, `Signal.luau`, `Validate.luau`, `RarityConfig`, `ItemDefs`, `SetDefs` (later stories), `RemoteService`, `VaultService`, any client controller, any `ReplicatedStorage.Remotes/` folder.
- Do NOT modify `default.project.json` beyond the minimal server-side package mapping; do NOT touch `src/server/init.server.luau` behavior, `src/client/*`, `src/shared/Hello.luau` (scaffold — delete only when services land, not here).
- Git cannot track empty dirs: every new file above must be real content, so this story leaves no empty-dir gaps.

### Testing Requirements

- TestEZ specs for PURE logic only: `Schema.migrate()` takes plain tables, returns plain tables — no Players, no DataStore, no game services in the spec.
- Cases: (a) fresh/nil input → defaults (`schemaVersion=1`, `vault={}`, `provenance={}`, `capacity=8`); (b) older-schema (missing/0 version, pre-existing vault entries) → migrated to 1, entries preserved, version never decreases; (c) current-version input → untouched (idempotent).
- Studio Play / Team Test for integration; `Log.info` diagnostics must be Studio-gated (`RunService:IsStudio()`). No CI exists — record how TestEZ was executed.
- Quality gates (must pass before review): `rojo build`, `stylua --check src/`, `selene src/`.

### Scope Guard — What NOT To Build (1.3 / 1.4 own these)

- NO `player:Kick(...)`, NO join-gate release, NO initial snapshot push, NO `Log` wrapper module (Story 1.3).
- NO RemoteEvents, NO rate limiting, NO `StateMirror`, NO test-view UI (Story 1.4).
- NO trade state, NO `tradeReceipts`, NO `setsCompleted` in the schema (Story 4.1 / Epic 3 via future migrations).
- A handlerless `DataService` that nobody calls yet is CORRECT at the end of this story — 1.3 wires it up.

### Architecture Compliance (boundaries — violations are defects)

1. **Path is permission:** `src/server/` may touch profile data; `src/shared/` must be importable from both sides and must NEVER `require` server or client modules.
2. **Only `DataService` reads/writes `Profile.Data`.** Nothing else holds its own copy of profile data.
3. **Only `RemoteService` registers remote handlers** — this story creates NO remotes and connects NO `OnServerEvent` (Story 1.4 owns the pipeline).
4. **Config tables are read-only** — never mutate `GameConfig` at runtime.
5. **No cross-layer require** except client/shared → shared, server → shared.

### Previous Story Intelligence (1.1 — what the next dev must reuse)

- `aftman install` + full gates were green post-install (`rojo 7.7.0`, `stylua 2.5.2`, `selene 0.31.0`, `wally 0.3.2` binaries verified).
- Windows gotcha: stop `rojo serve` before `aftman install` or it dies with `os error 32` (alias rewrite vs running binary); order stop → install → restart.
- `rojo build` EMITS empty dirs as `Folder` instances but `rojo sourcemap` OMITS them (LSP can't resolve until real modules land) — this story lands real modules, closing that gap for its files.
- Script source in `.rbxlx` is `<string name="Source"><![CDATA[...]]></string>`, not `ProtectedString` — grep CDATA when verifying artifact contents.
- `src/shared/Hello.luau` is dead code (returns an uncalled function; nothing requires it) — do not require, imitate, or delete it here.
- `serve` is a live-sync HTTP server on `127.0.0.1:34872` (Studio clicks Connect); `build` is the static artifact. ACs need `build` only.
- Human step outstanding from 1.1: opening the built `.rbxlx` in Studio (agent cannot launch the GUI).

### Git Intelligence Summary

- Story branch `feat/story-1-2-session-locked-profile-load` already exists (created during 1.1 close-out). All `wally.toml` + `src/` + `tests/` work goes there, atomically (`chore:` for wally pin, `feat:` for DataService/schema, `test:` for specs).
- 1.1 updated `aftman.toml` (+wally), `.gitattributes` (`eol=lf`), `AGENTS.md` gotchas; its story file sits at `skills/implementation-artifacts/1-1-project-structure-on-the-existing-scaffold.md` (status `review`→`done` after the human Studio check).
- Do NOT commit `*.rbxlx`, `Packages/`/`ServerPackages/`, `sourcemap.json`, or throwaway `review-prompts/` sketches.

### Latest Tech Information

- ProfileStore v1 (lm-loleris): `StartSessionAsync(key, params)` → session-locked `Profile` with in-memory `.Data`; auto-save default ~300s; `game:BindToClose` flush handled internally. READ THE VENDORED PACKAGE SOURCE after `wally install` for exact constructor/params (`CreateStore` vs `New` naming, mock-DataStore behavior in Studio) — do not trust training-data API shapes.
- Studio path uses ProfileStore's mock DataStore but MUST flow through the same `startSession` gate (Story 1.3 verifies; this story must not special-case Studio).
- Wally lockfile (`wally.lock`) is the reproducibility contract — commit both `wally.toml` and `wally.lock`.

### Project Structure Notes

- Alignment: exactly the architecture's Project Structure tree — `Services/` holds one file per service (`DataService.luau` first), shared pure modules at `src/shared/`, specs in `tests/` (NOT in production place).
- Variance: architecture's full `ProfileData` (with `setsCompleted`, `tradeReceipts`) is the END-STATE shape; this story deliberately implements the minimal v1 subset per the readiness remediation. Future fields arrive via forward migration, never by editing old saves in place.

### Project Context Rules

- All DataStore access server-side only; client never reads/writes player data (AGENTS.md Policy). This story creates no client code at all.
- Never hand-edit `*.rbxlx` (gitignored build output); change `src/` + maps and rebuild.
- `stylua.toml` requires LF line endings — `.gitattributes` pins `eol=lf`; do not commit CRLF.
- Roblox Studio cannot be driven from an agent session: verify the `.rbxlx` structurally and mark any Studio-open step as human confirmation.
- Commit atomically on the story branch `feat/story-1-2-session-locked-profile-load` (already created); Conventional Commits with bullet body. Docs-only fixes may land on default branch; all `src/` + `wally.toml` work stays on the branch.

### References

- [Source: skills/planning-artifacts/epics.md#Story 1.2] — canonical ACs (GWT).
- [Source: skills/planning-artifacts/game-architecture.md#Session Load Gate] — `startSession` gate code + never-default rule.
- [Source: skills/planning-artifacts/game-architecture.md#Data Persistence] — ProfileStore ownership, `Player_<UserId>` keys, no direct DataStoreService, auto-save 300s.
- [Source: skills/planning-artifacts/game-architecture.md#Architectural Decisions #3, #8, #16] — ProfileStore 1.0.3, count-map + bounded provenance, TestEZ.
- [Source: skills/planning-artifacts/game-architecture.md#Project Structure] — directory tree, naming (PascalCase modules, `<Module>.spec.luau`), boundaries.
- [Source: skills/planning-artifacts/game-architecture.md#Development Environment] — setup commands, first steps.
- [Source: skills/planning-artifacts/implementation-readiness-report-2026-09-28.md] — READY verdict; 1.2 narrowed (trade state deferred to 4.1); keep-1.4-lean flag.
- [Source: skills/planning-artifacts/gdd.md#Technical Specifications] — atomic commits, debounced saves, per-player rate limits (context; rate limits land in 1.4).
- [Source: AGENTS.md] — policy, Rojo map source of truth, build/verify commands, Windows gotchas.

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

### Change Log

