---
title: 'Game Architecture'
project: 'secure-data-and-inventory-system'
date: '2026-09-28'
author: 'Administrator'
version: '1.0'
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8, 9]
status: 'complete'
engine: 'Roblox'
platform: 'Roblox (mobile-first, cross-platform)'

# Source Documents
gdd: 'skills/planning-artifacts/gdd.md'
epics: null
brief: 'skills/planning-artifacts/briefs/brief-secure-data-and-inventory-system-2026-09-28/brief.md'
---

# Game Architecture

## Executive Summary

Curio Vault is a Roblox collect-a-thon whose one unusual constraint is correctness: every item must be provably singular and provably owned. This architecture therefore puts a session-locked ProfileStore data layer behind a single validated remote pipeline, with an atomic dual-lock trade commit as the one genuinely novel pattern. Everything else is deliberately boring Roblox — service modules, vanilla ScreenGuis, Rojo + stylua/selene — sized so a solo developer and a team of AI agents can both work in it without guessing.

**Key Architectural Decisions:**

- ProfileStore v1.0.3 session-locked persistence with a mandatory Session Load Gate (never play on defaulted data)
- Single server-authoritative RemoteService pipeline — client sends requests, server validates before touching data
- Atomic 3-phase trade commit as the one novel pattern; server-fed read-only data mirror for all UI

**Project Structure:** Rojo-mapped service folders (`src/server`, `src/client`, `src/shared`) with 8 core systems.

**Implementation Patterns:** 8 patterns defined (4 novel, 4 standard) ensuring AI agent consistency.

**Ready for:** Epic implementation phase

## Document Status

This architecture document was created through the GDS Architecture Workflow.

**Steps Completed:** 9 of 9 — complete

---

## Project Context

### Game Overview

**Curio Vault** (working title) — a cozy collect-a-thon where short dives yield oddities that are stowed in a persistent, dupe-proof vault; sets complete for capacity; a single server-arbitrated trade path supports the social layer.

### Technical Scope

**Platform:** Roblox — mobile-first UI, PC parity, console via Roblox defaults
**Genre:** Collect-a-thon / cozy loot-loop with light trading
**Project Level:** medium-high complexity — small feature surface, unusually strict correctness requirements

### Core Systems

| System | Complexity | GDD Reference |
| --- | --- | --- |
| Profile & persistence (ProfileStore, session locking) | high | Technical Specifications |
| Inventory / vault model (item schema, capacity, provenance) | high | Mechanics — Vault, Technical Specs |
| Remote API surface (validation, rate limiting) | high | Technical Specifications |
| Trading (1:1 arbitrated commit) | high | Mechanics — Trade |
| Dive & loot (procedural room, rarity rolls, pack) | medium | Mechanics — Dive; Level Design |
| Set tracking & completion grants | low | Mechanics — Sets |
| UI shell (mobile-first vault/dive HUD) | medium | Controls; Art Direction |
| Assets & audio integration | low | Art and Audio Direction |

**Platform requirements:** single primary platform (Roblox), no secondary surface; mobile is the primary device, so UI is touch-first while development runs on PC.

**Performance constraints:** 60 FPS Roblox client target; no frame-critical simulation; memory/asset budget unconstrained at MVP scale (40 item meshes).

**Networking requirements:** client-server only. Roblox RemoteEvents/RemoteFunctions with **server-authoritative state** — the client never reads or writes player data (matches `AGENTS.md` Policy). Every remote is per-player rate-limited and argument-validated; the server never accepts an item ID, quantity, price, or ownership claim from the client without verification.

### Complexity Drivers

**High complexity:**
1. **Atomic inventory commits** — stow and trade must commit as all-or-nothing operations that survive a mid-commit disconnect; a partial commit is a dupe or a lost save.
2. **Session-locking semantics** — ProfileStore's lock/`Steal`/`Cancel` behavior is subtle; misuse reintroduces the cross-server dupe it exists to prevent.
3. **Remote API trust boundary** — every remote is an exploit surface (spam, forged args, NaN/negative quantities, non-existent item IDs).

**Novel concepts (no standard pattern in this codebase):**
- Dupe-proof 1:1 trade arbitration with receipts — flagged as the #1 technical risk in the brief; prototype before a second trade path is designed.
- Provenance/integrity surfaced as an in-UI feature (trade receipts, vault source display) — design + data-shape implications.

**Technical risks:**
- DataStore throttling is invisible in Studio; failures appear only under real load.
- 4MB/key cap constrains schema growth — item data must be ID + count, not per-item blobs.
- Solo scope creep against the MVP boundary.
- No loss state means the difficulty curve depends entirely on scarcity tuning (design risk, not engineering).

### Technical Risks (summary)

