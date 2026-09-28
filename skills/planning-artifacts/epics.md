---
stepsCompleted: [1, 2, 3, 4]
inputDocuments: ['skills/planning-artifacts/gdd.md', 'skills/planning-artifacts/game-architecture.md']
---

# secure-data-and-inventory-system - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for secure-data-and-inventory-system (Curio Vault), decomposing the requirements from the GDD and Architecture into implementable stories. No UX Design document exists for this project (excluded as an optional artifact); interaction requirements are carried from the GDD's Controls/Input and Platform sections.

## Requirements Inventory

### Functional Requirements

FR1: Assemble a dive room procedurally from the 3–5 fixed layout templates, seeded per run, with loot spawns rolled from the rarity table.

FR2: Loot rolls follow the MVP rarity table exactly (Common 60%, Rare 25%, Epic 12%, Legendary 3%).

FR3: The pack enforces a hard 12-slot capacity limit; when the pack is full the dive forces extraction.

FR4: The player may extract at will at any time; extraction ends the dive with no loss state.

FR5: On extraction, pack contents are committed server-side in one validated atomic transaction (stow) — the client never holds authoritative inventory.

FR6: The vault persists across sessions, is browsable, sortable by set and rarity, and shows provenance (source run) per item.

FR7: Exactly 3 sets ship at MVP, each a list of distinct item IDs; completing a set triggers a visible celebration and grants +4 vault capacity (server-granted only).

FR8: Capacity ladder is enforced: vault starts at 8 slots, pack is 12, each set completion grants +4 vault capacity.

FR9: One 1:1 player-to-player trade path ships at MVP: both players confirm, the server validates ownership + capacity + non-duplication atomically, and a trade receipt is emitted and shown in-UI.

FR10: Player data loads through a session-locked ProfileStore profile with forward-only schema migration on load.

FR11: A join gate prevents gameplay until the session lock succeeds; a failed load kicks the player — the game never continues on defaulted data.

FR12: All UI state arrives as a server-fed read-only mirror pushed after the gate opens; the client sends RemoteEvent requests and the server validates before touching data.

FR13: Every client remote is rate-limited per player; requests are rejected rather than queued.

FR14: The shell provides a main menu and navigation to dive, vault, and trade flows (mobile-first).

FR15: Integrity features are visible in-UI: trade receipts and vault provenance (integrity as a visible feature).

### NonFunctional Requirements

NFR1: Stow commit and trade commit are atomic — a mid-commit disconnect never produces a partial or duplicated inventory.

NFR2: Save writes are debounced via ProfileStore auto-save; no synchronous SetAsync on player-facing paths.

NFR3: All DataStore access is server-side only; the client never reads or writes player data (AGENTS.md Policy).

NFR4: Exploit resilience: zero dupe reproduction cases and zero lost-save incidents under playtest/exploit pressure; save success rate ≥ 99.9% under simulated throttle pressure.

NFR5: Mobile-first touch input (tap-to-grab, swipe-to-browse, thumb-zone Extract button) with PC parity and Roblox default gamepad navigation.

NFR6: Respect Roblox DataStore limits (4MB/key, unified budget, 500MB storage); Studio throttle behavior must be simulated, not assumed.

NFR7: The data + inventory layer stays a self-contained, extractable server module.

NFR8: Code quality gate: `--!strict` Luau, tab indentation, `stylua --check src/` and `selene src/` both pass before review.

NFR9: Balance target: first set completion in ~15–20 minutes of playtime.

### Additional Requirements

- **Starter template:** Architecture specifies the existing Rojo hello-world scaffold (`src/server/init.server.luau`, `src/client/init.client.luau`, `src/shared/Hello.luau`) mapped via `default.project.json` — Epic 1 Story 1 must establish the Project Structure layout on top of it, not recreate tooling.
- **Dependency setup:** Wally `0.3.2` + ProfileStore `1.0.3` pinned with lockfile; Rojo 7.7.0 / stylua 2.5.2 / selene 0.31.0 via aftman (`PATH="$HOME/.aftman/bin:$PATH"` prefix required).
- **Session Load Gate (mandatory pattern):** `PlayerAdded → startSession → migrate → ready → release into game`; kick with generic message on failure; no remote handler serves a player without an active profile.
- **RemoteService pipeline:** single validated remote pipeline; handlers registered server-side; handlers refuse players before the gate opens; structured `Log` on all rejections.
- **Atomic trade commit:** dual-lock commit as the one novel pattern (ADR); server-side only; receipt persisted.
- **Schema migration:** forward-only; `schemaVersion` must never decrease; migrations run before first snapshot reaches the client.
- **Version pinning:** record Rojo 7.7.0, ProfileStore 1.0.3, Wally 0.3.2, TestEZ 0.4.2, stylua 2.5.2, selene 0.31.0.
- **Testing:** TestEZ `0.4.2` for pure server logic (rolls, trade validation, schema); Studio/Team Test for integration; `build → rbxlx`, never hand-edit `*.rbxlx`.
- **No currency at MVP** (GDD `[DECISION]`): capacity is the only resource and only the server grants it.
- **Rate limiting:** per-player, per-remote, reject-not-queue (also an NFR, enforced in RemoteService).

