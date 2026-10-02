---
baseline_commit: 29ae88ca76402ddc5a46e27f1b802711c26ad4fd
---

# Story 2.1: Seeded Procedural Room Assembly

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want each dive to assemble a fresh-feeling ruin room from the fixed layout pool,
so that runs differ while the space stays learnable.

## Acceptance Criteria

1. **AC1 — The room is assembled server-side from the template pool, seeded per run.** When a dive starts, the server picks the run's layout from the fixed pool using a **server-generated seed**; the same seed produces the same layout. The client never supplies or influences the seed (server-authoritative assembly — the seed is not player input). [Source: epics.md#Story 2.1 ("a room is assembled from templates seeded per run (same seed ⇒ same layout)"); gdd.md#Primary Mechanics ("procedurally assembled room from a fixed pool of 3–5 layout templates, seeded per run"); game-architecture.md#Networking ("the server never accepts … from the client without verification")]
2. **AC2 — Loot spawn positions derive from the chosen template.** The assembly result carries the loot spawn positions for the run, derived from the selected template's own spawn slots — no loot is rolled or instantiated in this story (Story 2.2 owns rolls; positions only). [Source: epics.md#Story 2.1 ("loot spawn positions derive from the chosen templates")]
3. **AC3 — Assembly is a pure function covered by TestEZ for determinism and pool bounds.** The selection logic lives in `src/shared/` as a pure function (pool + seed in, layout description out — no game services, no I/O) so `tests.project.json` can reach it. TestEZ proves: identical seeds give identical results, every selected template id is a member of the pool, and loot spawn positions fall inside the chosen template's footprint. [Source: epics.md#Story 2.1 ("assembly logic is a pure function covered by TestEZ for determinism and pool bounds"); game-architecture.md#Testing Strategy]
4. **AC4 — Templates differ only in loot density / route length, never mechanics.** The pool is the GDD's fixed set — entry hall, vault chamber, tower stair, flooded gallery (4 names inside the "3–5" pool). No template introduces mechanics, and assembly adds none. [Source: epics.md#Story 2.1; gdd.md#Level Design Framework ("Templates differ in loot density and route length, not in mechanics")]
5. **AC5 — The dive is reachable end-to-end from the menu.** Pressing the menu's Dive button starts a dive: `RequestStartDive` (a normal registered remote — rate-limited, session-gated, payload-validated) → `DiveService` assembles and places a room the player can see in Workspace. A second start request while already in a dive is refused (logged, no second room). Room geometry is **placeholder** (code-built from template metadata) until Story 5.2 swaps in authored dressing. [Source: system end-to-end requirement; 1.5 Design Decision — "when Epic 2 lands, the Dive button's `Activated` handler is where a `RemoteEvent` fire will be added"; game-architecture.md#Remote Handler Pipeline ("mandatory for all client→server traffic")]
6. **AC6 — Pipeline and boundary compliance.** The new remote is registered only through `RemoteService.register` (still exactly one `OnServerEvent` connection); rejections use the existing taxonomy via `Log.warn`; the room is server-side state only — the profile, schema, and mirror are untouched (a room is not player data). [Source: game-architecture.md#Architectural Boundaries 2/3; FR12; 1.4 Scope Guard]
7. **AC7 — Quality gates pass (NFR8).** `stylua --check src/ tests/`, `selene src/`, both Rojo builds green; `sourcemap.json` regenerated. [Source: NFR8; AGENTS.md#Running and verifying]

## Tasks / Subtasks

- [ ] Task 1 — Template pool metadata (AC: 1, 2, 4)
  - [ ] 1.1 Create `src/shared/Config/LayoutConfig.luau` (`--!strict`, frozen): the 4 GDD-named templates as plain data — each entry: `id`, `name`, footprint (`width`/`depth` in studs), and `lootSlots` (local XZ offsets inside the footprint). No behavior, no game services
  - [ ] 1.2 Slots must lie strictly inside the footprint (0 ≤ x < width, 0 ≤ z < depth) — TestEZ will assert this against the real config; slot density may differ per template (that is the loot-density/route-length difference the GDD allows)
- [ ] Task 2 — Pure assembly function (AC: 1, 2, 3)
  - [ ] 2.1 Create `src/shared/RoomAssembly.luau` (`--!strict`, shared-pure): `assemble(seed: number, pool: {...}?) -> Layout?` — defaults pool to `LayoutConfig.templates`; uses `Random.new(seed)` (deterministic, testable, never `os.clock` inside); returns `nil` for an empty pool (fail loud for callers, no silent fallback)
  - [ ] 2.2 Result: chosen template `id` + world-space loot spawn positions (template-local slots + template origin; placeholders are axis-aligned so no rotation math) — pure data, no `Instance.new`
  - [ ] 2.3 No game services, no requires beyond `LayoutConfig` — same purity rule as `RateLimit`/`Validate`
- [ ] Task 3 — TestEZ specs, RED-first (AC: 3)
  - [ ] 3.1 Write `tests/RoomAssembly.spec.luau` BEFORE the implementation: (a) same seed twice ⇒ deep-equal results; (b) every selected id ∈ pool for a sweep of seeds; (c) all loot spawns inside the chosen template's footprint; (d) real `LayoutConfig` pool: 4 members, all slots in-bounds; (e) empty pool ⇒ `nil`
  - [ ] 3.2 Confirm RED (module absent), implement, confirm GREEN
- [ ] Task 4 — `DiveService` (AC: 1, 5, 6)
  - [ ] 4.1 Create `src/server/Services/DiveService.luau` (`--!strict`): `startDive(player): ErrorCode?` — refuses with `"ALREADY_IN_DIVE"` if a run is active; generates the seed server-side (never client input), calls `RoomAssembly.assemble`, logs the chosen template + seed (`Log.info`, Studio diagnostics for verification)
  - [ ] 4.2 Instantiate the placeholder room: anchored, non-collidable-script parts built from the assembly result into Workspace, positioned per-player (deterministic offset so two players in one server never overlap); track the active run (player → room + assembly result)
  - [ ] 4.3 Cleanup: destroy the room and drop the run on `PlayerRemoving`. Extraction-time teardown is Story 2.4's — do not build it here, but a leaving player must not leak a room
- [ ] Task 5 — Remote + server wiring (AC: 5, 6)
  - [ ] 5.1 In `src/server/init.server.luau`: `RemoteService.register("RequestStartDive", handler)` — handler validates an empty payload with `Validate.noArgs` (reuse, no new validator), then returns `DiveService.startDive(player)`'s `ErrorCode?`; rejections flow through the existing pipeline untouched
  - [ ] 5.2 Add `DiveService` cleanup call to the existing `Players.PlayerRemoving` connection (one connection, explicit ordering — 1.4 pattern)
  - [ ] 5.3 Nothing else in the gate/pipeline path changes
- [ ] Task 6 — Menu Dive button goes live (AC: 5)
  - [ ] 6.1 In `src/client/Controllers/MainMenuController.luau`: require-lookup `Remotes/RequestStartDive` (string constant, `WaitForChild` with timeout like `init.client`), and the Dive button's `Activated` handler fires it once per press; on timeout `Log.warn` with a reason code and leave the button as-is
  - [ ] 6.2 Vault / Trade stay placeholders (local note only) — their epics own them
  - [ ] 6.3 Update the controller header: Dive is now a live remote; placeholder note wording unchanged for the other two
- [ ] Task 7 — Quality gates (AC: 7; NFR8)
  - [ ] 7.1 `stylua src/ tests/` then `stylua --check src/ tests/` **before** `git add`; `selene src/` (never `selene tests/`)
  - [ ] 7.2 `rojo build default.project.json -o "secure-data-and-inventory-system.rbxlx"` and `rojo build tests.project.json`
  - [ ] 7.3 Regenerate `rojo sourcemap default.project.json -o sourcemap.json` + **Reload Window** in VS Code
  - [ ] 7.4 Structural probe: built place contains `RequestStartDive` + `DiveService` + `RoomAssembly`; `rg OnServerEvent src/` still shows exactly one `Connect`
- [ ] Task 8 — Verification (AC: 1–5; human steps)
  - [ ] 8.1 TestEZ in Studio (3-line command-bar form — `local RS = …; local TestEZ = require(RS.DevPackages.TestEZ); TestEZ.TestBootstrap:run({RS.Tests}, TestEZ.Reporters.TextReporter)`): **28 existing + new RoomAssembly cases, 0 failed**; record counts
  - [ ] 8.2 Studio Play: join → menu → press Dive → Output logs `[DiveService] dive started {template, seed}` → a placeholder room appears in Workspace; pressing Dive again logs `ALREADY_IN_DIVE`, no second room
  - [ ] 8.3 Second local player (or Studio "Start Server with 2 players" if convenient): rooms do not overlap; leaving destroys the room
- [ ] Task 9 — Close-out
  - [ ] 9.1 Update Dev Agent Record, File List, Change Log; set Status `review`; set `sprint-status.yaml` `2-1-seeded-procedural-room-assembly: review`

## Dev Notes

### Technical Requirements

- Luau `--!strict` on every new/modified file; tab indentation (stylua, never hand-format); `task.wait/spawn/defer/delay` only; instance-based requires; no `.luaurc`.
- **Purity rule for TestEZ reachability:** `tests.project.json` maps only `src/shared` + `tests`. AC3 therefore forces the assembly logic (and its pool metadata) into `src/shared/` — the same reasoning that put `RateLimit` there (1.4 Design Decision, precedent). Server code (`DiveService`) consumes it but is verified structurally + by Play.
- **Determinism source:** `Random.new(seed)` — deterministic across platforms for a given seed; never `math.random()` inside the pure function (it ignores the seed) and never `os.clock()` (TestEZ can't drive it).
- **Server-authoritative seed:** generated inside `DiveService` (e.g. from `math.random()` at call time); a client-supplied seed would let a player choose their layout — rejected by design, not by validation (there is no seed parameter on the remote at all: payload is empty).
- **Pipeline reuse:** `RequestStartDive` goes through the exact 1.4 pipeline (rate limit → `hasSession` → `pcall(handler)`); the handler's only validation is `Validate.noArgs` (empty payload). No pipeline changes, no new validators, no per-remote rate override (default 15/5s is fine for a button press).
- **Room ≠ player data:** the active run lives in a server-side table, never in `Profile.Data`, never pushed to `StateMirror`. Schema untouched ⇒ no migration. Boundary rules 2 and 5 hold trivially.
- **Placeholder geometry:** parts built in code from `LayoutConfig` metadata (anchored, `CanCollide` on for walkability, no scripts). This avoids touching `default.project.json` (no ServerStorage mapping yet) and keeps assembly's single source of truth in the config; Story 5.2 replaces this with authored geometry (that story may add the ServerStorage/ReplicatedStorage mapping — record, don't pre-build).
- **Client remote lookup:** string constants duplicated client-side, per the existing pattern (`init.client.luau` defines its own `REMOTES_FOLDER_NAME` etc.) — `MainMenuController` does the same for `RequestStartDive` with a `WaitForChild` timeout + `Log.warn`.

### Library / Framework Requirements

- **No new dependency.** `wally.toml` unchanged (ProfileStore 1.0.3, TestEZ pinned 0.4.1 — do not bump). No UI framework additions.
- Engine API: `Random.new(seed):NextInteger(lo, hi)` for selection; `Instance.new("Part")` for placeholder geometry.
- Toolchain pins unchanged: Rojo 7.7.0, stylua 2.5.2, selene 0.31.0, Wally 0.3.2.

### File Structure Requirements

```
src/shared/Config/LayoutConfig.luau      # NEW — pool metadata (4 templates, footprints, loot slots)
src/shared/RoomAssembly.luau             # NEW — pure assemble(seed, pool) -> Layout?
src/server/Services/DiveService.luau     # NEW — startDive, seed, room instantiation, run tracking
src/server/init.server.luau              # MOD — register RequestStartDive; PlayerRemoving cleanup
src/client/Controllers/MainMenuController.luau  # MOD — Dive button fires RequestStartDive
tests/RoomAssembly.spec.luau             # NEW — determinism, pool bounds, footprint, empty pool
skills/implementation-artifacts/2-1-seeded-procedural-room-assembly.md  # self
skills/implementation-artifacts/sprint-status.yaml                       # MOD — 2-1 status
```

- Do NOT create: loot roll code (`RarityConfig`), pack/grab/extraction logic, `VaultService`/`TradeService`, `Signal.luau`, `Notify` toast/listener (2.3's "visible pack-full feedback" is the story that needs it —1.5 deferred it there), any menu navigation or menu hiding (5.1), authored room geometry (5.2), new `Validate` functions beyond reuse of `noArgs`.
- Do NOT modify: `src/shared/Schema.luau`, `DataService`, `RemoteService` pipeline internals, `StateMirror`, `GameConfig` (no new gameplay numbers in this story), `default.project.json`, `tests.project.json`, `wally.toml`, Vault/Trade menu behavior.
- `Workspace` note: the room is placed in `Workspace` from the server — legitimate, it replicates; no client writes to Workspace beyond what Roblox does natively.

### Testing Requirements

- **RED-first:** write `RoomAssembly.spec.luau` before implementing `RoomAssembly.luau` (grep-confirm absence = RED), then implement to GREEN — 1.4 precedent.
- Specs are pure: plain tables/numbers/Vector3 in-out, no `Players`, no services. `describe`/`it`/`expect` are TestEZ globals — exempt from `selene src/`.
- Hand-trace each spec case's arithmetic before trusting it (1.4 Debug Log #2 lesson: a spec asserting a rejection while tokens remain is a RED spec that can never fail).
- Integration (seed logged, room appears, double-start refused, cleanup on leave) is Studio Play only — human steps (Task 8).
- Gates before review: `stylua --check src/ tests/`, `selene src/`, both builds.

### Previous Story Intelligence (1.5 — and what still binds from 1.4)

- **`MainMenuController` structure is current and reviewed:** `setText` guards, `makeButton`/`makeLabel` helpers, `Activated` + `Selectable` wiring, mirror-driven `render`. Task 6 touches only the Dive handler + header — do not restructure the menu (Decision 8 from 1.5 still holds: menu stays visible over the room until 5.1).
- **1.5's review patch is the pattern for handler connections:** `button.Activated:Connect(onPlaceholder("Dive"))` connects the returned closure — when you replace it with a remote fire, keep the same "handler factory returns the closure" shape or go inline; never double-invoke (`()`) — that exact bug was the 1.5 review patch.
- **`init.client` bootstrap order is frozen** (connect-then-request); Task 6 does not touch `init.client` at all — the remote lookup lives in the controller.
- **Server wiring precedents from 1.4** (`init.server.luau`): registration sits in `Init()` next to `RemoteService.init()`; `PlayerRemoving` already does `gated` clear → `releasePlayer` → `endSession` — append `DiveService` cleanup there in explicit order (before `endSession` is fine; the room is not profile state).
- **CRLF / stylua before `git add`**, **`selene tests/` never fails by design**, **sourcemap + Reload Window** after adding 3+ modules, **3-line TestEZ command-bar form** (recorded in 1.5 Task 7.4 — the 1.4 one-liner fails on a fresh command bar).
- **selene gotchas:** use `UDim2.fromScale/fromOffset` (layout is in the controller, already correct); new Part-building code should avoid unused temporaries.

### Scope Guard — What NOT To Build (who owns it instead)

- NO loot rolls / rarity table — **Story 2.2** (positions only here; `RarityConfig` doesn't exist yet).
- NO pack capacity, tap-to-grab, slot counting — **Story 2.3**.
- NO extraction, forced extract, run teardown on extract — **Story 2.4** (this story's cleanup is leave-only).
- NO stow, provenance, profile writes — **Story 2.5**.
- NO menu hiding, back navigation, menu→room transition — **Story 5.1** (room appears behind/under the transparent menu; that is expected and recorded).
- NO authored room geometry, dressing, curator — **Story 5.2** (placeholders degrade visibly per that story's AC; ours are the placeholders).
- NO `Notify` toast — arrives with **2.3**'s visible feedback AC (1.5's deferred fork resolved to Epic 2, first story with a real feedback requirement).
- NO client-sent seed, NO layout preview remote, NO dive-state in the mirror/profile.

### Design Decisions Made at Story Creation (do not re-litigate)

1. **One template per run, not stitched multi-room composition.** The GDD's templates (entry hall, vault chamber, tower stair, flooded gallery) are whole-room layouts that "differ in loot density and route length" — selection, not stitching. Stitching would need corridor/connection semantics no planning artifact defines. "Assembled from templates" = selected from the pool. (Listed as an Open Question below for confirmation.)
2. **Pool metadata in shared `Config/LayoutConfig.luau`** — a 5th config module beyond the architecture's table (GameConfig, RarityConfig, ItemDefs, SetDefs). Rationale: AC3's TestEZ reachability forces the data the pure function needs into `src/shared/`, and "content constants live in Config" is the config rule. Architecture's *geometry instances* in ServerStorage remain the 5.2 target — metadata vs. instances distinction is deliberate. Recorded variance (precedent: `RateLimit` in shared).
3. **Placeholder geometry is code-built from metadata** — avoids a `default.project.json` change (no ServerStorage mapping until authored assets exist), keeps one source of truth, and gives Play something visible. 5.2 replaces the builder, not the assembly contract.
4. **`RequestStartDive` with an empty payload** — the seed is server state, so it is simply not on the wire; `Validate.noArgs` covers shape with zero new validators ("data created only when required").
5. **Dive button wiring lands here, not in 5.1.** Epic 2 must be playable end-to-end; 1.5 explicitly anticipated this ("the Dive button's `Activated` handler is where a `RemoteEvent` fire will be added"). 5.1 remains *navigation between* flows (back paths, hiding), which we still do not build.
6. **Double-start is refused, not idempotent** — `ALREADY_IN_DIVE` returned as a normal pipeline rejection (logged, silent to client per Decision 7). A no-op success would hide bugs.
7. **Rooms offset per player** — deterministic grid offset from `UserId` so a 2-player server doesn't stack rooms; real placement/arrival experience is content (5.2) territory.
8. **`RoomAssembly` name** (not part of `DiveService`) — mirrors `Validate`/`RateLimit` being separately testable pure modules; `DiveService` owns lifecycle, `RoomAssembly` owns math.

### Project Structure Notes

- Alignment: `Config/LayoutConfig.luau` + `RoomAssembly.luau` in shared, `Services/DiveService.luau` named in the architecture's System Location Mapping ("Dive & loot → server/Services/DiveService.luau — room generation, rarity rolls, pack, extraction" — we build the room-generation slice), specs in `tests/`.
- Variances (deliberate, recorded): (1) `LayoutConfig` not in the architecture's Config listing (Decision 2); (2) `RoomAssembly.luau` not in the architecture's `src/shared/` tree (same precedent as `RateLimit`); (3) geometry built in code instead of cloned from `ServerStorage` (Decision 3, temporary until 5.2).

### Project Context Rules

- All DataStore access is server-side only; this story adds no data paths (rooms are transient server state — AGENTS.md Policy holds).
- Never hand-edit `*.rbxlx`; change `src/` and rebuild.
- `stylua.toml` Unix line endings via `.gitattributes` — run stylua, never hand-format.
- Studio cannot be driven from an agent session: structural verification (CDATA grep, `rg OnServerEvent`) + human Play/TestEZ steps.
- Commit atomically on `feat/story-2-1-seeded-procedural-room-assembly`; Conventional Commits with bullet body, split `feat` / `test` / `fix` / `docs` (1.4/1.5 precedent).

### Open Questions / Assumptions (saved during analysis)

1. **Selection vs. stitching** — assumed one whole template per run (Decision 1). If "assembled from templates" meant composing several per run (e.g. entry hall + tower stair joined), that is a scope/design change — raise via `gds-correct-course` before dev if intended.
2. **Pool size 4 vs. "3 layout templates" in GDD Asset Requirements** — GDD Level Design names 4 templates; Asset Requirements says "3 layout templates". Assumed the 4 named ones (Level Design is the mechanics source); 5.2 reconciles asset counts when authoring.
3. **Room persistence across menu** — room stays assembled after the player leaves the menu viewport (there is no navigation yet); teardown on extract is 2.4. No action here.

### Git Intelligence Summary

- Branch **`feat/story-2-1-seeded-procedural-room-assembly`** created from `master` @ `29ae88c` (merge of PR #4, story 1.5) — story 1.5 code is fully merged, no stacking needed.
- History to match: `5881368 feat: …`, `5a10492 fix: …`, `f62e432 docs: story 1.5 to done (…)`; PRs #2–#4 merged to `master`.
- Conventional Commits, atomic: `feat:` assembly/service/remote/button, `test:` spec (RED-first commit order welcome), `fix:` review findings, `docs:` close-out. Ship as PR #5.
- Do NOT commit `*.rbxlx`, `tests.rbxlx`, `Packages/`/`ServerPackages/`/`DevPackages/`, `sourcemap.json`.

### Latest Tech Information (verified at story creation)

- `Random.new(seed)` — deterministic generator for a fixed seed; `NextInteger(lo, hi)` inclusive. This is the sanctioned way to get seed-driven determinism in a testable pure function.
- TestEZ command bar (fresh-session form, 1.5 lesson): `local RS = game:GetService("ReplicatedStorage"); local TestEZ = require(RS.DevPackages.TestEZ); TestEZ.TestBootstrap:run({RS.Tests}, TestEZ.Reporters.TextReporter)`.
- Pin reminder: Rojo 7.7.0, ProfileStore 1.0.3, Wally 0.3.2, TestEZ 0.4.1, stylua 2.5.2, selene 0.31.0.

### References

- [Source: skills/planning-artifacts/epics.md#Story 2.1] — canonical ACs (GWT).
- [Source: skills/planning-artifacts/gdd.md#Primary Mechanics] / #Level Design Framework — pool of 3–5 templates, seeded per run, loot density/route length only, the four named templates.
- [Source: skills/planning-artifacts/gdd.md#Core Gameplay Loop] — dive is the loop's entry; the menu button is its front door.
- [Source: skills/planning-artifacts/game-architecture.md#Entity / Creation Patterns] — factory-from-templates (target shape for 5.2; our placeholder honors the contract).
- [Source: skills/planning-artifacts/game-architecture.md#Remote Handler Pipeline] — registration example; mandatory for all client→server traffic.
- [Source: skills/planning-artifacts/game-architecture.md#Configuration] — read-only config modules; gameplay/content numbers live in `Config/`.
- [Source: skills/planning-artifacts/game-architecture.md#System Location Mapping] — `DiveService.luau` owns room generation.
- [Source: skills/planning-artifacts/game-architecture.md#Testing Strategy] — TestEZ for pure logic; Studio/Team Test for the rest.
- [Source: skills/implementation-artifacts/1-5-main-menu-entry.md] — previous story: menu structure, Decision 8 (menu persists), the handler-factory patch pattern, 3-line TestEZ form.
- [Source: skills/implementation-artifacts/1-4-validated-remote-pipeline-and-read-only-mirror.md] — pipeline contract, `PlayerRemoving` ordering, shared-pure precedent (`RateLimit`), RED-first discipline.
- [Source: AGENTS.md] — policy, build/verify commands, Windows/toolchain gotchas, git workflow.

## Dev Agent Record

### Agent Model Used

`opencode/muse-spark` (create-story session, 2026-10-02)

### Debug Log References

### Completion Notes List

### File List