| Risk | Impact | First mitigation |
| --- | --- | --- |
| Trade-window dupe / race on rejoin | Breaks the pillar that sells the game | Prototype the single trade path first |
| Partial commit on disconnect | Duped or lost items | Atomic transaction + session lock |
| Studio hides throttle behavior | Failures found in production only | Retries/backoff from day one; simulate budget pressure |
| Schema growth past 4MB/key | Save failures | Compact ID+count encoding, enforced at schema layer |

---

## Engine & Framework

### Selected Engine

**Roblox Studio** (latest) with a **Rojo 7.7.0** filesystem workflow.

**Rationale:** the repo is already a Rojo place project targeting Roblox; the platform is fixed by the brief and the audience (Roblox players). This is a validation rather than a trade-off study — no alternative engine reaches the target audience.

**Version verification (2026-09-28):** Rojo **7.7.0** is the current stable release (July 2026, adds `syncback` + websocket/MessagePack sync). Our `aftman.toml` pin `rojo-rbx/rojo@7.7.0` is current — no upgrade needed.

### Project Initialization

Existing Rojo scaffold — no starter template required. Build/serve workflow lives in `AGENTS.md`.

```bash
PATH="$HOME/.aftman/bin:$PATH" rojo build default.project.json -o "secure-data-and-inventory-system.rbxlx"
```

### Engine-Provided Architecture

| Component | Solution | Notes |
| --- | --- | --- |
| Rendering | Roblox engine (Voxel lighting per `default.project.json`) | No custom renderer decisions |
| Physics | Roblox physics | Effectively unused at MVP — no combat/platforming |
| Audio | Roblox `SoundService` (`RespectFilteringEnabled` on) | Stow/set-complete SFX are the polish priority |
| Input | Roblox GUI input + `ContextActionService` | Touch-first; PC/gamepad follow Roblox defaults |
| Networking | Roblox client-server replication, `FilteringEnabled` | RemoteEvent/RemoteFunction is our only transport |
| Persistence | `DataStoreService` (thin) wrapped by **ProfileStore** | Session locking is the point — do not touch DataStoreService directly |
| Scene/place mgmt | Rojo two-way sync (`syncback` in 7.7.0) | `*.rbxlx` is build output, never hand-edited |
| Build & quality | Rojo + aftman; stylua + selene | Checks configured in `stylua.toml` / `selene.toml` |
| UI | `ScreenGui`/`CoreGui` from `StarterPlayerScripts` | Mobile-first kit |

### Remaining Architectural Decisions

These are *not* provided by the engine — decided in steps 4–7:

1. Server-only data layer shape: profile schema, module boundaries, storage format
2. Remote API contract: names, payload shapes, validation rules, rate limits, error semantics
3. Commit semantics: atomic stow/trade, disconnect mid-commit behavior
4. Trade protocol: state machine, receipt format, idempotency
5. Item ID registry and schema evolution rules (4MB/key discipline)
6. Client state model: replicated view vs. client-held cache
7. `src/` directory layout and module ownership
8. Error handling and logging conventions

### Development Environment (MCPs)

- **Roblox Studio MCP (official, first-party)** — *optional, recommended.* 21 tools: DataModel exploration, script read/grep/multi-edit, **`execute_luau`** live execution, playtest control, screen capture, AI asset generation. Requires Roblox Studio running with the plugin; note the catalog lists supported clients as Claude Code/Desktop, so verify opencode compatibility before relying on it.
- **Context7** (`upstash/context7`) — *optional.* Version-specific Roblox/Luau docs into prompts instead of model training data.

Neither is required for the architecture to hold; both can be added post-setup without architectural impact.

---

## Architectural Decisions

### Decision Summary

