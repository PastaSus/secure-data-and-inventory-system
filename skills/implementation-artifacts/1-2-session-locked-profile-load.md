---
baseline_commit: 2c2eb6cd31f074b9fcf57f7bad427caa30441180
---

# Story 1.2: Session-Locked Profile Load

Status: review

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

- [x] Task 1 — Pin and vendor dependencies (AC: 1)
  - [x] 1.1 Add `wally.toml` (`[dependencies] ProfileStore = "lm-loleris/profilestore@1.0.3"`, TestEZ as dev-dependency — see Library section for the 0.4.2/0.4.1 caveat)
  - [x] 1.2 Run `wally install`; verify `wally.lock` + vendored package dir on disk
  - [x] 1.3 Wire the SMALLEST Rojo mapping that makes ProfileStore requirable from `src/server` only (never replicate server packages to the client); document the mapping choice in the File List
- [x] Task 2 — Minimal profile schema + pure migration (AC: 3, 4)
  - [x] 2.1 Create `src/shared/Config/GameConfig.luau` with ONLY `startCapacity = 8` (no pack size, trade timeout, rarity — later stories)
  - [x] 2.2 Create `src/shared/Types.luau` with ONLY v1 needs: `ProfileData` (`schemaVersion`, `vault: {[number]: number}`, `provenance: {ProvenanceEntry}`, `capacity: number`) + `ProvenanceEntry`; no trade types
  - [x] 2.3 Create pure migration module `src/shared/Schema.luau` (`CURRENT_SCHEMA_VERSION = 1`, `defaultProfile()`, `migrate(data)` — pure, no DataStore/game services, `--!strict`, tabs); never decreases `schemaVersion`, preserves existing vault entries
- [x] Task 3 — `DataService.startSession` session lock (AC: 2, 5)
  - [x] 3.1 Create `src/server/Services/DataService.luau` (module singleton, `--!strict`): `startSession(player): boolean`, key `Player_<UserId>`, `pcall` around the ProfileStore boundary, `Migrate/Schema.run` after lock acquisition, store profile in module table keyed by `UserId`
  - [x] 3.2 `startSession` returns `(true)` on lock+migrate success, `(false)` on any failure — NO kick, NO snapshot push, NO gameplay release (Story 1.3 owns all three); NO `SetAsync`, NO direct `DataStoreService`
  - [x] 3.3 Do NOT touch `init.server.luau` wiring beyond making the module requirable (no auto-start on PlayerAdded yet — Story 1.3)
- [x] Task 4 — TestEZ coverage + gates (AC: 6)
  - [x] 4.1 Add `tests/project.json` (test-only Rojo map, NOT in the production place) + `tests/Schema.spec.luau`: fresh-profile case (defaults, version 1, capacity 8) and older-schema case (v0/missing version → migrated up, items preserved, version never decreases)
  - [x] 4.2 Run full gates: `rojo build default.project.json -o "secure-data-and-inventory-system.rbxlx"`, `stylua --check src/`, `selene src/` — all green; record TestEZ run method/result in Completion Notes (Studio runner; no CI exists)
- [x] Task 5 — Close-out
  - [x] 5.1 Update Dev Agent Record (model, debug log, completion notes), File List, Change Log; set Status `review`; set `sprint-status.yaml` `1-2-session-locked-profile-load: review`

### Review Findings

_Code review 2026-09-29 · diff `master...HEAD` (branch `feat/story-1-2-session-locked-profile-load`, 5 commits, 13 files, +602/−2) · three-layer pass (Blind Hunter / Edge Case Hunter / Acceptance Auditor) via parallel subagents, findings verified against the vendored ProfileStore source before triage._