### UX Design Requirements

None — no UX Design document exists (excluded as an optional artifact). The following interaction constraints from the GDD stand in for UX-DRs:

UX-DR1: Touch-first controls: tap-to-grab, swipe-to-browse vault, Extract button in the thumb zone.

UX-DR2: Set completion and stow have prominent celebration/feedback moments (stow sound + set-complete sting take the polish budget).

UX-DR3: Rarity must read at a glance on a phone screen (chunky silhouettes, 4 rarity frames).

UX-DR4: Vault UI is sortable by set and rarity with per-item provenance visible.

### FR Coverage Map

FR1: Epic 2 — procedural dive room from layout templates
FR2: Epic 2 — rarity-table loot rolls
FR3: Epic 2 — 12-slot pack forces extraction
FR4: Epic 2 — voluntary extraction, no loss state
FR5: Epic 2 — atomic server-side stow on extraction
FR6: Epic 3 — persistent, browsable, sortable vault with provenance
FR7: Epic 3 — 3 sets, completion celebration, +4 capacity grant
FR8: Epic 2 (base ladder 8/12) + Epic 3 (set-granted growth)
FR9: Epic 4 — single 1:1 arbitrated trade with atomic validation
FR10: Epic 1 — session-locked ProfileStore load + forward-only migration
FR11: Epic 1 — join gate, kick on failure, never defaulted data
FR12: Epic 1 — server-fed read-only mirror; validated remote requests
FR13: Epic 1 — per-player remote rate limiting, reject-not-queue
FR14: Epic 1 (main menu entry) + Epic 5 (navigation to all flows)
FR15: Epic 3 (provenance) + Epic 4 (trade receipts) + Epic 5 (integrity presentation)

## Epic List