| # | Category | Decision | Version | Rationale |
| --- | --- | --- | --- | --- |
| 1 | State management | Server service modules + client controllers; no ECS/Redux | — | ~6 systems, solo dev — ECS/Redux overhead buys nothing at this size |
| 2 | Server structure | Service ModuleScripts, Init/Start lifecycle, single entry point | — | Roblox-idiomatic; gives every AI agent one obvious place to hook in |
| 3 | Save system | **ProfileStore** session-locked profiles, one key per player | `lm-loleris/profilestore@1.0.3` (verified 2026-09-28) | Session locking is the anti-dupe mechanism; auto-save 300s, exponential backoff built in |
| 4 | Package management | **Wally** `0.3.2` for the ProfileStore dependency | `0.3.2` (verified 2026-09-28) | Pinned, lockfile'd dependency = reproducible for every future agent session |
| 5 | Networking | Reliable **RemoteEvent** only; **no client→server RemoteFunction** | engine | RemoteFunction can yield forever if a client disconnects mid-request |
| 6 | Remote contract | `ReplicatedStorage.Remotes/` named events; primitive payloads; server validates type+range+ownership | — | One folder, one convention — removes the largest exploit surface |
| 7 | Rate limiting | Per-player token bucket per remote, silent drop on violation | — | Silent drop avoids giving exploiters a signal; engine ceiling is not a substitute |
| 8 | Item schema | Compact `{[itemDefId]: count}` + bounded provenance log (last 50) | — | Fits 4MB/key with room to grow; provenance powers the "integrity visible" pillar |
| 9 | Trade protocol | Offer → Confirm → Commit state machine, both locks held, atomic | — | #1 risk; all-or-nothing commit with idempotent `tradeId` |
| 10 | Client state | Server-pushed snapshot + delta events; client mirror is read-only | — | Client never computes authoritative inventory (AGENTS.md Policy) |
| 11 | UI framework | Vanilla Roblox `ScreenGui` | — | Fusion/Roact unjustified at MVP; revisit only if UI state sync gets painful |
| 12 | Assets | Creator Store base assets + custom meshes; server-only content in `ServerStorage` | — | Keeps client payload small; no StreamingEnabled (map is tiny) |
| 13 | Directory layout | `src/server/Services/`, `src/client/Controllers/`, `src/shared/` | — | Matches Rojo map in `AGENTS.md`; mirrors decision 2 |
| 14 | Error handling | pcall at every remote handler + DataStore boundary; `Log` wrapper; `warn` never `error` across remotes | — | An `error()` escaping a remote handler kills the request silently on the client |
| 15 | Type checking | `--!strict` on all new ModuleScripts | Luau | Catches schema/type drift at edit time; default `nonstrict` misses most mismatches |
| 16 | Testing | TestEZ `0.4.2` for pure server logic (rolls, trade validation, schema); Studio/Team Test for the rest | `Roblox/testez@0.4.2` (verified 2026-09-28) | Pure-function coverage where exploits actually get caught; no CI yet |
| 17 | Deployment | Rojo build → Roblox publish (no export step) | Rojo 7.7.0 | Publishing *is* deployment on Roblox |

### State Management

**Approach:** plain module singletons with explicit lifecycle — no ECS, no Redux-style store.

- **Server:** service modules in `ServerScriptService` (`DataService`, `DiveService`, `VaultService`, `TradeService`, `RemoteService`) initialized by `src/server/init.server.luau`: synchronous `Init()` pass, then `task.spawn`'d `Start()` pass.
- **Client:** controllers in `src/client/` own UI state only; they render a **read-only mirror** of server state.

*Trade-off accepted:* singletons are harder to mock than DI. Mitigated by keeping pure logic (roll table, validation, schema) in dependency-free shared modules that TestEZ can exercise directly.

### Data Persistence

**Save system:** ProfileStore v1.0.3 — session-locked profiles, in-memory `Profile.Data` during the session, auto-save every 300s, backoff on failure.

- One DataStore key per player: `Player_<UserId>`.
- **Never call `DataStoreService` directly** — ProfileStore owns all reads/writes (`AGENTS.md` Policy made concrete).
- ProfileStore is explicitly *not* for leaderboards/global state — no global reads anywhere in this design.
- `game:BindToClose` / session end flush handled by ProfileStore; no hand-rolled save path.

**Profile shape (v1):**

```lua
type ProfileData = {
    schemaVersion: number,          -- migration gate
    vault: {[number]: number},      -- itemDefId -> count
    setsCompleted: {number},         -- set ids
    capacity: number,               -- vault slots
    provenance: {ProvenanceEntry},  -- ring buffer, capped at 50
    tradeReceipts: {TradeReceipt},  -- ring buffer, capped at 50
}
```

### Networking

**Pattern:** `Client input → RemoteEvent → server validates → apply → replicate`. Authoritative state only travels on **reliable** RemoteEvents.

- **No client→server RemoteFunction** (disconnect-during-yield hazard). Client feedback (success/failure toasts) comes back on a server→client `Notify` RemoteEvent.
- `UnreliableRemoteEvent` reserved for future visual-only FX — **not used at MVP**.
- Every handler: per-player token-bucket rate limit (silent drop) → type check → range check → ownership check → apply.
- `WaitForChild` with timeouts on every client require from `ReplicatedStorage`.
- Verify `Workspace.SignalBehavior = Deferred` on the place; audit any handler that assumes immediate event firing.

### Trade Protocol (ADR — highest risk)

**Decision:** three-phase state machine, executed entirely server-side.

1. **Offer** — player A submits `tradeId, {offeredItems}, {requestedItems}`; server validates A owns and can spare every offered item.
2. **Confirm** — player B sees the offer; both must confirm within **30s** or the offer expires.
3. **Commit** — server acquires both players' session locks, re-validates ownership + capacity against *current* state (not the offer snapshot), then moves both sides in one atomic step. Any check fails → abort, **zero** mutations.