- [x] [Review][Decision] **Future-version clamp decreases `schemaVersion`, contradicting AC3 "never decreases it"** — RESOLVED 2026-09-29: Option 1 (bless the clamp as corruption repair). Single-version live game ⇒ a stored version above current cannot be a genuine newer client; failing closed would turn one corrupt metadata field into a denied join for no integrity gain, since the stamp is unrecoverable either way. AC3's "never decreases" is read as "real profiles only move forward"; impossible versions are repaired, not migrated. [Schema.luau:43-45; spec "repairs corrupt fields..."]
- [x] [Review][Patch] **Non-table `profile.Data` is repaired into a value nobody keeps** — applied 2026-09-29: `startSession` returns `false` when `profile.Data` is not a table. [DataService.luau:46]
- [x] [Review][Patch] **`migrate` throws past the "false on ANY failure" contract** — applied 2026-09-29: migrate call wrapped in `pcall`, failure returns `false`. [DataService.luau:46]
- [x] [Review][Patch] **Stringified numeric vault keys are wiped as malformed** — applied 2026-09-29: string keys coerced via `tonumber()` before validation; spec case added. [Schema.luau:60]
- [x] [Review][Patch] **`ipairs` truncates provenance at the first hole and "newest 50" is input-order only** — applied 2026-09-29: `pairs` collection + `acquiredAt` sort + front trim; sparse-array and unsorted-newest spec cases added. [Schema.luau:71-88]
- [x] [Review][Patch] **Non-finite numbers slip through validation into saved data** — applied 2026-09-29: `isPositiveInteger` rejects `inf` (`< math.huge`), version coercion catches `NaN` (`version ~= version`), new `isUsableTimestamp` guards `acquiredAt`; NaN-version, inf-capacity, bad-timestamp spec cases added. [Schema.luau:24,40,73,92]
- [x] [Review][Patch] **File List omits `AGENTS.md` and miscounts spec coverage (7 vs 8 `it` blocks)** — applied 2026-09-29: `AGENTS.md` line added, counts corrected to 14 `it` blocks (8 original + 6 new). [story File List; spec file]
- [x] [Review][Defer] **Session lock is never released; double `startSession` overwrites** — deferred, 1.3 owns it: no `EndSession`/removal exists and `_profiles[id] = profile` stores unconditionally, but the spec's Scope Guard assigns all release/wiring to Story 1.3's join gate and nothing calls `startSession` yet. [DataService.luau:47]
- [x] [Review][Defer] **`Cancel` does not bound a hung DataStore call** — deferred, 1.3 owns it: `Cancel` fires only at ProfileStore yield points, so an outage still hangs `startSession`; timeout/kick policy belongs to 1.3's join gate. [DataService.luau:34-40]
- [x] [Review][Defer] **`ProfileStore.New` at require time is outside the `pcall`** — deferred, revisit in 1.3: a throwing `New` would crash requirers instead of returning `false`, but args are constants and DataStore errors surface inside `StartSessionAsync` (already protected). [DataService.luau:17]
- [x] [Review][Defer] **Capacity has no upper bound** — deferred, Epic 3 owns it: any positive integer persists, but no design max exists anywhere, so any bound invented here would be arbitrary; Epic 3 (set-completion capacity grants) sets the ceiling. [Schema.luau:92-94]
- [x] [Review][Defer] **TestEZ specs never executed** — deferred, human step: specs are written and statically green but require Studio's TestEZ runner; the story cannot move to `done` until a human runs them and pastes results. [tests/Schema.spec.luau]
- [x] [Review][Defer] **No vault/provenance payload bounds (O(n²) front-trim)** — deferred, no path: data comes from DataStore/template (server-written), so no attacker can inject a 100k-entry payload in this story's scope. [Schema.luau:85-87]

_Dismissed as noise (7): shared-template aliasing (verified: ProfileStore hard-copies the template via `DeepCopyTable`); `Types.luau return nil` (idiomatic types-only module); unknown-field passthrough breaking serialization (DataStore-sourced data is JSON-safe by construction); `DataService` unrequirable in the test place (by design — pure-logic specs only); "`ServerPackages` absent on disk" (false — vendored and present); ``any``-typed interop boundaries (deliberate); Rojo/wally "split-brain" (false — `wally.lock` is in the diff)._
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

`opencode/muse-spark-1.3-contributor-free` (close-out session, 2026-09-29). The `src/` + `tests/` + `wally.toml` implementation it closed out was authored on disk by an earlier unrecorded session — no model identifier was left behind, so implementation authorship is recorded as unknown rather than guessed (same constraint as Story 1.1 Patch 5).

### Debug Log References

**1. `stylua --check src/` failed on the inherited implementation — CRLF working copies**

All five new `.luau` files were CRLF on disk (`file` reported CRLF line terminators; the stylua diff showed every line as changed with identical content). Root cause: the files were created directly on disk and never passed through git, so `.gitattributes` (`eol=lf`) never normalized them. Fix: `stylua src/ tests/` rewrote them to LF per `stylua.toml` (`line_endings = "Unix"`), gate green after. Lesson for later stories: run stylua BEFORE `git add` — once staged, git's `eol=lf` keeps the blob LF, but the working-copy CRLF still breaks the local gate until reformatted.

**2. `selene tests/` fails by design — the gate is `selene src/` only**

Running selene over `tests/` reports `describe`/`it`/`expect` as undefined (36 errors). Those are TestEZ globals injected by TestPlanner at run time inside Studio; the spec file's own header documents this exclusion. Not a defect — keep the documented gate (`selene src/`) and do not add globals shims.

**3. `.gitignore` regression: `sourcemap.json` was un-ignored**