### Epic 1: Safe Join — My Collection Survives
The player enters the game from a main menu and their data reliably persists across rejoins; a failed load kicks them cleanly instead of ever playing on empty/defaulted data. Delivers the session load gate, ProfileStore persistence, the validated remote pipeline, and the server-fed mirror — the security spine every later epic builds on.
**FRs covered:** FR10, FR11, FR12, FR13, FR14 (menu entry)
**Implementation notes:** Epic 1 Story 1 starts from the existing Rojo scaffold (architecture's starter-template requirement); Wally + ProfileStore pinned here. Everything server-authoritative per AGENTS.md.

### Epic 2: Dive & Stow — The Core Loop Works
The player runs a dive through a procedurally assembled room, grabs oddities within pack capacity, extracts voluntarily or when the pack fills, and finds everything they grabbed in their vault afterward — committed in one atomic server transaction.
**FRs covered:** FR1, FR2, FR3, FR4, FR5, FR8 (base ladder: vault 8 / pack 12)
**Implementation notes:** Deliverable value is the full find→stow→persist loop; loot rolls and stow commit are pure logic covered by TestEZ.

### Epic 3: Vault & Sets — The Trophy Case Fills Up
The player browses a persistent vault sortable by set and rarity with per-item provenance, completes any of 3 curated sets, and celebrates as the server grants +4 vault capacity — the whole progression curve.
**FRs covered:** FR6, FR7, FR8 (set-granted growth), FR15 (provenance)
**Implementation notes:** Set definitions are content data (distinct item IDs); UI is mobile-first vanilla ScreenGui per architecture.

### Epic 4: Safe Trading — Trade Dupes with Strangers
Two online players complete a 1:1 trade where both confirm, the server atomically validates ownership, capacity, and non-duplication, and both sides receive a visible trade receipt.
**FRs covered:** FR9, FR15 (receipts)
**Implementation notes:** Highest-risk epic per GDD (dual-lock atomic commit, ADR-004). Separated as a risk boundary; the commit primitive is pure logic with TestEZ coverage, so this epic can start right after Epic 2 if risk review calls for it. No shared-file overlap with Epic 3 — receipts live in the trade flow's own UI.

### Epic 5: Shell & Content — The Game Feels Finished
The player navigates between dive, vault, and trade flows from the shell with the curated content in place (item meshes/icons, rarity frames, layouts, curator NPC, stow/set-complete audio), and the integrity features are presented as a visible feature.
**FRs covered:** FR14 (navigation to all flows), FR15 (integrity presentation)
**Implementation notes:** Covers UX-DR1–4, asset requirements (40 meshes, 4 frames, 3 templates, SFX), NFR5 (touch-first/PC/gamepad), and place integration. Content may partially land earlier as placeholders; this epic is where it's all wired and polished.


---

## Epic 1: Safe Join — My Collection Survives

The player enters the game from a main menu and their data reliably persists across rejoins; a failed load kicks them cleanly instead of ever playing on defaulted data. Delivers the session load gate, ProfileStore persistence, the validated remote pipeline, and the server-fed mirror — the security spine every later epic builds on.

**FRs covered:** FR10, FR11, FR12, FR13, FR14 (menu entry)

### Story 1.1: Project Structure on the Existing Scaffold

As a developer,
I want the Rojo scaffold reorganized into the architecture's project structure with the pinned toolchain working,
So that every later story lands files in the right place and quality gates run from the first commit.

**Acceptance Criteria:**

**Given** the existing hello-world scaffold (`src/server/init.server.luau`, `src/client/init.client.luau`, `src/shared/Hello.luau`)
**When** I run `aftman install` and the build/lint commands from the architecture's Development Environment section
**Then** Rojo builds `secure-data-and-inventory-system.rbxlx` which opens in Roblox Studio
**And** `stylua --check src/` and `selene src/` both pass with zero findings
**And** empty service/module folders from the architecture's Project Structure exist under `src/server`, `src/client`, `src/shared` ready to be filled by later stories

### Story 1.2: Session-Locked Profile Load

As a player,
I want my collection stored in a session-locked profile that loads with forward-only migration,
So that my data survives rejoins and can never be silently reset.

**Acceptance Criteria:**

**Given** Wally `0.3.2` is installed and ProfileStore `1.0.3` is pinned in the lockfile
**When** the server starts a session for a joining player
**Then** `DataService.startSession` obtains a ProfileStore session lock before any gameplay begins
**And** profile data carries a `schemaVersion`; migration runs forward-only and never decreases it
**And** the profile schema includes only what this story needs: vault items (with provenance fields) and vault capacity (start 8) — trade state is added by Story 4.1 when first needed (data created only when required)
**And** no synchronous `SetAsync` occurs on the player-facing path (NFR2)
**And** TestEZ covers the migration function for a fresh profile and an older-schema profile

### Story 1.3: Join Gate — Never Play on Defaulted Data

As a player,
I want the game to either load my real data or tell me to rejoin,
So that a failed load can never create a ghost copy of my inventory.

**Acceptance Criteria:**

**Given** a player joins and session lock acquisition fails (lock conflict, DataStore outage)
**When** `startSession` returns failure
**Then** the player is kicked with a generic "Could not load your data. Please rejoin." message
**And** they are never released into gameplay with default data (Session Load Gate pattern, ADR-001)
**Given** a player joins and the session lock succeeds
**When** migration completes
**Then** the player is released into the game and receives their initial data snapshot
**And** structured `Log` output records both the success and failure paths
**And** the Studio path (ProfileStore mock DataStore) goes through the same gate

### Story 1.4: Validated Remote Pipeline and Read-Only Mirror

As a player,
I want every action I take sent through one validated server pipeline that pushes my state back to me,
So that the client can never desync from — or tamper with — my real inventory.

**Acceptance Criteria:**

**Given** a player has passed the join gate
**When** any client request arrives at `RemoteService`
**Then** the server validates it (player has active profile, payload shape, rate-limit budget) before any data mutation
**And** rate limits are per-player per-remote and **reject rather than queue** (FR13)
**And** rejections emit structured `Log` entries with the rejection reason
**Given** a player's server-side state changes
**When** the server pushes the snapshot
**Then** the client's mirror is read-only and is the only source UI renders from (mirror pattern)
**And** a request from a player without an active profile is refused
**And** a mirror-driven test view (capacity "8 / 8", item count) renders from the pushed snapshot, proving the round trip — Story 1.5 then surfaces this view inside the main menu

### Story 1.5: Main Menu Entry

As a player,
I want to enter the game through a main menu,
So that I have a clear, mobile-first starting point for every flow.

**Acceptance Criteria:**

**Given** the game starts
**When** the session gate opens
**Then** a main menu ScreenGui appears with entry points to Dive, Vault, and Trade (later epics' destinations may be visibly placeholder)
**And** the primary action sits in the thumb zone per UX-DR1 (touch-first controls)
**And** menu content derives only from the read-only mirror
**And** PC click and Roblox default gamepad navigation reach the same controls (NFR5)

---

## Epic 2: Dive & Stow — The Core Loop Works

The player runs a dive through a procedurally assembled room, grabs oddities within pack capacity, extracts voluntarily or when the pack fills, and finds everything they grabbed in their vault afterward — committed in one atomic server transaction.

**FRs covered:** FR1, FR2, FR3, FR4, FR5, FR8 (base ladder: vault 8 / pack 12)

### Story 2.1: Seeded Procedural Room Assembly

As a player,
I want each dive to assemble a fresh-feeling ruin room from the fixed layout pool,
So that runs differ while the space stays learnable.

**Acceptance Criteria:**

**Given** the layout template pool (entry hall, vault chamber, tower stair, flooded gallery — 3–5 templates)
**When** a dive starts
**Then** a room is assembled from templates seeded per run (same seed ⇒ same layout)
**And** loot spawn positions derive from the chosen templates
**And** the assembly logic is a pure function covered by TestEZ for determinism and pool bounds
**And** no template introduces mechanics beyond loot density / route length (GDD Level Design Framework)

### Story 2.2: Rarity-Table Loot Rolls

As a player,
I want loot to drop at the documented rarity odds,
So that the hunt feels fair and Legendary actually means something.

**Acceptance Criteria:**

**Given** the MVP rarity table (Common 60%, Rare 25%, Epic 12%, Legendary 3%)
**When** a loot spawn is resolved
**Then** the roll matches the table exactly (FR2)
**And** TestEZ verifies the roll function's distribution stays within tolerance over a large sample and never returns an unknown rarity
**And** the rolled item carries a unique server-generated instance ID and rarity

### Story 2.3: Pack Capacity and Grab

As a player,
I want a 12-slot pack so every grab is a choice,
So that triage pressure drives the dive.

**Acceptance Criteria:**

**Given** a player in a dive with an empty 12-slot pack
**When** they tap an oddity (tap-to-grab, UX-DR1)
**Then** the server validates and records the grab, and the client mirror shows the slot filled
**Given** the pack has 11 slots filled
**When** the player attempts a 12th grab
**Then** it succeeds and fills the pack
**Given** the pack is full (12/12)
**When** the player taps another oddity
**Then** the server rejects the grab with visible "pack full" feedback and the item is not added
**And** base capacity ladder is enforced: vault capacity starts at 8 (FR8)

### Story 2.4: Extraction — Voluntary and Forced

As a player,
I want to extract whenever I choose, and be forced out when the pack fills,
So that a dive always ends cleanly with no loss state (GDD win/loss).

**Acceptance Criteria:**

**Given** a player mid-dive
**When** they press Extract (thumb-zone button per UX-DR1)
**Then** the dive ends and the stow flow begins
**Given** the pack reaches 12/12
**When** the grab that filled it resolves
**Then** extraction is forced automatically
**And** in both cases there is no failure state, no item loss, and no penalty (cozy rule)
**And** the player returns to the shell with the dive marked complete (source run ID recorded for stow)

### Story 2.5: Atomic Stow Commit

As a player,
I want everything I extracted to land in my vault in one indivisible server transaction,
So that a disconnect mid-save can never duplicate or half-store my finds.

**Acceptance Criteria:**

**Given** a dive ends with N items in the pack
**When** the stow transaction runs on the server
**Then** all N items commit to the vault in one atomic operation (NFR1) — all or nothing
**And** each stored item records provenance: source run ID, rarity, instance ID, stow timestamp
**And** the client never holds authoritative inventory during the commit (NFR3)
**Given** the commit is interrupted (simulated disconnect / injected failure)
**When** state is inspected afterward
**Then** the vault is exactly pre-commit or exactly post-commit — never partial, never doubled
**And** TestEZ covers the commit primitive for success, interruption, and duplicate-instance-ID rejection
**And** the stow moment plays visible/audible feedback (placeholder OK until Epic 5 polish)

---

## Epic 3: Vault & Sets — The Trophy Case Fills Up

The player browses a persistent vault sortable by set and rarity with per-item provenance, completes any of 3 curated sets, and celebrates as the server grants +4 vault capacity — the whole progression curve.

**FRs covered:** FR6, FR7, FR8 (set-granted growth), FR15 (provenance)

### Story 3.1: Vault Browse and Sort

As a collector,
I want a persistent vault I can browse and sort by set and rarity,
So that my collection feels like an organized trophy case.

**Acceptance Criteria:**

**Given** a player with stored items
**When** they open the vault from the shell
**Then** every persisted item renders from the read-only mirror (data matches server state exactly)
**And** sorting by set and by rarity both work and are mobile-first (swipe-to-browse, UX-DR1/UX-DR4)
**Given** a returning player
**When** they rejoin
**Then** the vault shows the same items as before the session ended (FR6 persistence)
**And** empty-vault state is a designed state, not a blank screen

### Story 3.2: Set Definitions and Completion Detection

As a collector,
I want 3 curated sets with distinct item IDs that tick off as I collect,
So that I always know what I'm hunting next.

**Acceptance Criteria:**

**Given** 3 set definitions, each a list of distinct item IDs (content data)
**When** an item is stowed
**Then** the server updates set progress from the persisted vault — never from client claims
**And** a set is complete exactly when all its member IDs are present in the vault (no duplicates count twice)
**And** TestEZ covers detection for: empty vault, one missing item, full set, and duplicate items

### Story 3.3: Set Completion Celebration and Capacity Grant

As a collector,
I want completing a set to be a visible celebration that grows my vault by 4,
So that finishing a collection is the emotional and progression payoff.

**Acceptance Criteria:**

**Given** a player's vault satisfies a set definition
**When** the server detects completion
**Then** vault capacity increases by exactly +4 server-side (the only capacity-grant path — no currency, no other sources)
**And** a set-complete celebration fires in-UI with its audio sting (placeholder asset OK until Epic 5)
**And** the grant is idempotent: re-detection or rejoin never grants the same set twice
**And** the new capacity is reflected in the pushed mirror before the UI shows it
**And** first set completion remains reachable in ~15–20 minutes of play (NFR9 — verified in playtest, Epic 5)

### Story 3.4: Per-Item Provenance Display

As a collector,
I want to see where each item came from,
So that the vault doubles as proof of legitimate ownership (integrity as a visible feature).

**Acceptance Criteria:**

**Given** an item stored by stow (with provenance from Story 2.5)
**When** the player inspects it in the vault
**Then** the UI shows its source run ID, rarity, and when it was stowed (FR15 provenance, UX-DR4)
**And** provenance renders only from server-persisted data
**Given** an item with no provenance record (corrupt/legacy)
**When** rendered
**Then** it displays an explicit "unverified" marker rather than guessing

---

## Epic 4: Safe Trading — Trade Dupes with Strangers

Two online players complete a 1:1 trade where both confirm, the server atomically validates ownership, capacity, and non-duplication, and both sides receive a visible trade receipt.

**FRs covered:** FR9, FR15 (receipts)

### Story 4.1: Trade Invitation and Dual Confirmation

As a trader,
I want to propose a 1:1 item trade that both sides must explicitly confirm,
So that nothing moves without clear consent from both players.

**Acceptance Criteria:**

**Given** two players online in the shell
**When** player A proposes a trade to player B with one item each
**Then** both players see the proposed trade in a confirmation UI and both must confirm (no self-confirm shortcut)
**And** the profile schema gains its pending-trade state structure in this story — the first point it is needed (data created only when required)
**Given** either player cancels, goes offline, or the invite times out
**When** the trade state resolves
**Then** the trade is aborted with no inventory change on either side
**And** exactly one trade path exists at MVP (GDD: single path ships)
**And** trade requests are rate-limited per-player via RemoteService (FR13)

### Story 4.2: Atomic Dual-Lock Trade Commit

As a player,
I want the server to validate and swap both inventories in one indivisible step,
So that a race or disconnect can never dupe an item or strand a trade.

**Acceptance Criteria:**

**Given** both players have confirmed
**When** the server runs the commit
**Then** it validates: A owns item X, B owns item Y, both have capacity after the swap, and no instance ID is duplicated — atomically (FR9, ADR-004 dual-lock)
**And** the swap is all-or-nothing: injected failure or either player disconnecting mid-commit leaves both inventories exactly as before (NFR1)
**And** the same instance ID never exists in two vaults at any observable moment
**And** TestEZ covers: happy path, missing ownership, insufficient capacity, duplicate instance ID, and mid-commit interruption
**And** both players' read-only mirrors update from the post-commit server state only

### Story 4.3: Trade Receipts

As a trader,
I want a persisted receipt for every completed trade,
So that I have visible proof of what was exchanged, when, and with whom.

**Acceptance Criteria:**

**Given** a committed trade
**When** both mirrors refresh
**Then** each side shows a receipt: items exchanged, counterpart, timestamp, receipt ID (FR15)
**And** receipts persist across sessions in the profile
**And** aborted trades never produce a receipt
**And** receipts render only from server data

---

## Epic 5: Shell & Content — The Game Feels Finished

The player navigates between dive, vault, and trade flows from the shell with the curated content in place (item meshes/icons, rarity frames, layouts, curator NPC, stow/set-complete audio), and the integrity features are presented as a visible feature.

**FRs covered:** FR14 (navigation to all flows), FR15 (integrity presentation)

### Story 5.1: Shell Navigation Wiring

As a player,
I want to move between Dive, Vault, and Trade from one shell with sane back navigation,
So that the game feels like a whole, not stitched-together screens.

**Acceptance Criteria:**

**Given** the main menu and the flows delivered by Epics 1–4
**When** the player navigates menu → dive → (extract) → vault → trade → menu
**Then** every transition works with a consistent back/close path (FR14)
**And** navigation works on touch, PC, and gamepad (NFR5)
**And** no flow is reachable before the join gate has opened

### Story 5.2: Content Integration

As a player,
I want the curated visuals in place — item meshes/icons, rarity frames, the ruined observatory, the curator NPC,
So that rarity reads at a glance and the world feels authored.

**Acceptance Criteria:**

**Given** the asset list (40 item meshes/icons, 4 rarity frames, 3 layout templates, curator NPC, vault UI kit)
**When** the player sees items, sets, and rooms
**Then** each item renders its mesh/icon and its rarity frame from the 4-frame set (UX-DR3: rarity legible at phone size)
**And** all 3 layout templates in use show their distinct dressing
**And** the curator NPC is present in the shell with placeholder dialogue wiring
**And** missing assets degrade to a visible placeholder, never a silent failure

### Story 5.3: Audio Pass

As a player,
I want the stow sound and set-complete sting to land with weight,
So that the two emotional payload moments feel rewarding.

**Acceptance Criteria:**

**Given** audio assets (stow SFX, set-complete sting, light ambience)
**When** a stow commits or a set completes
**Then** the corresponding sound plays for the acting player, synchronized to the server-confirmed moment (not the client prediction)
**And** audio respects Roblox volume/mute settings
**And** sounds are wired through the same events the celebration UI uses (no parallel triggers)

### Story 5.4: Integrity Presented as a Feature

As a player,
I want the game to visibly show that my collection is protected,
So that the trust promise (dupe-proof, provably mine) is legible rather than just claimed.

**Acceptance Criteria:**

**Given** receipts, provenance markers, and session-lock behavior from Epics 1–4
**When** the player views their vault and trade history
**Then** the UI surfaces the integrity story: verified provenance, receipt history, and a clear language for "server-verified" states (FR15 presentation)
**And** no integrity claim is displayed unless backed by actual server data
**And** an "unverified" state (Story 3.4) is visually distinct from verified

### Story 5.5: Playtest Readiness and Quality Gate

As a developer,
I want a built place that passes the quality gates and a playtest checklist against our success metrics,
So that the MVP claim (no dupes, no rollbacks, retained loop) is actually evidenced.

**Acceptance Criteria:**

**Given** the assembled game
**When** `rojo build` output is opened and Team Test runs
**Then** a full loop works: menu → dive → stow → vault → set complete → trade → rejoin with everything intact
**And** `stylua --check src/` and `selene src/` pass (NFR8)
**And** Studio throttle simulation exercises rate limits and save debounce (NFR2/NFR6) with save success ≥ 99.9% under pressure
**And** a dupe-hunt pass attempts: rapid double-submit, mid-commit disconnect, forged remote payloads — zero reproductions (NFR4)
**And** playtest measures first set completion lands in the 15–20 min band (NFR9)