- Idempotency: `tradeId` (server-generated GUID); a replayed commit is a no-op.
- Disconnect during confirm → offer expires. Disconnect during commit → ProfileStore session lock guarantees the next server sees exactly one side of the trade, never both or neither.
- Receipts appended to both players' `tradeReceipts` — this is the "integrity as visible feature" pillar made real.

**Consequence:** exactly one trade path ships at MVP. Any second path (currency legs, auction) requires a new ADR.

### Item Schema (ADR)

**Decision:** compact count-map plus bounded provenance, not per-item instances.

- `vault: {[itemDefId]: count}` — O(items) storage, trivially under the 4MB/key cap.
- Item definitions (`ItemDefs`) are a **shared, read-only module** keyed by small integer IDs; the client reads definitions but never owns counts.
- Provenance is a capped ring buffer (50 entries: item id, rarity, run id, timestamp) rather than per-item history — enough to display "found in run #12" for recents without unbounded growth.
- **Schema evolution:** every profile carries `schemaVersion`; a single migration function runs on load, ordered old→new, pure and unit-tested. Never rename a field without a migration.

### Asset Management

**Loading strategy:** no streaming, no lazy loading — the map and 40 items are small enough to load with the place. Server-only content (loot spawn templates, layout data) lives in `ServerStorage`; anything the client renders lives in `ReplicatedStorage`.

### UI Architecture

Vanilla Roblox `ScreenGui` hierarchy from `StarterGui`/`StarterPlayerScripts`, mobile-first sizing, `ResetOnSpawn = false` on persistent HUD. UI input fires a RemoteEvent; **no gameplay state ever changes client-side.**

### Error Handling & Logging

- `pcall` at every remote handler entry and every DataStore-adjacent boundary.
- `src/shared/Log.luau` wrapper: `Log.warn(context, message, data)` → prefixed `warn()`. No logging framework, no external service at MVP.
- Failures degrade gracefully: a failed stow keeps items in the pack and notifies the player — never a silent partial write.

### Testing Strategy

- **TestEZ** (Roblox org) unit specs for pure logic: rarity rolls, trade validation, capacity rules, schema migrations.
- Studio **Play** + **Team Test** for integration; client/server context toggle to inspect both sides.
- Optional: Roblox Studio MCP `execute_luau` for live assertions if the client supports it.

### Architecture Decision Records

| ADR | Decision | Context | Consequences |
| --- | --- | --- | --- |
| ADR-001 | ProfileStore owns all persistence | Duping via cross-server races is the core threat | Gains session locking; loses direct DataStoreService control; no leaderboards |
| ADR-002 | RemoteEvents only, no client→server RemoteFunction | Disconnect-during-yield can strand requests | Client must handle async acks via `Notify` |
| ADR-003 | Atomic 3-phase trade commit | Trade dupes would break the selling pillar | Serializes trade commits; caps MVP at one trade path |
| ADR-004 | Count-map + bounded provenance | 4MB/key discipline + "integrity visible" pillar | No full per-item history; oldest provenance rotates out |
| ADR-005 | No currency at MVP | Removes an entire exploit + balancing surface | Progression limited to capacity grants; economy deferred |

---

## Cross-cutting Concerns

These patterns apply to ALL systems and must be followed by every implementation.

### Error Handling

**Strategy:** *boundary containment + result values* — two layers, no exceptions escaping.

1. **Expected failures return results.** Validation never throws; it returns `(ok: boolean, err: ErrorCode?)`. Callers and the client handle failure as data.
2. **Unexpected failures are contained** with `pcall` at remote-handler entries and every ProfileStore/DataStore-adjacent call. An error inside a remote handler must never propagate — it dies silently on the client.

**Error levels:**

| Level | Meaning | Handling |
| --- | --- | --- |
| `REJECTED` | Client sent something invalid/exploitative | Silent drop + `Log.warn` with userId + remote name; never inform the client of *why* |
| `FAILED` | Server-side operation could not complete (throttle, lock contention) | Retry where safe, otherwise notify player via `Notify` |
| `FAULT` | Bug / invariant broken | `Log.error` with full context; degrade gracefully (keep items, notify player) |

```luau
-- RemoteService.luau — the only shape a remote handler may take
function RemoteService.handle(remoteName: string, player: Player, ...: any)
	local ok, err = pcall(validateAndApply, remoteName, player, ...)
	if not ok then
		Log.error(remoteName, "handler fault", { player = player.UserId, err = err })
		Notify.send(player, "Something went wrong — nothing was changed.")
		return
	end
end
```

**Rules:** errors never pause the game; players only ever see a generic failure message (specifics are an exploit oracle); partial writes are forbidden — on failure, state stays exactly as it was.

### Logging

**Format:** plain text, engine Output — `[ServiceName] message {context-table}`
**Destination:** Roblox Output (`warn` for WARN/ERROR, `print` for INFO). No external service at MVP.