The inherited uncommitted `.gitignore` edit (which correctly added `/ServerPackages/` etc.) also deleted the `sourcemap.json` line, so `sourcemap.json` showed as untracked noise. This story's own Git Intelligence says never to commit it. Restored as `sourcemap.json` under a "Rojo sourcemap (regenerated, never committed)" comment.

**4. Vendored ProfileStore API verified against package source, not memory**

`ServerPackages/_Index/lm-loleris_profilestore@1.0.3/profilestore/ProfileStore.luau`: `ProfileStore.New(store_name, template)` (line 1249) and `ProfileStore:StartSessionAsync(profile_key, params)` with `params: {Steal: boolean?}` (line 1004) where `params.Cancel` IS honored via `cancel_condition()` (lines ~1400-1410) — so `DataService`'s `{Cancel = fn}` usage is genuine v1 API, not a ProfileService-ism. Return contract Profile-or-nil matches the `pcall` + nil-check in `startSession`. Mock-DataStore path (`ReadMockFlag`) is internal, so Studio flows through the same gate with no special-casing — as required.

**5. TestEZ 0.4.1 fallback confirmed on disk**

`DevPackages/_Index/` contains `roblox_testez@0.4.1` and `wally.lock` pins `roblox/testez 0.4.1` — the registry-404 fallback the story predicted was taken. Recorded in File List per the story's instruction.

### Completion Notes List

**Technical approach**

