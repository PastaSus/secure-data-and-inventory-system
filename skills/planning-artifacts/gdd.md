# Curio Vault — Game Design Document

**Author:** Administrator
**Game Type:** Collect-a-thon / cozy loot-loop with light trading (light roguelite dive structure)
**Target Platform(s):** Roblox — mobile-first UI, PC parity, console via Roblox defaults
**Source:** derived from approved brief `skills/planning-artifacts/briefs/brief-secure-data-and-inventory-system-2026-09-28/brief.md`
**Date:** 2026-09-28

---

## Executive Summary

### Core Concept

Short dives into a ruined seaside observatory, oddities scooped up and stowed in a persistent vault, sets completed, dupes traded — under a server-authoritative data layer where every item is provably singular and provably yours.

### Target Audience

Primary: Roblox players 9–16 who already play collection games (Pet Sim 99, Adopt Me!, MM2), 10–20 minute sessions, mobile-primary. Secondary: 13–20 traders/collectors chasing rarity status.

### Unique Selling Points

1. Dupe-proof by construction — session-locked persistence + server-side trade validation.
2. Sets, not spam — finite curated collections, completion is reachable.
3. Integrity as a visible feature — trade receipts and vault provenance shown in-UI.

---

## Goals and Context

### Project Goals

- Ship an MVP that validates: *does find→stow→complete retain, and does the data layer survive real play?*
- Prove a security claim (no dupes, no rollbacks, no lost saves) under live exploit pressure.
- Leave the data + inventory layer as a self-contained, extractable server module.

### Background and Rationale

The collection genre is proven at massive scale (30B+ visit titles) and saturated on features; the opening is *trust*. Platform tailwind: unified DataStore budget + 500MB storage cap live since 2026-07-29.

---

## Core Gameplay

### Game Pillars

1. **Integrity is gameplay** — every item server-authored, session-locked, singular.
2. **Find → stow → complete** — sets, not raw counts, create direction.
3. **Trade with strangers safely** — dupe-proof, server-arbitrated, rarity-legible.
4. **The vault is the trophy** — the collection is displayable and flex-worthy.

### Core Gameplay Loop

Dive (3–8 min procedural ruin room) → grab oddities within pack capacity → extract → items auto-stow (server-validated) → set progress ticks → completing a set grants vault capacity → dive again.

Session beat: one dive = a complete experience; four dives = a satisfying visit.

### Win/Loss Conditions

No loss state (cozy). A dive ends on **extraction** (player choice) or **pack full** (forced extract). "Win" beats are set completions — each is a visible celebration and awards capacity.

---

## Game Mechanics

### Primary Mechanics

- **Dive:** procedurally assembled room from a fixed pool of 3–5 layout templates, seeded per run. Loot spawns roll from the rarity table. No combat, no failure penalty — extraction is always available.
- **Pack:** hard capacity limit (MVP: **12 slots**), forces triage decisions during a dive.
- **Stow:** on extraction, contents are committed server-side in one validated transaction. Client never holds authoritative inventory.
- **Sets:** 3 collections at MVP, each a list of distinct item IDs. Completing one = celebration + **+4 vault capacity**.
- **Trade:** 1:1 server-arbitrated exchange between two online players. Both confirm, server validates ownership + capacity + non-duplication atomically, emits a trade receipt. Exactly one trade path ships at MVP.
- **Vault:** persistent, browsable, sortable by set/rarity; shows provenance (source run) per item.

### Rarity Roll Table (MVP)

| Rarity | Weight | Notes |
|---|---|---|
| Common | 60% | filler; also set-glue |
| Rare | 25% | set drivers |
| Epic | 12% | set drivers |
| Legendary | 3% | prestige, trade bait |

### Controls and Input

Touch-first: tap-to-grab, swipe-to-browse vault, big thumb-zone Extract button. PC: click + number keys. Console: Roblox default gamepad nav.

---

## Progression and Balance

### Player Progression

Capacity ladder is the whole progression curve: start 8 → pack 12 → vault grows +4 per set. First set completion targeted at **~15–20 minutes** playtime. No levels, no XP, no skill tree at MVP.

### Difficulty Curve

Pressure comes from **scarcity, not danger** — pack fills before greed does. Later dives pull from the same table with tighter layout variety (repeat-room fatigue is a known post-MVP risk).

### Economy and Resources

`[DECISION]` **No currency at MVP.** Removing the currency layer deletes an entire class of exploit surface (negative-quantity, NaN, price tampering) and an entire design surface (balancing sinks). Capacity is the only resource, and it is only ever granted by the server for set completion. Currency is a post-MVP gate, reconsidered through `gds-correct-course`.

---

## Level Design Framework

### Level Types

One biome (ruined seaside observatory) with 3–5 layout templates: entry hall, vault chamber, tower stair, flooded gallery. Templates differ in loot density and route length, not in mechanics.

### Level Progression

None at MVP — all templates available from the first dive. Ordering/unlocking is a post-MVP lever.

---

## Art and Audio Direction

### Art Style

Stylized low-poly, chunky silhouettes so rarity reads at a glance on a phone screen. `[ASSUMPTION]` Marketplace-safe base assets + custom item meshes; solo-dev feasible.

### Audio and Music

Warm, light, percussive. The stow sound and the set-complete sting are the emotional payload and take the polish budget.

---

## Technical Specifications

### Performance Requirements

- Stow commit and trade commit must both be **atomic** — a mid-commit disconnect must never produce a partial or duplicated inventory.
- Save writes debounced (ProfileStore auto-save), no synchronous `SetAsync` on player-facing paths.
- Rate-limit every client remote per player; reject rather than queue.

### Platform-Specific Details

Roblox, server-authoritative (see `AGENTS.md` Policy — client never touches data APIs). DataStore: 4MB/key cap, unified budget, 500MB storage. Studio's lower rate limits mean throttle behavior must be simulated, not assumed.

### Asset Requirements

40 item meshes/icons, 4 rarity frames, 3 layout templates, curator NPC, vault UI kit (mobile-first), stow/set-complete SFX.

---

## Development Epics

Coarse structure for `gds-create-epics-and-stories` to break down (ordering is dependency-driven):

1. **Data foundation** — ProfileStore session-locked profile, item schema, save/load, server-only data API.
2. **Dive & loot** — procedural room, pack, loot rolls, extraction.
3. **Vault & sets** — persistent vault UI, set definitions, completion grants.
4. **Trading** — the single 1:1 arbitrated path + receipts (highest risk — prototype early).
5. **Shell & content** — main menu, navigation, assets, audio, place integration.

---

## Success Metrics

### Technical Metrics

- **Zero** dupe reproduction cases; **zero** lost-save incidents in playtests.
- Save success rate ≥ 99.9% under simulated throttle pressure.

### Gameplay Metrics

- First set completion 15–20 min; ≥3 dives in a typical session; D1 return rate directional (small sample, read as signal only).

---

## Out of Scope (MVP)

Monetization/gamepasses, combat, daily-chore/retention systems, currency, cosmetics shop, guilds/clans, leaderboards, multiple biomes, trading beyond the single 1:1 path.

---

## Assumptions and Dependencies

- `[ASSUMPTION]` Players value the security promise, not just the loop — validate in playtest interviews.
- `[ASSUMPTION]` Sets beat unbounded collecting for retention.
- Dependency: ProfileStore (live successor to archived ProfileService) for session locking.
- Dependency: Rojo/aftman toolchain — see `AGENTS.md` for the PATH caveat.