```luau
-- src/shared/Log.luau
local Log = {}
local RunService = game:GetService("RunService")

function Log.info(context: string, message: string, data: {})
	if RunService:IsStudio() then print(("[%s] %s"):format(context, message), data) end
end

function Log.warn(context: string, message: string, data: {})
	warn(("[%s] %s"):format(context, message), data)
end

function Log.error(context: string, message: string, data: {})
	warn(("[%s] ERROR %s"):format(context, message), data)
end

return Log
```

- **Always logged:** handler faults, rejected-remote warnings (rate-limit hits and validation failures — this is our exploit telemetry), save failures, session-lock conflicts.
- **Never logged:** full profile payloads, item contents of other players.
- **DEBUG/TRACE:** Studio-only, behind `RunService:IsStudio()`; never compiled into production paths.

### Configuration

**Approach:** typed constant modules in `src/shared/Config/` — plain Luau tables, no files, no remote config at MVP.

| Module | Holds |
| --- | --- |
| `Config/GameConfig` | pack size, vault start capacity, capacity per set, trade timeout |
| `Config/RarityConfig` | rarity tiers + roll weights (single source for the roll table) |
| `Config/ItemDefs` | itemDefId → name, rarity, set membership (read-only, shared) |
| `Config/SetDefs` | set id → required item ids, reward |

**Rules:** config modules are **read-only** — never mutate a config table at runtime; gameplay numbers live only in `Config/` (an agent changing balance must never touch logic files); every balance number is server-authoritative, client reads the same shared module but its copy is advisory.

### Event System

**Pattern:** typed observer signals for server-internal decoupling; RemoteEvents are a **separate, explicit** channel — never simulated with signals.

```luau
-- src/shared/Signal.luau (vanilla typed signal, no Instance overhead)
type Connection = { Disconnect: (Connection) -> () }
type Signal<T...> = {
	Connect: (Signal<T...>, (T...) -> ()) -> Connection,
	Fire: (Signal<T...>, T...) -> (),
}

local GameEvents = {
	VaultChanged = createSignal(),   -- (player, changedItemIds)
	SetCompleted = createSignal(),   -- (player, setId)
	TradeCommitted = createSignal(), -- (tradeId, a, b)
}
```

- **Naming:** `PastTense` for events that happened (`VaultChanged`, `TradeCommitted`), never commands.
- Processing is synchronous at fire time via `task.spawn` per listener; no replay/history.
- Every long-lived system tracks its `RBXScriptConnection`s in a table and disconnects them on teardown.

### Debug Tools

- **Available at MVP:** TestEZ suite for pure logic; Studio-only `Log.info` diagnostics; Studio client/server context toggle for state inspection.
- **Activation:** everything debug-gated behind `RunService:IsStudio()` — no debug keys, no cheat commands, nothing reachable in a published build.
- **Deliberately not built:** in-game debug console, visual overlays, state inspectors. Add only when a concrete debugging need appears.

---

## Project Structure

### Organization Pattern

**Pattern:** *layer-first, domain within* — forced top-level split by Rojo (server / shared / client), services grouped by game domain underneath.

**Rationale:** the server/shared/client split **is** the security boundary in `AGENTS.md`; making it the top level means an agent can see from the path alone whether code is allowed to touch data. Within `server/`, one file per service keeps ownership unambiguous.

### Directory Structure

```
secure-data-and-inventory-system/
├── default.project.json        # Rojo map — source of truth for instance paths
├── aftman.toml                 # rojo 7.7.0, stylua, selene
├── wally.toml / wally.lock     # ProfileStore dependency (pinned)
├── stylua.toml / selene.toml
├── AGENTS.md                   # agent policy block
├── src/
│   ├── shared/                 → ReplicatedStorage.Shared
│   │   ├── Config/
│   │   │   ├── GameConfig.luau     # pack size, capacity, trade timeout
│   │   │   ├── RarityConfig.luau   # tiers + roll weights (single source)
│   │   │   ├── ItemDefs.luau       # itemDefId → name, rarity, set
│   │   │   └── SetDefs.luau        # setId → required ids, reward
│   │   ├── Types.luau              # ProfileData, ErrorCode, TradeReceipt, ProvenanceEntry
│   │   ├── Validate.luau           # pure validators (type/range/ownership checks)
│   │   ├── Signal.luau             # typed observer signal
│   │   ├── Log.luau                # logging wrapper
│   │   └── Hello.luau              # existing scaffold (delete when services land)
│   ├── server/                 → ServerScriptService.Server
│   │   ├── init.server.luau        # entry: Init() pass, then Start() pass
│   │   └── Services/
│   │       ├── DataService.luau    # ONLY module allowed to touch Profile.Data
│   │       ├── RemoteService.luau  # registers handlers + rate limit + pcall boundary
│   │       ├── VaultService.luau   # stow, capacity, sets, provenance
│   │       ├── DiveService.luau    # room gen, loot rolls, pack, extract
│   │       └── TradeService.luau   # 3-phase trade state machine
│   │   (Packages/ from Wally holds ProfileStore — vendored by `wally install`)
│   └── client/                 → StarterPlayer.StarterPlayerScripts.Client
│       ├── init.client.luau        # entry: starts controllers in order
│       └── Controllers/
│           ├── StateMirror.luau    # read-only mirror of server snapshots/deltas
│           ├── HUDController.luau  # pack + dive HUD
│           ├── VaultController.luau# vault grid, set progress, provenance display
│           └── TradeController.luau# offer/confirm UI (fires remotes only)
├── tests/                      # TestEZ specs (NOT in the production place)
│   ├── project.json            # test-only Rojo map for the runner
│   ├── Validate.spec.luau
│   ├── TradeService.spec.luau
│   └── Schema.spec.luau
├── skills/planning-artifacts/  # brief, GDD, game-architecture.md, epics, specs
├── docs/                       # project knowledge
└── secure-data-and-inventory-system.rbxlx   # build output (gitignored)
```