- Implementation was inherited on disk (wally files, `src/`, `tests/` all present but uncommitted, story untouched). This session verified it against every AC rather than rewriting: vendored API check (Debug Log #4), scope-guard check (`init.server.luau`, `src/client/*`, `Hello.luau` untouched; no remotes, no trade/set fields), then fixed the two inherited defects (CRLF gate failure, `.gitignore` regression) and renamed one misleading spec title.
- Rojo mapping choice (Task 1.3): `ServerPackages` nested under `ServerScriptService.Server` in `default.project.json` — the only mapping added. `DataService` requires it via `script.Parent.Parent.ServerPackages.ProfileStore` (Services → Server → ServerPackages). Wally's `ServerPackages/ProfileStore.lua` entrypoint re-exports the `_Index` copy, so only that one public path exists. Client never sees server packages; `DevPackages`/TestEZ are not in the production map at all (`tests/project.json` is the separate test-only map).

**Verification evidence**

| Check | Command | Result |
| --- | --- | --- |
| Deps vendored | `wally install` state on disk | `wally.lock` pins ProfileStore 1.0.3 + TestEZ 0.4.1; `ServerPackages/`, `DevPackages/` present |
| Build | `rojo build default.project.json -o "secure-data-and-inventory-system.rbxlx"` | exit 0 |
| Format gate | `stylua --check src/ tests/` | green (after CRLF fix) |
| Lint gate | `selene src/` | `0 errors, 0 warnings, 0 parse errors` |
| TestEZ | specs written, Studio execution | **human step outstanding** (see below) |

**Acceptance criteria mapping**

- **AC1** — `wally.lock` exists, ProfileStore 1.0.3 vendored under `ServerPackages/`, no `wally.toml` open error ✅
- **AC2** — `DataService.startSession` acquires the session lock first, returns boolean, does not kick/snapshot/release ✅
- **AC3** — `schemaVersion` forward-only (garbage→0→lifted to current; impossible future values clamped as corruption repair, never a backward migration); fresh profiles get defaults; existing vault entries preserved ✅
- **AC4** — schema is `schemaVersion` + `vault` + `provenance` + `capacity` (start 8) only; no trade/set fields ✅
- **AC5** — no `SetAsync`, no direct `DataStoreService` anywhere; persistence is ProfileStore-owned ✅
- **AC6** — `tests/Schema.spec.luau` covers fresh/nil, empty, older-schema preservation, idempotency, corruption repair, malformed-vault filtering, provenance cap ✅ (specs written; execution below)

**⚠️ Caveat on the TestEZ-execution half of AC6/Task 4.2**

Same constraint as Story 1.1's Studio-open step: the agent cannot launch Roblox Studio, and TestEZ specs run only under Studio's TestEZ runner (`tests/project.json` maps a test-only DataModel — `selene src/` deliberately excludes it, runners exist only in Studio). Specs are written and statically green; **running them in Studio is a human step still outstanding** — open `tests/project.json` in the Studio TestEZ plugin (or Play-test harness) and paste the pass/fail counts here before marking this story `done`.

**Definition of Done**

- Tasks/subtasks: all complete
- Tests: TestEZ specs written for pure migration (14 `it` blocks); Studio execution outstanding (human step, recorded above)
- Regression suite: full gates re-run after final change — `rojo build`, `stylua --check src/ tests/`, `selene src/` all green
- Lint / static analysis: pass
- File List: complete
- Dev Agent Record: updated
- Only permitted story sections modified: yes — `baseline_commit` frontmatter, checkboxes, Dev Agent Record, File List, Change Log, Status

### File List

**Created (this story):**

- `wally.toml` — package manifest (`realm = "shared"`, `[server-dependencies] ProfileStore = "lm-loleris/profilestore@1.0.3"`, `[dev-dependencies] TestEZ = "roblox/testez@0.4.1"` — 0.4.1 is the registry fallback; arch said 0.4.2 but the Wally registry publishes only 0.4.1)
- `wally.lock` — pins `lm-loleris/profilestore 1.0.3`, `roblox/testez 0.4.1` (generated, committed as the reproducibility contract)
- `src/shared/Config/GameConfig.luau` — ONLY `startCapacity = 8`, `table.freeze`d
- `src/shared/Types.luau` — `ProvenanceEntry` + minimal v1 `ProfileData` only
- `src/shared/Schema.luau` — `CURRENT_SCHEMA_VERSION = 1`, `MAX_PROVENANCE_ENTRIES = 50`, `defaultProfile()`, pure in-place `migrate(data)` (review: `tonumber` key coercion, `pairs`+sort provenance trim, non-finite guards)
- `src/server/Services/DataService.luau` — `profileKey()` + `startSession(player): boolean` only; handlerless by design (1.3 wires it); failure paths return `false` (review: non-table `Data`, migrate throw)
- `tests.project.json` (repo root) — test-only Rojo map (DataModel with Shared + DevPackages + Tests; NOT in production place)
- `tests/Schema.spec.luau` — 14 TestEZ cases (fresh, nil, empty, older-schema, idempotent, corruption repair, malformed vault, provenance cap, string-key coercion, NaN version, inf capacity, sparse provenance, unsorted newest, bad timestamps)

**Modified:**

- `default.project.json` — added `ServerPackages` (`$path: "ServerPackages"`) under `ServerScriptService.Server` ONLY; no client-side package mapping
- `.gitignore` — added `/ServerPackages/`, `/DevPackages/`, `/Packages/`; restored accidentally-dropped `sourcemap.json` (this session)
- `AGENTS.md` — recorded sourcemap-regenerate-plus-reload gotcha (review follow-up)
- `skills/implementation-artifacts/1-2-session-locked-profile-load.md` — `baseline_commit` frontmatter, checkboxes, Dev Agent Record, File List, Change Log, Status
- `skills/implementation-artifacts/sprint-status.yaml` — `1-2-...` status, `last_updated`

**Generated (gitignored, not tracked):**

- `ServerPackages/`, `DevPackages/` — `wally install` output (includes third-party `.lua` files — Wally convention, leave them)
- `secure-data-and-inventory-system.rbxlx`, `sourcemap.json`

**Verified untouched (scope guard):**

- `src/server/init.server.luau`, `src/client/*`, `src/shared/Hello.luau` — no wiring/behavior changes
- No `Log`/`Signal`/`Validate`, no rarity/item/set defs, no `RemoteService`, no remotes folder

### Change Log

| Date | Change |
| --- | --- |
| 2026-09-29 | Close-out session: verified inherited implementation against all 6 ACs (vendored ProfileStore source confirms `New` + `StartSessionAsync(key, {Cancel})` usage). Fixed `stylua --check src/` CRLF failure (`stylua src/ tests/` → LF), restored dropped `sourcemap.json` gitignore, renamed misleading spec title (`never decreases schemaVersion` → `repairs corrupt fields and clamps impossible future versions`). Gates re-run green. Story `ready-for-dev` → `review`. TestEZ Studio execution recorded as outstanding human step. |
| 2026-09-29 | Code review (3 layers, verified against vendored source): 1 decision, 6 patches, 6 defers, 7 dismissed. Decision → Option 1 (future-version clamp is corruption repair; AC3 "never decreases" covers real profiles). Applied all 6 patches: `startSession` failure hardening, string-key coercion, `pairs`+sort provenance trim, non-finite guards, File List/count fixes — each with new spec cases (8 → 14 `it` blocks). Gates + luau-lsp re-run green. |
| 2026-09-29 | Studio-testing follow-up (live bug, found while running specs): the test map as specified (`tests/project.json`) is unusable — Rojo 7.7.0 only accepts `*.project.json` filenames ("no project file found"), and renaming in place causes infinite project-composition recursion (stack overflow: `Tests: $path ../tests` re-loads its own project file forever). Moved to repo-root `tests.project.json` with root-relative paths; builds clean (62KB, spec + TestEZ + Shared verified in artifact). Variance vs architecture's `tests/project.json` path is deliberate and recorded here. |

