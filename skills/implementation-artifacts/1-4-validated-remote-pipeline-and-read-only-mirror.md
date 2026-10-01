---
baseline_commit: 457ad68a50685da6cf990fa4d9400da0530ccd21
---

# Story 1.4: Validated Remote Pipeline and Read-Only Mirror

Status: ready-for-dev

## Story

As a player,
I want every action I take sent through one validated server pipeline that pushes my state back to me,
so that the client can never desync from — or tamper with — my real inventory.

## Acceptance Criteria

1. **AC1 — One pipeline validates before any data is touched.** Given a player has passed the join gate, when any client request arrives at `RemoteService`, then three checks run before any handler body can affect state: (a) per-player per-remote rate-limit budget, (b) the player holds an active profile (gate still open), (c) payload shape. Checks (a)–(c) are an unordered *set* of required gates, not a sequence mandate; the execution order is fixed by the architecture (rate limit → gate → `pcall(validate + apply)`) — see Dev Notes. [Source: epics.md#Story 1.4; game-architecture.md#Networking; game-architecture.md#Remote Handler Pipeline]
2. **AC2 — Rate limits reject, never queue (FR13).** Rate limiting is a per-player, per-remote token bucket. When the bucket is empty the request is dropped immediately — never queued, never retried, never delayed — and the handler never runs. Budget numbers live in `Config/GameConfig` (read-only). [Source: epics.md#Story 1.4; FR13; game-architecture.md#Architectural Decisions #7; gdd.md#Technical Requirements]
3. **AC3 — Every rejection is logged with a reason; the client is told nothing.** Rate-limit hits, gate refusals, and payload rejections each emit one structured `Log.warn("RemoteService", "rejected", {player, remote, reason})` entry with a machine-readable reason code. Rejections are *silent to the client* (Decision 7: an exploiter gets no signal); only an unexpected handler fault (`pcall` failure) reaches the player, through a generic `Notify` message. Never log profile payloads or item contents. [Source: epics.md#Story 1.4; game-architecture.md#Error Handling; game-architecture.md#Logging]
4. **AC4 — A request from a player without an active profile is refused.** A `RequestSnapshot` (or any registered remote) fired before the gate opens, or after the session ended, is refused by the gate check — no handler body runs, no snapshot leaves the server, and the refusal is logged per AC3. This is the Session Load Gate rule "no remote handler serves a player until the gate has opened" made executable. [Source: epics.md#Story 1.4; game-architecture.md#Session Load Gate rules]
5. **AC5 — Server pushes state; the client mirror is read-only and is the only thing UI renders.** When server-side state changes the server pushes the snapshot; the client's `StateMirror` deep-freezes it and is the single source every view renders from. No view, controller, or LocalScript may hold its own copy of player data or write into the mirror — firing a remote is the only client input path. [Source: epics.md#Story 1.4; game-architecture.md#Server-fed Read-only Mirror; AGENTS.md#Policy]
6. **AC6 — Snapshot delivery is reliable, closing the 1.3 one-shot defer.** Both paths deliver and are idempotent: (i) the gate pushes `Snapshot` when the session opens (1.3 mechanism, now routed through `RemoteService`), and (ii) the client, *after* connecting `OnClientEvent`, fires `RequestSnapshot` once on bootstrap, which is answered with a fresh push when the gate is open. Whichever ordering occurs (client late, gate push early, request pre-gate and refused) the mirror ends up holding a snapshot. [Source: skills/implementation-artifacts/deferred-work.md; 1.3 Review Findings "reliable delivery → 1.4"]
7. **AC7 — Mirror-driven test view proves the round trip.** A client view renders `Vault: {used} / {capacity}` and `Items: {count}` **exclusively** from `StateMirror`, and updates when a snapshot arrives. For a fresh profile it renders `0 / 8` and `0`. This is a temporary proof view, not a menu — Story 1.5 surfaces it inside the main menu. [Source: epics.md#Story 1.4]
8. **AC8 — Pure pipeline pieces are TestEZ-covered.** TestEZ covers the payload validator (empty payload accepted, any argument rejected) and the token bucket (allows `capacity` consumes, rejects the next without queueing, refills over elapsed time, caps at `capacity`, never refills without elapsed time). [Source: game-architecture.md#Testing Strategy; NFR8]

## Tasks / Subtasks

- [ ] Task 1 — Pure shared validators (AC: 1c, 8)
  - [ ] 1.1 Add `export type ErrorCode = string` to `src/shared/Types.luau` (UPPER_SNAKE by convention) — architecture names `ErrorCode` as a `Types.luau` responsibility
  - [ ] 1.2 Create `src/shared/Validate.luau` (`--!strict`, shared-pure, no game services): `Validate.noArgs(...any): ErrorCode?` returns `"INVALID_PAYLOAD"` when `select("#", ...) > 0`, else `nil`
  - [ ] 1.3 Do NOT pre-build a validator library — only what this story's handlers call (no duplicated `isPositiveInteger`; `Schema` keeps its private copy)
- [ ] Task 2 — Pure token bucket (AC: 2, 8)
  - [ ] 2.1 Create `src/shared/RateLimit.luau` (`--!strict`, shared-pure): `newBucket(now)` → `{tokens, updatedAt}`; `tryConsume(bucket, cfg, now): boolean` refills by `elapsed * cfg.refillPerSecond`, caps at `cfg.capacity`, consumes 1 on success, returns `false` when `tokens < 1`
  - [ ] 2.2 The clock is an **explicit `now` parameter**, never `os.clock()` inside — TestEZ cannot stub `os.clock`, and RemoteService passes `os.clock()` at the call site
  - [ ] 2.3 Reject semantics: `false` means *drop now* — no queue field, no deferred retry, no waiting
- [ ] Task 3 — Rate-limit configuration (AC: 2)
  - [ ] 3.1 Add `remoteRateCapacity = 15` and `remoteRateRefillPerSecond = 5` to `src/shared/Config/GameConfig.luau`, before the existing `table.freeze`
  - [ ] 3.2 Document them as the default bucket for **every** client remote; a per-remote override table is added only when a remote genuinely needs a different budget (data created only when required)
- [ ] Task 4 — `RemoteService` (AC: 1, 2, 3, 4)
  - [ ] 4.1 Create `src/server/Services/RemoteService.luau` (`--!strict`): `init()` creates `ReplicatedStorage.Remotes` + `Snapshot` + `Notify` RemoteEvents (the server→client channels; moved out of `init.server.luau`)
  - [ ] 4.2 `register(name, handler)` lazily creates `Remotes/<name>` if absent, then connects `OnServerEvent` **once**; calling it before `init()` (no folder) or registering an already-registered name is refused with `Log.error` (never a second connection)
  - [ ] 4.3 Handler contract: `handler(player, ...any) -> ErrorCode?` — `nil` = accepted; non-nil = rejected (logged, no client signal). Handlers call `Validate.*` themselves inside the body, per the architecture's verbatim registration example
  - [ ] 4.4 Pipeline per request, in this order: (1) `RateLimit.tryConsume(bucket, RATE_CFG, os.clock())` where `RATE_CFG = { capacity = GameConfig.remoteRateCapacity, refillPerSecond = GameConfig.remoteRateRefillPerSecond }` is built **once at module scope** (not per request) → on `false` log `RATE_LIMITED` and return; (2) `DataService.hasSession(player)` → on `false` log `NO_ACTIVE_PROFILE` and return; (3) `pcall(handler, player, ...)` → on throw `Log.error` `HANDLER_FAULT` + `RemoteService.notify(player, "Something went wrong — nothing was changed.")`; on a returned code `Log.warn` that code
  - [ ] 4.5 Bucket state keyed `userId .. "\0" .. remoteName`; expose `RemoteService.releasePlayer(player)` to drop every bucket for a player — called from the **existing** `PlayerRemoving` connection in `init.server.luau` (one connection, explicit ordering; do not open a second one)
  - [ ] 4.6 `pushSnapshot(player, snapshot)` fires `Snapshot`; `notify(player, message)` fires `Notify`. Both no-op with a `Log.warn` if the event/`player.Parent` is gone
  - [ ] 4.7 No other module ever connects to `OnServerEvent` (boundary rule 3); no `IsStudio()` branch anywhere in the pipeline
- [ ] Task 5 — Server rewiring (AC: 1, 4, 5, 6)
  - [ ] 5.1 `src/server/init.server.luau` `Init()`: keep `Players.CharacterAutoLoads = false`, replace the inline Remotes/`Snapshot` creation with `RemoteService.init()`, then `RemoteService.register("RequestSnapshot", handler)` — handler = `Validate.noArgs(...)` → `DataService.getSnapshot(player)` → `nil` returns `"NO_ACTIVE_PROFILE"` (fail closed, never push defaults) → else `RemoteService.pushSnapshot(player, snapshot)`
  - [ ] 5.2 Gate success path: `RemoteService.pushSnapshot(player, snapshot)` instead of the local `snapshotEvent:FireClient` (order unchanged: push **then** `LoadCharacter`); delete `snapshotEvent`, `REMOTES_FOLDER_NAME`, `SNAPSHOT_EVENT_NAME`
  - [ ] 5.3 Add `DataService.hasSession(player): boolean` (registry lookup only — no snapshot copy, no yields) and use it in the pipeline gate check
  - [ ] 5.4 In the existing `Players.PlayerRemoving` handler, call `RemoteService.releasePlayer(leaving)` before `DataService.endSession(leaving)`
  - [ ] 5.5 Leave untouched: kick message, `gated` dedup set, backstop `task.delay`, respawn watcher, nil-snapshot fail-closed kick, `endSession` behavior
- [ ] Task 6 — Client mirror (AC: 5, 6)
  - [ ] 6.1 Create `src/client/Controllers/StateMirror.luau`: private frozen snapshot; `apply(payload)` type-checks + deep-freezes + stores, then fires subscribers; `get()` returns the frozen snapshot (or `nil`); `onChange(cb)` registers a subscriber (plain callback list — **no** `Signal.luau`, no delta events at this story)
  - [ ] 6.2 Move `deepFreeze` out of `init.client.luau` into `StateMirror` (only `StateMirror.apply` may write the mirror — boundary rule 5)
  - [ ] 6.3 Rewrite `src/client/init.client.luau`: `WaitForChild` Remotes (existing timeouts + `Log.warn` on timeout) → require `StateMirror` + `MirrorTestView` → connect `Snapshot.OnClientEvent` → `StateMirror.apply(payload)` → `MirrorTestView.start()` → **then**, only if the `RequestSnapshot` event resolved, `FireServer()` once. Connect-before-fire is what makes AC6 hold
  - [ ] 6.4 Delete the `initialSnapshot` local holder (replaced by `StateMirror`)
- [ ] Task 7 — Mirror-driven test view (AC: 7)
  - [ ] 7.1 Create `src/client/Controllers/MirrorTestView.luau`: `start()` builds a `ScreenGui` in `LocalPlayer:WaitForChild("PlayerGui")` with two `TextLabel`s, renders immediately from `StateMirror.get()` (placeholder `— / —` pre-snapshot), re-renders on every `StateMirror.onChange`
  - [ ] 7.2 Render `Vault: {used} / {capacity}` and `Items: {count}` where `used` = distinct `itemDefId`s with `count > 0`, `count` = sum of vault counts — both are *display derivations from the mirror only*, never authoritative state, never enforced
- [ ] Task 8 — TestEZ (AC: 8)
  - [ ] 8.1 Create `tests/Validate.spec.luau`: empty payload → `nil`; extra arg / explicit `nil` arg / table arg → `"INVALID_PAYLOAD"`
  - [ ] 8.2 Create `tests/RateLimit.spec.luau`: full bucket accepts exactly `capacity` consumes then rejects; `capacity + 1`-th returns `false` (reject, not queue); advancing `now` refills proportionally; refill caps at `capacity`; identical `now` never refills; fractional refill accrues across calls
  - [ ] 8.3 Run TestEZ in Studio (human step — see Task 10.2) and record counts before `review`
- [ ] Task 9 — Quality gates (AC: all; NFR8)
  - [ ] 9.1 `stylua src/ tests/` then `stylua --check src/ tests/` — run stylua **before** `git add` (CRLF working copies break the local gate; 1.2/1.3 lesson)
  - [ ] 9.2 `selene src/` (never `selene tests/` — TestEZ globals are undefined by design)
  - [ ] 9.3 `rojo build default.project.json -o "secure-data-and-inventory-system.rbxlx"` and `rojo build tests.project.json`
  - [ ] 9.4 Regenerate `rojo sourcemap default.project.json -o sourcemap.json` after adding the five new modules, then **Reload Window** in VS Code (AGENTS.md gotcha)
- [ ] Task 10 — Verification (AC: 7; human steps)
  - [ ] 10.1 Studio Play on the production place: Output shows `[DataService] session opened`, the test view goes `— / —` → `0 / 8` + `Items 0` → character spawns. Rate-limit probe (temporary code added during dev, **removed before close-out**): a local loop firing `RequestSnapshot` ~20× from the client must produce `rejected {... RATE_LIMITED}` lines in Output — evidence for AC2/AC3, then delete the loop
  - [ ] 10.2 Build `tests.rbxlx` from `tests.project.json`, run `TestEZ.TestBootstrap:run({RS.Tests}, TestEZ.Reporters.TextReporter)` in the command bar, delete the throwaway `.rbxlx`, record pass/fail counts in Completion Notes
- [ ] Task 11 — Close-out
  - [ ] 11.1 Update Dev Agent Record, File List, Change Log; set Status `review`; set `sprint-status.yaml` `1-4-validated-remote-pipeline-and-read-only-mirror: review`

## Dev Notes

### Technical Requirements

- Luau, `--!strict` on every NEW or modified ModuleScript; tab indentation (run stylua, never hand-format); `task.wait/spawn/defer/delay` only (never `wait()/spawn()/delay()`).
- Requires are Roblox instance-based (`require(script.Parent.X)`); deliberately no `.luaurc`.
- **Pipeline order (canonical, from architecture Networking + Remote Handler Pipeline):** `rate-limit check → gate check (active profile) → pcall(validate + apply)`. The epics AC lists the three checks as a set of requirements, not a sequence; where the two differ, architecture's data flow is the specific technical spec. Rationale: the token bucket is the cheap bound on per-remote work and must run before any lookup.
- **Handler contract:** `handler(player, ...any) -> ErrorCode?`. `nil` = accepted; a returned code = rejected. Rejections are data, never thrown — an `error()` escaping a handler dies silently on the client (Decision 14).
- **Rejection taxonomy (this story's codes):** `RATE_LIMITED`, `NO_ACTIVE_PROFILE`, `INVALID_PAYLOAD`, plus `HANDLER_FAULT` for the `pcall` failure (logged with `Log.error`, not a rejection). Format: `Log.warn("RemoteService", "rejected", { player = player.UserId, remote = name, reason = <CODE> })`.
- **Silent ≠ unlogged:** Decision 7's "silent drop" means silent *to the client*; AC3 requires the server-side `Log.warn`. Never inform the client *why* — that is an exploit oracle (Error Handling, `REJECTED` level).
- **Reject, not queue:** Roblox queues in the network layer; our "reject" means the handler body never runs and nothing is scheduled in its place. No retry tokens, no deferred work.
- **Gate before everything:** `DataService.hasSession` is a registry lookup (`_profiles[UserId] ~= nil`) — no snapshot copy, no yield. It exists purely so the pipeline can enforce Session Load Gate rule 3.
- **Mirror is the only read path:** only `StateMirror.apply` writes it; every view renders from `StateMirror.get()`. Deriving a display number (`used`, `count`) from mirror data is rendering, not computing authoritative state.
- **Snapshot payload** stays a whole-table deep copy of migrated `ProfileData` (`Schema.snapshot`) — unchanged from 1.3; `StateMirror` deep-freezes whatever it receives so client-side mutation is impossible by construction.
- Persistence is untouched: no `DataStoreService`, no `SetAsync`, no new profile fields (NFR2, ADR-001). No schema change means no migration.
- `Workspace.SignalBehavior`: no handler in this story assumes immediate event firing; nothing to change (architecture Networking note).

### Library / Framework Requirements

- **No new dependency.** `wally.toml`/`wally.lock` are unchanged; ProfileStore `lm-loleris/profilestore@1.0.3` stays vendored under `ServerPackages/`.
- **TestEZ is pinned at `0.4.1`** in `wally.toml` (registry fallback recorded by 1.2) — epics.md's "0.4.2" is a planning-level number; do **not** bump it.
- Toolchain pins: Rojo `7.7.0`, stylua `2.5.2`, selene `0.31.0`, Wally `0.3.2` via `aftman.toml`. `aftman` tools resolve in a fresh shell; if "command not found", prefix `PATH="$HOME/.aftman/bin:$PATH"`. Stop `rojo serve` before `aftman install` (Windows `os error 32`).
- Roblox specifics relied on: `RemoteEvent:FireClient` before the client connects is **lost** (the reason AC6 needs the client-initiated request); `OnServerEvent` fires with `(player, ...)`; a `LocalScript` under `StarterPlayerScripts` runs before the gate can open for that player (so a pre-gate request is the *normal* first outcome, not an error case).

### File Structure Requirements

```
src/shared/Validate.luau                  # NEW — payload validators (noArgs)
src/shared/RateLimit.luau                 # NEW — pure token bucket, explicit `now`
src/shared/Types.luau                     # MOD — add export type ErrorCode
src/shared/Config/GameConfig.luau         # MOD — remoteRateCapacity, remoteRateRefillPerSecond
src/server/Services/RemoteService.luau    # NEW — registry + rate limit + gate + pcall + pushes
src/server/init.server.luau               # MOD — RemoteService.init/register, gate push via RemoteService
src/client/Controllers/StateMirror.luau   # NEW — frozen read-only mirror + onChange
src/client/Controllers/MirrorTestView.luau# NEW — temporary mirror-driven proof view
src/client/init.client.luau               # MOD — StateMirror wiring, connect-then-request, drop local holder
tests/Validate.spec.luau                  # NEW
tests/RateLimit.spec.luau                 # NEW
skills/implementation-artifacts/sprint-status.yaml  # MOD — 1-4 status
```

- Do NOT create: `Signal.luau`, `HUDController`, `VaultController`, `TradeController`, `DiveService`, `VaultService`, `TradeService`, any menu/navigation ScreenGui, `Config/RarityConfig|ItemDefs|SetDefs`, any `src/remotes` Rojo mapping.
- Do NOT modify: `default.project.json` (Remotes stays runtime-created — empty folders do not map), `tests.project.json` (new specs live in `tests/`, modules in `src/shared/` — both already mapped), `wally.toml`, `Schema.luau`, `DataService.startSession/endSession/getSnapshot` (add `hasSession` only).
- Leave `src/client/Controllers/.gitkeep` alone — harmless, and removing it is not this story's business.
- **Test reachability constraint:** `tests.project.json` maps only `src/shared` + `tests` (+ DevPackages). Anything unit-tested must therefore live in `src/shared/`. `RemoteService` (server) is *not* TestEZ-reachable — its ordering and gate behavior are verified structurally + by Studio Play.

### Testing Requirements

- TestEZ specs for PURE logic only: plain tables in/out, no `Players`, no `DataStore`, no game services. `describe`/`it`/`expect` are TestEZ globals — these files are exempt from `selene src/`.
- **Why `RateLimit` takes `now`:** TestEZ cannot stub `os.clock`; passing the clock in makes refill/cap/exhaustion deterministic without `task.wait` in specs.
- Pipeline ordering, gate refusal, and the `Notify` fault path are integration — Studio Play / Output only. Structure-verify everything else (grep the built `.rbxlx`).
- Quality gates (must pass before review): `rojo build`, `stylua --check src/ tests/`, `selene src/`. Running TestEZ in Studio is a human step — record results before `done`.
- Remember the 1.2 lesson: run `stylua src/ tests/` BEFORE `git add` (CRLF working copies break the local gate even when git normalizes on commit).

### Scope Guard — What NOT To Build (1.5 / Epic 2 own these)

- NO main menu, NO navigation, NO thumb-zone layout, NO Dive/Vault/Trade destinations (Story 1.5).
- NO delta events, NO `VaultChanged`-style signals, NO `Signal.luau` — nothing mutates player data at this story, so a delta channel would have no producer (Epic 2 adds both).
- NO gameplay request handlers (`RequestExtract`, `RequestGrab`, trade remotes) — the pipeline is generic; later stories only call `RemoteService.register`.
- NO payload validators beyond `noArgs`; no ownership/range validators until a handler needs them (avoid a speculative validator library).
- NO per-remote rate-limit override table, NO rate-limit UI feedback, NO client-visible rejection state (silent by design).
- NO client-side `Notify` listener/toast — the event exists so the fault path has a destination; a `FireClient` nobody listens to is a harmless no-op, and the toast UI belongs with the shell feedback surfaces (1.5/Epic 2). Do not `WaitForChild` it on the client.
- NO profile/schema changes, NO new `Config` gameplay numbers (pack size, rarity weights arrive with their stories).

### Architecture Compliance (boundaries — violations are defects)

1. **Path is permission:** `src/server/` touches profile data; `src/shared/` is requirable from both sides and never requires server/client modules (`Validate`, `RateLimit` are pure — no game services).
2. **Only `DataService` reads/writes `Profile.Data`** — the pipeline gates on `hasSession`, the handler reads via `getSnapshot`, and only a copy crosses the wire.
3. **Only `RemoteService` connects to `OnServerEvent`** — everyone else calls `RemoteService.register`; `pushSnapshot`/`notify` are the sanctioned server→client fires.
4. **Config tables are read-only** — the rate numbers are added before `table.freeze`, never mutated at runtime.
5. **Client never computes authoritative state** — `StateMirror` is frozen on receipt; views derive display strings from it and fire remotes, nothing else.
6. **No cross-layer require** except client/shared → shared, server → shared (`RemoteService` → `DataService` is server→server, legal).
7. **`src/shared/` must not require server or client** — `Validate`/`RateLimit` require nothing but `Types` if needed.

### Design Decisions Made at Story Creation (do not re-litigate)

- **Where `RequestSnapshot`'s handler lives:** registered by `init.server.luau` next to the gate push (it owns snapshot semantics); `RemoteService` stays a generic pipeline that merely requires `DataService` for the gate check. Boundary rule 3 still holds — registration is the sanctioned path.
- **Event ownership:** `RemoteService.init()` creates `Remotes`, `Snapshot`, `Notify` (server→client channels); `register(name)` lazily creates the client→server event it needs. The Remotes folder is runtime-created by code, never Rojo-mapped (1.3 variance, unchanged).
- **Why a shared `RateLimit` module exists at all:** architecture's shared list doesn't name it, but (a) `tests.project.json` maps only `src/shared`, so a server-local bucket would have zero unit coverage for FR13's core claim, and (b) it is as pure as `Validate`/`Signal`/`Log`. Recorded as a deliberate variance below.
- **`ErrorCode = string` (open alias), not a literal union:** codes are UPPER_SNAKE by convention; a closed union would force every later story to edit `Types.luau` before it can reject with a new code. `--!strict` still catches non-string returns.
- **`used` for the test view = distinct item ids with `count > 0`; `count` = sum of vault counts.** Slot semantics (does 3 of one id occupy 1 slot or 3?) are not defined by any planning artifact — Epic 3 owns the capacity rule. This is a *display-only* derivation in one module; when Epic 3 defines slots, `MirrorTestView` (or its 1.5 replacement) is the only place to change. Flagged as an open question at the end of Dev Notes.
- **AC7's literal `8 / 8`:** read as the *format* (a full vault renders `8 / 8`); a fresh profile renders `0 / 8` + `Items 0`. Both numbers come from the pushed snapshot, which is what "proving the round trip" requires.

### Previous Story Intelligence (1.3 — what this dev must reuse, not rewrite)

- **`startSession` / `endSession` / `getSnapshot` contracts hold — extend, never rewrite.** You are adding `hasSession` only.
- **The gate is complete and reviewed:** `gated` UserId dedup (cleared on `PlayerRemoving`), nil-snapshot fail-closed kick, backstop `task.delay(joinLoadTimeout + 5s)`, `Died → RespawnTime → LoadCharacter` respawn, pcall'd `releaseLive`, seven reason tags (`lock_failed`, `player_left`, `timeout`, `bad_data`, `migrate_failed`, `double_start`, `store_init_failed`). Touch none of it beyond the `pushSnapshot` swap in 5.2.
- **Client bootstrap pattern already exists** in `init.client.luau` (`WaitForChild` + timeout `Log.warn`s) — keep it verbatim; you are only adding the mirror + request.
- **`deepFreeze` already exists client-side** — *move* it into `StateMirror`, do not write a second copy.
- **CRLF gate failure:** files created directly on disk come out CRLF and break `stylua --check`; run stylua before `git add`.
- **`selene tests/` fails by design** — the gate is `selene src/` only; do not add global shims.
- **TestEZ execution precedent:** `rojo build tests.project.json -o "tests.rbxlx"` (repo-root filename — Rojo 7.7.0 rejects other patterns), Studio command bar `TestEZ.TestBootstrap:run({RS.Tests}, TestEZ.Reporters.TextReporter)`, delete the throwaway `.rbxlx` after (already gitignored).
- **Regenerate `sourcemap.json` after adding modules, then Reload Window in VS Code** (AGENTS.md) — this story adds five modules; skipping it produces ~100 bogus require errors.
- `.gitignore` already covers `ServerPackages/`, `DevPackages/`, `Packages/`, `sourcemap.json`, `*.rbxlx`, `tests.rbxlx` — do not re-edit it.
- **1.1 gotcha:** script source in `.rbxlx` is CDATA `<string name="Source">` — grep the built place for structural evidence (`rg -c --fixed-strings`); `python3` is not on PATH in this shell.

### Deferred Work This Story Owns

- [Source: skills/implementation-artifacts/deferred-work.md] **One-shot `Snapshot` FireClient can fire before the client connects and is lost forever** — deferred from 1.3 with an explicit "1.4 owns it". AC6 is that design: connect first, then request; the gate push stays as the primary path. Close the deferred-work.md bullet when AC6 is verified.

### Git Intelligence Summary

- Branch **`feat/story-1-4-validated-remote-pipeline`** already exists and is checked out (created at story-creation time). All `src/` + `tests/` work goes there, atomically, with Conventional Commits + bullet body: `feat:` for pipeline/mirror/view, `test:` for specs, `fix:` for review findings, `docs:` for story/status close-out.
- Recent history to match: `dece11b feat: join gate, session lifecycle, and snapshot push (story 1-3)`, `892b30c test: Schema.snapshot TestEZ cases (story 1-3)`, `422829e fix: apply story 1-3 code review findings`, `75625de docs: story 1-3 review to done (...)`.
- Do NOT commit `*.rbxlx`, `Packages/`/`ServerPackages/`/`DevPackages/`, `sourcemap.json`, `tests.rbxlx`.
- Ship as a PR to `master` (precedent: PR #1 for 1.2, PR #2 for 1.3); docs-only tracking changes may ride on the branch.

### Latest Tech Information

- Roblox `RemoteEvent` semantics as used here: `FireClient(player, ...)` before the client's `OnClientEvent` connection exists is unrecoverable — there is no ack without a client→server path, which is exactly why the client-initiated `RequestSnapshot` exists (AC6).
- No client→server `RemoteFunction` anywhere (ADR-002): it can yield forever if the client disconnects mid-request. All feedback is server→client `Snapshot`/`Notify`.
- Token bucket: `tokens = min(capacity, tokens + (now - updatedAt) * refillPerSecond)`; consume only when `tokens >= 1`. With `capacity 15` / `refill 5/s`, a burst of 15 passes instantly, sustained spam is capped at 5/s, and a normal client (one bootstrap request) never notices.
- Pin reminder: Rojo 7.7.0, ProfileStore 1.0.3, Wally 0.3.2, TestEZ 0.4.1, stylua 2.5.2, selene 0.31.0.

### Project Structure Notes

- Alignment: exactly the architecture's tree — `Services/RemoteService.luau` (named in the System Location Mapping), `Controllers/StateMirror.luau` (named), shared pure modules in `src/shared/`, specs in `tests/`.
- Variances (deliberate, recorded): (1) `ReplicatedStorage.Remotes` is runtime-created, not Rojo-mapped — carried from 1.3, unchanged; (2) `src/shared/RateLimit.luau` is a new shared module not listed in the architecture's `src/shared/` tree — pure and unit-test-reachable, rationale in Design Decisions; (3) `src/client/Controllers/MirrorTestView.luau` is a temporary proof view not in the architecture's controller list — Story 1.5 rehomes it into the main menu (epics AC7 says so); (4) `GameConfig.remoteRate*` extends the architecture's config table listing under the same "gameplay/robustness numbers live in Config" rule.

### Project Context Rules

- All DataStore access is server-side only; the client never reads or writes player data — it receives pushed copies and sends RemoteEvent requests the server validates before touching data (AGENTS.md Policy; this story is the story that makes that sentence executable).
- Never hand-edit `*.rbxlx` (gitignored build output); change `src/` and rebuild.
- `stylua.toml` requires Unix line endings — `.gitattributes` pins `eol=lf`; run stylua, never hand-format.
- Roblox Studio cannot be driven from an agent session: verify the build structurally (CDATA grep), and mark TestEZ execution / Studio Play as human confirmation steps.
- Commit atomically on `feat/story-1-4-validated-remote-pipeline`; Conventional Commits with bullet body.

### Open Questions / Assumptions (saved during analysis)

1. **Vault slot semantics** — does `used` count distinct item ids or total units? No planning artifact defines it; assumed distinct ids for display only (see Design Decisions). Epic 3 owns the real rule.
2. **`Notify` payload shape** — plain message string for now; if Epic 2 needs machine-readable codes client-side, extend `Notify` then rather than speculating here.
3. **Rate-limit budgets per remote** — one default pair now; revisit when a remote (e.g. tap-to-grab) proves it needs its own.

### References

- [Source: skills/planning-artifacts/epics.md#Story 1.4] — canonical ACs (GWT).
- [Source: skills/planning-artifacts/game-architecture.md#Remote Handler Pipeline] — pattern #1: registration example, data flow, "a handler that mutates profile data without passing through this pipeline is a defect".
- [Source: skills/planning-artifacts/game-architecture.md#Server-fed Read-only Mirror] — pattern #3: snapshot → StateMirror → controllers; local mutation is a defect.
- [Source: skills/planning-artifacts/game-architecture.md#Session Load Gate] — rule "no remote handler serves a player until the gate has opened".
- [Source: skills/planning-artifacts/game-architecture.md#Networking] — handler order (token bucket → type → range → ownership), no RemoteFunction, `WaitForChild` timeouts, `SignalBehavior = Deferred`.
- [Source: skills/planning-artifacts/game-architecture.md#Error Handling] / #Logging — REJECTED/FAILED/FAULT levels, `Log.warn` shape, generic messages, no payload logging.
- [Source: skills/planning-artifacts/game-architecture.md#Architectural Decisions #5, #6, #7, #10, #14] — RemoteEvents only, `ReplicatedStorage.Remotes` convention, token bucket + silent drop, read-only mirror, pcall boundaries.
- [Source: skills/planning-artifacts/game-architecture.md#Project Structure] — `RemoteService.luau`, `StateMirror.luau`, `Validate.luau`, `Types.luau`, `GameConfig` locations and naming.
- [Source: skills/planning-artifacts/gdd.md#Technical Requirements] — "Rate-limit every client remote per player; reject rather than queue."
- [Source: skills/implementation-artifacts/1-3-join-gate-never-play-on-defaulted-data.md] — previous story intelligence, review findings, patterns to preserve.
- [Source: skills/implementation-artifacts/deferred-work.md] — the reliable-delivery item assigned to this story.
- [Source: skills/planning-artifacts/implementation-readiness-report-2026-09-28.md] — FR12/FR13 → Story 1.4; "Story 1.4 is wide … keep it lean".
- [Source: AGENTS.md] — policy, build/verify commands, Windows/toolchain gotchas, git workflow.

## Dev Agent Record

### Agent Model Used

`opencode/mimo-v2.6-flash-free` (create-story session, 2026-10-01)

### Debug Log References

### Completion Notes List

### File List

**Created (this story):**

**Modified:**

**Deleted:**

**Generated (gitignored, not tracked):**

### Change Log

| Date | Change |
| --- | --- |
| 2026-10-01 | Story created from epics 1.4 + architecture Remote Handler Pipeline / Read-only Mirror / Networking + 1.3's deferred reliable-delivery item (AC6); branch `feat/story-1-4-validated-remote-pipeline` created. |