### System Location Mapping

| System | Location | Responsibility |
| --- | --- | --- |
| Profile persistence | `server/Services/DataService.luau` | ProfileStore session, load/save, migrations |
| Remote API | `server/Services/RemoteService.luau` | Handler registry, rate limits, pcall boundary |
| Vault & sets | `server/Services/VaultService.luau` | Stow commits, capacity, set completion, provenance |
| Dive & loot | `server/Services/DiveService.luau` | Room generation, rarity rolls, pack, extraction |
| Trading | `server/Services/TradeService.luau` | Offer/confirm/commit state machine, receipts |
| Validation logic | `shared/Validate.luau` | Pure, reusable, unit-tested |
| Config & definitions | `shared/Config/*` | Read-only constants |
| Client state | `client/Controllers/StateMirror.luau` | Server-fed read-only mirror |
| UI | `client/Controllers/*` | Rendering + remote firing only |
| Unit tests | `tests/*.spec.luau` | Pure-logic specs |

### Naming Conventions

#### Files
Modules: **PascalCase** matching their primary export (`VaultService.luau` → `local VaultService = {}`). Entry points are `init.server.luau` / `init.client.luau` (Rojo convention — they become `Script` / `LocalScript`). Specs: `<Module>.spec.luau`.

#### Code Elements

| Element | Convention | Example |
| --- | --- | --- |
| Module tables / types | PascalCase | `VaultService`, `ProfileData` |
| Functions & locals | camelCase | `commitStow`, `currentCapacity` |
| Constants | UPPER_SNAKE | `MAX_PACK_SIZE`, `TRADE_TIMEOUT` |
| Remote event names | PascalCase noun/verb phrase | `RequestExtract`, `Notify`, `RequestTradeOffer` |
| Error codes | UPPER_SNAKE strings | `"REJECTED_OWNERSHIP"` |
| Config keys | camelCase | `startCapacity` |

#### Game Assets
Assets: **snake_case** — `item_amethyst`, `room_vault_chamber`, `sfx_stow`, `mus_vault_ambient`. Item/set IDs are small integers defined in `Config`, never encoded in asset filenames beyond the item key.

### Architectural Boundaries

1. **Path is permission.** Code in `src/server/` may touch `Profile.Data` and DataStores; `src/client/` may not, ever. `src/shared/` must be importable from both sides and must never `require` anything from server or client.
2. **Only `DataService` reads or writes `Profile.Data`.** Other services go through it. A service holding its own copy of profile data is a dupe waiting to happen.
3. **Only `RemoteService` registers remote handlers.** No other module connects to `OnServerEvent`.
4. **Config tables are read-only** — runtime mutation of `shared/Config/*` is a bug.
5. **Client never computes authoritative state.** It renders `StateMirror` and fires remotes.
6. **No cross-layer `require`** except: client/shared → shared, server → shared. Server → client is impossible; shared → server is a layering violation.

---

## Implementation Patterns

These patterns ensure consistent implementation across all AI agents.

### Novel Patterns

#### 1. Remote Handler Pipeline

**Purpose:** every client→server request flows through one identical sequence, so no agent can accidentally ship an unvalidated remote.

**Components:** `RemoteService` (registry + rate limiter + pcall boundary) → `Validate` (pure) → service handler → `Notify` (result to client).

**Data flow:** `client fires remote → rate-limit check → pcall(validate + apply) → success: replicate delta / failure: Log.warn + generic Notify`.

