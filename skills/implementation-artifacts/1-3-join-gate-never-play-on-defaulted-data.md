---
baseline_commit: 4e7994433895f50e300af704677c622860cf9e2f
---

# Story 1.3: Join Gate — Never Play on Defaulted Data

Status: ready-for-dev

## Story

As a player,
I want the game to either load my real data or tell me to rejoin,
so that a failed load can never create a ghost copy of my inventory.

## Acceptance Criteria

1. **AC1 — Kick on failed load, never defaulted gameplay.** Given a player joins and session lock acquisition fails (lock conflict, DataStore outage, non-table data, migration failure), when `startSession` returns failure, then the player is kicked with exactly "Could not load your data. Please rejoin." and is never released into gameplay with default data (Session Load Gate pattern, ADR-001). [Source: epics.md#Story 1.3; game-architecture.md#Session Load Gate]
2. **AC2 — Release + initial snapshot on success.** Given the session lock succeeds, when migration completes, then the player is released into the game (character only loads after the gate opens) and receives their initial data snapshot — a plain deep copy of the migrated `ProfileData`, fired once via a server→client RemoteEvent. [Source: epics.md#Story 1.3; game-architecture.md#Session Load Gate data flow]
3. **AC3 — Structured logging on both paths.** The success path emits `Log.info` and the failure path emits `Log.error` with context (`userId`, machine-readable reason); no profile payloads or item contents are ever logged. [Source: epics.md#Story 1.3; game-architecture.md#Logging]
4. **AC4 — Same gate in Studio.** The Studio path (ProfileStore mock DataStore) goes through the identical gate — no `IsStudio()` branching in gate logic. [Source: epics.md#Story 1.3; game-architecture.md#Session Load Gate edge cases]
5. **AC5 — Load is bounded, session is released, double-start guarded.** A hung `StartSessionAsync` is bounded by a join timeout and resolves to the AC1 kick; the session lock is released when the player leaves; a second `startSession` for a player who already holds a profile is refused instead of overwriting; `ProfileStore.New` runs inside a `pcall`. (Deferred from Story 1.2 review, explicitly assigned to 1.3.) [Source: skills/implementation-artifacts/deferred-work.md; 1-2 story Review Findings; DataService.luau:17,34-40,47]
6. **AC6 — Snapshot builder is TestEZ-covered.** TestEZ covers the pure snapshot builder: field equality with source, deep-copy independence (mutating the snapshot never touches `ProfileData`), provenance array copied. [Source: game-architecture.md#Testing Strategy]

## Tasks / Subtasks

- [ ] Task 1 — `Log` wrapper module (AC: 3)
  - [ ] 1.1 Create `src/shared/Log.luau` implementing the architecture's Logging section verbatim: `Log.info` (Studio-gated `print`), `Log.warn`, `Log.error` (always `warn`), format `[Context] message {data-table}`, `--!strict`, tabs
  - [ ] 1.2 Keep it shared-pure: no requires of server/client modules; no external logging service
- [ ] Task 2 — Pure snapshot builder (AC: 2, 6)
  - [ ] 2.1 Add `Schema.snapshot(data)` to `src/shared/Schema.luau`: returns a deep plain copy of the v1 profile fields (`schemaVersion`, `vault`, `provenance`, `capacity`) — independent tables so client-side mutation can never alias `Profile.Data`
  - [ ] 2.2 Add spec cases to `tests/Schema.spec.luau`: field equality, deep-copy independence (mutate `snapshot.vault` → source unchanged), provenance entries copied not shared
- [ ] Task 3 — DataService hardening + session lifecycle (AC: 1, 3, 5)
  - [ ] 3.1 Move `ProfileStore.New(...)` inside a `pcall` (lazy or module-level with protected failure flag) so a throwing constructor makes `startSession` return `false` instead of crashing requirers [deferred: DataService.luau:17]
  - [ ] 3.2 Bound the load: add `joinLoadTimeout = 10` (seconds) to `src/shared/Config/GameConfig.luau` and make `startSession` resolve `false` after the deadline — extend `Cancel` to return true past the deadline and verify in the vendored ProfileStore source that `cancel_condition` is polled during DataStore yields; if a single cancel check cannot bound a hang, add a backstop (e.g. `task.delay` → force-fail) so AC5 holds [deferred: DataService.luau:34-40]
  - [ ] 3.3 Add `DataService.endSession(player)`: call `Profile:EndSession()` on the stored profile (vendored source line ~1090) and remove `_profiles[UserId]`; no-op if no profile or profile already inactive
  - [ ] 3.4 Guard double-start: if `_profiles[player.UserId]` already exists, return `false` (and `Log.warn`) instead of overwriting the live session [deferred: DataService.luau:47]
  - [ ] 3.5 Add `DataService.getSnapshot(player): ProfileData?` — `Schema.snapshot` of the held profile, `nil` if none; only this module reads `Profile.Data`
  - [ ] 3.6 Structured logging on every failure branch (`lock_failed`, `bad_data`, `migrate_failed`, `timeout`, `double_start`, `store_init_failed`) via `Log.error`/`Log.warn`, and `Log.info` on success — context only, never payload (AC3)
- [ ] Task 4 — Join gate wiring (AC: 1, 2, 4)
  - [ ] 4.1 Rewrite `src/server/init.server.luau` with the architecture's Init/Start lifecycle: synchronous `Init()` pass, then `task.spawn`'d `Start()` pass; remove the hello-world print
  - [ ] 4.2 In `Init()`: set `Players.CharacterAutoLoads = false` **before** any player can spawn, and create `ReplicatedStorage.Remotes` folder + one RemoteEvent `Snapshot` via `Instance.new` at runtime (no `.rbxlx`/`default.project.json` edits; client uses `WaitForChild` with timeouts per architecture Networking)
  - [ ] 4.3 In `Start()`: connect `Players.PlayerAdded` **and** loop `Players:GetPlayers()` (belt-and-braces for anyone already in) → gate flow: `startSession` → on `true`: fire `Snapshot` with `getSnapshot(player)`, then `player:LoadCharacter()` (release; guard `player.Parent == Players`) → on `false`: `player:Kick("Could not load your data. Please rejoin.")`
  - [ ] 4.4 Connect `Players.PlayerRemoving` → `DataService.endSession(player)`
  - [ ] 4.5 No `IsStudio()` branch anywhere in the gate — Studio mock DataStore flows the identical path (AC4)
  - [ ] 4.6 Delete dead scaffold `src/shared/Hello.luau` (architecture: "delete when services land" — services are wired by this story) and the client hello print
- [ ] Task 5 — Client snapshot receive (AC: 2)
  - [ ] 5.1 In `src/client/init.client.luau`: `WaitForChild("Remotes", timeout):WaitForChild("Snapshot", timeout)`, connect once, store the payload in a local read-only table (top-level `table.freeze`) with a comment that Story 1.4 replaces this with `StateMirror`
  - [ ] 5.2 No client→server traffic of any kind (ADR-002; no RemoteFunctions)
- [ ] Task 6 — TestEZ + quality gates (AC: 6)
  - [ ] 6.1 Run the documented gates: `rojo build default.project.json -o "secure-data-and-inventory-system.rbxlx"`, `stylua --check src/ tests/`, `selene src/` (never `selene tests/` — TestEZ globals are undefined by design)
  - [ ] 6.2 TestEZ Studio run is a **human step** (build `tests.project.json` → open in Studio → `TestEZ.TestBootstrap:run({RS.Tests}, TestEZ.Reporters.TextReporter)`); record pass/fail counts in Completion Notes before `review`
- [ ] Task 7 — Close-out
  - [ ] 7.1 Update Dev Agent Record, File List, Change Log; set Status `review`; set `sprint-status.yaml` `1-3-join-gate-never-play-on-defaulted-data: review`

## Dev Notes

### Technical Requirements

- Luau, `--!strict` on every NEW or modified ModuleScript; tab indentation (run stylua, never hand-format); `task.wait/spawn/defer/delay` only (never `wait()/spawn()/delay()`).
- Requires are Roblox instance-based (`require(script.Parent.X)`); deliberately no `.luaurc`.
- **Gate flow (canonical, from architecture Session Load Gate):** `PlayerAdded → DataService.startSession → migrate(Profile.Data) → snapshot push → release (LoadCharacter)` — on ANY failure: `Log.error` + generic kick, never default data. A defaulted profile on one server + a real profile on another = dupes (trading exists).
- Kick message is exact: `"Could not load your data. Please rejoin."` — generic by design; specific failure reasons are an exploit oracle (they go in `Log.error`, not to the player).
- `CharacterAutoLoads = false` is the hold mechanism that makes "released" meaningful: no character (no gameplay) until the gate opens. Set it synchronously in `Init()` before any player can join.
- Snapshot = plain deep copy of migrated v1 `ProfileData`; fired **once** server→client after success, before `LoadCharacter`. Client copy is advisory; `Profile.Data` stays server-authoritative (AGENTS.md Policy).
- Persistence remains 100% ProfileStore-owned: no `DataStoreService`, no `SetAsync`, no hand-rolled save path (NFR2, ADR-001).
- `init.server.luau` gets the architecture's Init/Start passes now — this is the pattern every later service story (1.4 `RemoteService`, Epic 2 services) hooks into.

### Library / Framework Requirements

- ProfileStore `lm-loleris/profilestore@1.0.3`, vendored at `ServerPackages/_Index/lm-loleris_profilestore@1.0.3/profilestore/ProfileStore.luau`. **Read the vendored source, never memory** — already verified by 1.2: `ProfileStore.New(store_name, template)` (~line 1249); `ProfileStore:StartSessionAsync(key, {Steal?, Cancel = fn})` where `Cancel` is honored via `cancel_condition()` (~lines 1400–1410); **`Profile:EndSession()` exists at line ~1090**, `Profile:IsActive()` at ~1082, `Profile:Save()` at ~1172. Re-verify line numbers before use.
- Timeout caveat (1.2 defer): `Cancel` fires only at ProfileStore yield points. Verify from the vendored source that `cancel_condition` is polled during a hung DataStore request; if not provable, add the backstop in Task 3.2 so a hung join cannot hang forever.
- `aftman` tools are on User PATH in fresh shells; if "command not found", prefix `PATH="$HOME/.aftman/bin:$PATH"`. Stop `rojo serve` before `aftman install` (Windows `os error 32`); `rojo build` is unaffected by serve.
- TestEZ pinned at `0.4.1` (registry fallback recorded by 1.2) — do not bump.

### File Structure Requirements

```
src/shared/Log.luau                    # NEW — architecture Logging verbatim
src/shared/Schema.luau                 # MOD — add pure snapshot(data)
src/shared/Config/GameConfig.luau      # MOD — add joinLoadTimeout = 10
src/shared/Hello.luau                  # DELETE — dead scaffold, services now land
src/server/Services/DataService.luau   # MOD — pcall New, timeout, endSession,
                                       #        double-start guard, getSnapshot, Log calls
src/server/init.server.luau            # MOD — Init/Start passes, CharacterAutoLoads,
                                       #        PlayerAdded/Removing gate wiring, Remotes bootstrap
src/client/init.client.luau            # MOD — receive Snapshot into local frozen table
tests/Schema.spec.luau                 # MOD — snapshot builder cases
```

- Do NOT create: `RemoteService`, `StateMirror`, `Validate.luau`, `Signal.luau`, `RarityConfig`, `ItemDefs`, `SetDefs`, any menu/test-view UI, any `src/remotes` Rojo mapping (Remotes folder is runtime-created).
- Do NOT modify `default.project.json` (no new mappings needed — `ReplicatedStorage.Remotes` is created by code at runtime).
- `ReplicatedStorage.Remotes/Snapshot` is created via `Instance.new` in `Init()`; it is NOT a Rojo-mapped folder (empty dirs don't map, and ADR-006's convention is satisfied at runtime).

### Testing Requirements

- TestEZ specs for PURE logic only: `Schema.snapshot()` takes a plain table, returns a plain table — no Players, no DataStore, no game services in the spec.
- Cases: (a) snapshot fields equal source; (b) deep-copy independence — mutating `snapshot.vault` / `snapshot.provenance` leaves the source untouched; (c) source mutation after snapshot does not alter the snapshot.
- Gate/kick/timeout behavior is integration — Studio Play / Team Test only; watch the Output for `[DataService]` structured lines on both success and failure paths.
- Quality gates (must pass before review): `rojo build`, `stylua --check src/ tests/`, `selene src/`. Running TestEZ in Studio is a human step — record results before `done`.
- Remember the 1.2 lesson: run `stylua src/ tests/` BEFORE `git add` (CRLF working copies break the local gate even when git normalizes on commit).

### Scope Guard — What NOT To Build (1.4 / 1.5 own these)

- NO `RemoteService`, NO client→server remote handlers, NO payload validation pipeline, NO rate limiting, NO rejection logging (Story 1.4 — FR12/FR13).
- NO `StateMirror` module, NO delta pushes, NO mirror-driven test view (Story 1.4 renders from the snapshot; this story only delivers the initial copy).
- NO main menu ScreenGui, NO navigation, NO thumb-zone layout (Story 1.5).
- NO trade/set schema fields (Story 4.1 / Epic 3 via forward migration); NO capacity upper bound (Epic 3).
- The `Snapshot` RemoteEvent is server→client push ONLY — do not add any `OnServerEvent` connection (that is RemoteService's job in 1.4, which may also subsume/move this event's registration; keep this story's mechanism minimal).

### Architecture Compliance (boundaries — violations are defects)

1. **Path is permission:** `src/server/` may touch profile data; `src/shared/` must be requirable from both sides and must NEVER require server/client modules.
2. **Only `DataService` reads/writes `Profile.Data`** — `getSnapshot` is the sole read that leaves the module, and it leaves as a copy.
3. **Gate before everything:** no remote serves a player until the gate has opened (1.4's `RemoteService` will enforce this; this story establishes the gate it checks against).
4. **Config tables are read-only** — `joinLoadTimeout` is added to the frozen `GameConfig` at authoring time, never mutated at runtime.
5. **No cross-layer require** except client/shared → shared, server → shared. Client never computes authoritative state (mirror is advisory from the first byte).

### Previous Story Intelligence (1.2 — what this dev must reuse)

- `startSession` contract already holds: returns `true` only on lock + non-table check + pcall'd migrate; **do not rewrite it — extend it**. Failure paths already return `false`; you are adding the caller (gate), the timeout, and the release.
- Vendored ProfileStore facts from 1.2's Debug Log #4 (re-verify before trusting): `New` at ~1249, `StartSessionAsync(key, {Cancel})` with `cancel_condition()` honored ~1400–1410, mock-DataStore path is internal (`ReadMockFlag`) so Studio needs no special-casing — AC4 is satisfied by construction if you don't add `IsStudio` branches.
- CRLF gate failure: files created directly on disk came out CRLF and broke `stylua --check`; run stylua before `git add`.
- `selene tests/` fails by design (TestEZ globals) — the gate is `selene src/` only; do not add globals shims.
- `.gitignore` already covers `ServerPackages/`, `DevPackages/`, `Packages/`, `sourcemap.json`, `*.rbxlx` — do not re-edit it.
- TestEZ execution precedent: `rojo build tests.project.json -o "tests.rbxlx"` (repo-root filename — Rojo 7.7.0 rejects other patterns), Studio command bar `TestEZ.TestBootstrap:run({RS.Tests}, TestEZ.Reporters.TextReporter)`, delete the throwaway `.rbxlx` after.
- 1.1 gotchas: script source in `.rbxlx` is CDATA `<string name="Source">`; `rojo sourcemap` omits empty dirs; regenerate `sourcemap.json` after adding modules then Reload Window in VS Code (AGENTS.md).
- `src/shared/Hello.luau` is dead code (returns an uncalled function) — this story deletes it; do not require or imitate it before then.

### Git Intelligence Summary

- Branch **`feat/story-1-3-join-gate`** already exists and is checked out (created at story-creation time, 2026-10-01). All `src/` + `tests/` work goes there, atomically, with Conventional Commits + bullet body: `feat:` for gate/DataService/client receive, `chore:` for scaffold deletion, `test:` for specs, `docs:` for story/status close-out.
- Recent history to match: `6acf9ac feat: minimal v1 profile schema, migration, and DataService session lock (story 1-2)`, `3cb8752 test: TestEZ specs for Schema migration (story 1-2)`, `af5119f fix: apply story 1-2 code review findings`.
- Do NOT commit `*.rbxlx`, `Packages/`/`ServerPackages/`/`DevPackages/`, `sourcemap.json`.
- Docs-only tracking changes (sprint-status) may ride along on the branch; the default branch receives them at PR merge as in 1.2 (PR #1).

### Latest Tech Information

- ProfileStore v1 (loleris) `StartSessionAsync` returns a session-locked `Profile` or nil; auto-save ~300s; `game:BindToClose` flush is internal — do NOT hand-roll shutdown saves; `Profile:EndSession()` is the release API (vendored ~line 1090) and `Profile:IsActive()` (~1082) guards stale releases.
- Kick works regardless of spawn state — with `CharacterAutoLoads = false` a kicked player never sees a character.
- `player:LoadCharacter()` on a player who left mid-load errors — guard with `player.Parent == Players` before release (the `Cancel` fn already covers the leaving case by aborting the load).
- RemoteEvent payloads are JSON-serializable tables — the v1 `ProfileData` copy qualifies as-is.

### Project Structure Notes

- Alignment: exactly the architecture's tree — gate wiring in `init.server.luau`, logic in `Services/DataService.luau`, shared pure modules (`Log`, `Schema`) requirable from both sides, spec in `tests/`.
- Variances (deliberate, recorded): (1) `ReplicatedStorage.Remotes` is runtime-created, not Rojo-mapped; (2) `GameConfig.joinLoadTimeout` extends the architecture's config table listing (it names gameplay numbers — a join timeout is this story's server robustness number, same "number lives in Config" rule); (3) the initial snapshot push lands in 1.3 (epics AC2) while `StateMirror` + validated pipeline land in 1.4 — 1.4 may subsume this event.

### Project Context Rules

- All DataStore access is server-side only; the client never reads or writes player data — it receives pushed copies and sends RemoteEvent requests that the server validates (AGENTS.md Policy; this story creates zero client→server traffic).
- Never hand-edit `*.rbxlx` (gitignored build output); change `src/` and rebuild.
- `stylua.toml` requires Unix line endings — `.gitattributes` pins `eol=lf`; run stylua, never hand-format.
- Roblox Studio cannot be driven from an agent session: verify the build structurally (CDATA grep), and mark TestEZ execution / Studio open as human confirmation steps.
- Commit atomically on `feat/story-1-3-join-gate`; Conventional Commits with bullet body.

### References

- [Source: skills/planning-artifacts/epics.md#Story 1.3] — canonical ACs (GWT).
- [Source: skills/planning-artifacts/game-architecture.md#Session Load Gate] — gate data flow, kick rules, edge cases (pattern #4, line ~548).
- [Source: skills/planning-artifacts/game-architecture.md#Logging] — `Log.luau` code to implement verbatim.
- [Source: skills/planning-artifacts/game-architecture.md#Error Handling] — REJECTED/FAILED/FAULT levels; generic player messages; no partial writes.
- [Source: skills/planning-artifacts/game-architecture.md#Architectural Decisions #2, #5, #14, #15] — Init/Start lifecycle, RemoteEvents only, pcall boundaries, `--!strict`.
- [Source: skills/planning-artifacts/game-architecture.md#Architectural Decisions #3 / ADR-001] — ProfileStore owns persistence; session lock is the anti-dupe mechanism.
- [Source: skills/planning-artifacts/game-architecture.md#Data Persistence / #Networking] — `Player_<UserId>` keys, no direct DataStoreService, `WaitForChild` timeouts, `SignalBehavior = Deferred`.
- [Source: skills/implementation-artifacts/1-2-session-locked-profile-load.md] — previous story intelligence, review findings, deferred items assigned here.
- [Source: skills/implementation-artifacts/deferred-work.md] — three "revisit in 1.3" items folded into AC5/Task 3.
- [Source: skills/planning-artifacts/implementation-readiness-report-2026-09-28.md] — FR11 coverage → Story 1.3; no UX doc (UX-DR1–4 live in epics.md; no UI work in this story anyway).
- [Source: AGENTS.md] — policy, build/verify commands, Windows/toolchain gotchas, git workflow.

## Dev Agent Record

### Agent Model Used

`opencode/mimo-v2.6-flash-free` (create-story session, 2026-10-01)

### Debug Log References

### Completion Notes List

### File List

### Change Log

| Date | Change |
| --- | --- |
| 2026-10-01 | Story created from epics 1.3 + architecture Session Load Gate/Logging + 1.2 deferred items (AC5); branch `feat/story-1-3-join-gate` created. |