```luau
-- RemoteService.luau — declarative registration; no other module touches OnServerEvent
RemoteService.register("RequestExtract", function(player: Player, packSnapshot: {number})
	local err = Validate.packSnapshot(packSnapshot)   -- pure, unit-tested
	if err then return Log.warn("DiveService", "rejected", { player = player.UserId, err = err }) end
	return DiveService.extract(player, packSnapshot)
end)
```

**Usage:** mandatory for *all* client→server traffic. A handler that mutates profile data without passing through this pipeline is a defect.

#### 2. Atomic Dual-Lock Commit

**Purpose:** move items between two players without ever creating, destroying, or half-moving anything.

**Components:** `TradeService` state machine (`OFFERED → CONFIRMED → COMMITTED | EXPIRED`), both players' ProfileStore sessions, one `tradeId`.

**Data flow:** offer validated against A's *current* state → B confirms → server re-validates both sides against *current* state under both session locks → mutate both `Profile.Data` tables in one synchronous block → append receipts → release locks.

```luau
-- Commit phase (server, single synchronous block — no yields between re-validate and mutate)
local okA = Validate.canPartWith(a.data, offer.items)
local okB = Validate.canPartWith(b.data, offer.requests) and Validate.hasCapacity(b.data, offer.items)
if not (okA and okB) then return abort(tradeId) end   -- zero mutations

applyMove(a.data, offer.items, -1)
applyMove(b.data, offer.items,  1)
applyMove(b.data, offer.requests, -1)
applyMove(a.data, offer.requests,  1)
appendReceipt(a.data, tradeId); appendReceipt(b.data, tradeId)
```

**Usage:** the only sanctioned way to move items between players. Yields are forbidden inside the commit block; a new trade path (currency leg, auction) requires a new ADR before code.

#### 3. Server-fed Read-only Mirror

**Purpose:** client UI renders authoritative state without ever computing it.

**Components:** server snapshot on join + `VaultChanged`-style delta events → `StateMirror` (client) → controllers read `StateMirror` and render.

**Data flow:** `server mutates → RemoteService broadcasts delta → StateMirror applies → controllers re-render`. Client input only ever fires a remote; it never edits `StateMirror` directly.

```luau
-- Controllers read; only StateMirror.write may touch it
StateMirror.onDelta(function(delta)
	if delta.kind == "vault" then VaultController.render(StateMirror.vault) end
end)
```

**Usage:** mandatory for any UI showing player data. Controllers that mutate mirrored state locally are a defect (instant desync + exploit-shaped code).

#### 4. Session Load Gate

**Purpose:** guarantee a player only ever plays while *this server* holds their session lock — playing on unlocked or defaulted data is how items get duplicated across servers.

**Components:** `DataService` (session start + migration) + a join gate that blocks gameplay until load resolves.

**Data flow:** `PlayerAdded → DataService.startSession(player) → migrate(Profile.Data) → ready: push snapshot + release the player into the game` — and on any failure, the player never enters play.

```luau
-- DataService.luau — the gate
function DataService.startSession(player: Player): boolean
	local profile, err = ProfileStore:StartSessionAsync(PROFILE_KEY(player), ...)
	if not profile then
		-- No lock / no data: NEVER continue with defaults. Trading exists, so a
		-- defaulted profile on one server + a real profile on another = dupes.
		Log.error("DataService", "session start failed", { player = player.UserId, err = err })
		player:Kick("Could not load your data. Please rejoin.")
		return false
	end
	Migrate.run(profile.Data)             -- pure, ordered, unit-tested
	_profiles[player.UserId] = profile
	return true
end
```

**Rules:**
- **Never fall back to default data.** A failed load means kick with a generic message, not an empty vault.
- No remote handler serves a player until the gate has opened (RemoteService refuses handlers for players without an active profile).
- Migrations run before the first snapshot reaches the client, and only ever forward (`schemaVersion` must not decrease).

**Edge cases:** Studio (ProfileStore mock DataStore) still goes through the gate; a session-lock conflict while playing is ProfileStore's concern — we surface it via `Log.error` and never write around it.

**Usage:** every join, no exceptions — this pattern is what makes ADR-001 true in practice.

### Communication Patterns

**Pattern:** direct `require` of service modules (service locator) for calls; typed **signals** for decoupled notifications; **RemoteEvents** exclusively at the client/server boundary.

```luau
-- server-to-server: direct call when you need a result
local granted = VaultService.grant(player, itemDefId)

-- decoupled notification: signal when callers shouldn't be hard-wired
GameEvents.SetCompleted:Connect(function(player, setId)
	UIBroadcast.notify(player, "Set complete: " .. SetDefs[setId].name)
end)
```

### Entity / Creation Patterns

**Pattern:** *factory from templates* — `DiveService` clones room and loot templates out of `ServerStorage` per run and destroys them on extraction. No object pooling at MVP (a handful of rooms per session); revisit only if MicroProfiler shows clone cost.

### State Transition Pattern

**Pattern:** *explicit state machine* for anything with phases — trading (`OFFERED/CONFIRMED/COMMITTED/EXPIRED`) and the dive run (`ACTIVE/EXTRACTING/CLOSED`). Illegal transitions return an error code; they never `error()`.

```luau
local ALLOWED = {
	OFFERED = { CONFIRMED = true, EXPIRED = true },
	CONFIRMED = { COMMITTED = true, EXPIRED = true },
}
function TradeService.transition(tradeId, to: string): boolean
	local trade = trades[tradeId]
	if not (trade and ALLOWED[trade.state] and ALLOWED[trade.state][to]) then return false end
	trade.state = to
	return true
end
```

### Data Access Pattern

**Pattern:** *ModuleScript services* (Roblox-native) with **`DataService` as the single data gateway**. Services never hold their own long-lived copy of profile data — they read through `DataService.get(player)` and write through its mutators, so there is exactly one authoritative in-memory copy.

### Consistency Rules

| Pattern | Convention | Enforcement |
| --- | --- | --- |
| Client→server traffic | Remote Handler Pipeline only | Code review + no other `OnServerEvent` connections |
| Profile data access | `DataService` only | Boundary rule 2; review |
| Item movement between players | Atomic Dual-Lock Commit | ADR-003; `TradeService.spec.luau` |
| UI state | Read-only `StateMirror` | Boundary rule 5; review |
| Async primitives | `task.wait/spawn/defer` — never `wait()/spawn()/delay()` | selene lint |
| Types | `--!strict` on every new ModuleScript | selene lint + review |
| Formatting | stylua (`stylua.toml`) | `stylua --check src/` |
| Remote handler errors | pcall + generic `Notify`, never bare `error()` | Code review |
| Naming | per Project Structure table | Review |

---

## Architecture Validation

### Validation Summary

| Check | Result | Notes |
| --- | --- | --- |
| Decision Compatibility | PASS | ProfileStore ↔ remote pipeline ↔ atomic commit ↔ mirror all reinforce one boundary; no conflicting decisions found |
| GDD Coverage | PASS | 8/8 core systems mapped to a location in Project Structure |
| Pattern Completeness | PASS | 4 novel + 4 standard patterns, all with code examples; gap found and closed (Session Load Gate) |
| Epic Mapping | DEFERRED | Epics are created in the next workflow step (`gds-create-epics-and-stories`); coarse 5-epic structure already in the GDD |
| Document Completeness | PASS (after fixes) | Executive Summary added; all placeholders absent (grepped: clean) |
| Version Specificity | PASS (after fixes) | Rojo 7.7.0, ProfileStore 1.0.3, Wally 0.3.2, TestEZ 0.4.2, stylua 2.5.2, selene 0.31.0 — all web-verified 2026-09-28 |

### Coverage Report

- **Systems covered:** 8/8 (persistence, remote API, vault, dive, trading, sets, UI, assets/audio)
- **Patterns defined:** 8 (4 novel, 4 standard)
- **Decisions made:** 17
- **ADRs:** 5

### Issues Resolved

1. **Missing Executive Summary** (required section) — added.
2. **Unverified versions** — Wally (0.3.2) and TestEZ (0.4.2) now verified and recorded with dates.
3. **No join/load-failure rule** — safety-critical for a game with trading; added *Session Load Gate* pattern, including the explicit ban on falling back to default data.

### Validation Date

2026-09-28

**Overall Status: PASS** — ready to guide implementation.

---

## Development Environment

### Prerequisites

- **Roblox Studio** (Windows) for playtesting; Rojo place is generated from `src/`, never edited by hand
- **aftman 0.3.0+** managing: Rojo `7.7.0`, stylua `2.5.2`, selene `0.31.0`, Wally `0.3.2`
- **uv** (for BMad `_bmad/scripts` utilities)
- Toolchain lives in `~/.aftman/bin` — **not on PATH**; prefix every command: `PATH="$HOME/.aftman/bin:$PATH" <cmd>`

### Setup Commands

```bash
aftman install                     # installs Rojo, stylua, selene, Wally per aftman.toml
wally install                      # deps (ProfileStore 1.0.3) → Packages/
PATH="$HOME/.aftman/bin:$PATH" rojo build default.project.json -o "secure-data-and-inventory-system.rbxlx"
PATH="$HOME/.aftman/bin:$PATH" stylua --check src/ && PATH="$HOME/.aftman/bin:$PATH" selene src/
```

### First Steps

1. Run the setup commands above and open the built `.rbxlx` in Studio
2. Implement the vertical slice in the first epic, which establishes `src/server` services following the patterns in this document
3. Run `stylua --check src/` and `selene src/` before every review — both must pass

### AI Tooling (MCP Servers)

No engine-specific MCP servers were selected. You can add them later by searching for "Roblox MCP server" to find available integrations.
