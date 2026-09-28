---
title: Game Brief: Curio Vault (working title)
status: approved
created: 2026-09-28
updated: 2026-09-28
---

# Game Brief: Curio Vault — secure-data-and-inventory-system

## Executive Summary

`[ASSUMPTION]` The deliverable is **both, in priority order**: a standalone Roblox experience whose gameplay *is* inventory management, built so that the secure data + inventory layer underneath it is a clean, extractable module. The game is the proving ground; the system is the engineering product. A system with no live players proves nothing about exploit resistance — real players are the only meaningful test of a "secure" claim.

**Curio Vault** is a collect-a-thon: short dives into procedural ruin rooms, oddities scooped up and stowed in a persistent vault. Sets complete, dupes traded, vault becomes a trophy cabinet. The *find → stow → complete* loop that powers Roblox's largest collection titles, under a data layer where every item is provably singular and provably the player's.

Why now: Roblox raised unified DataStore storage from 100MB → 500MB and merged in-game/Open Cloud budgets on 2026-07-29 — the widest persistence headroom ever — while duping and remote-forgery exploits stay endemic in the genre (Steal an Egg's live dupe meta, trade scams across Adopt Me!/MM2). A collection game that *cannot* be duped is a real position, not a marketing line.

## Vision

**Core concept:** A cozy collect-a-thon where every find is permanent, every set is worth completing, and the vault is a dupe-proof trophy cabinet to show off and trade from.

**Core fantasy:** *"The thrill of the find, and the pride of the perfect collection."* The jolt of a rare pull, plus a shelf that fills and stays filled — nothing earned can be taken, duplicated, or rolled back by a bad save.

## Audience

`[ASSUMPTION]` **Primary:** Roblox players 9–16 who already play collection games (Pet Simulator 99, Adopt Me!, MM2). They session in 10–20 minute blocks, check in daily for a few short runs, and care about rarity legibility and status display. Mobile is their primary device — the UI must be touch-first even though development starts on PC.

**Secondary:** older traders/collectors (13–20) who treat rarity tiers as a status economy and grind for prestige items.

**Market:** proven and enormous — Pet Sim 99 (2.6B visits), Adopt Me! (44.7B), MM2 (30.2B), Blox Fruits (64B). The genre needs no validation; it needs *positioning*. Our opening is trust: in a genre where dupes and trade scams are a cultural fixture, a vault with integrity is a differentiator players can feel.

## Core Loop & Pillars

**Genre:** Collect-a-thon / cozy loot-loop with light trading — single-player collection plus social trading, not combat-driven.

**Core loop:** Dive (3–8 min procedural ruin room) → grab oddities, choose what fits the pack → extract → items **auto-stow to the vault, server-validated** → set progress ticks, incomplete sets taunt you → spend dupes or currency on capacity/aesthetic upgrades → dive again. One dive is a complete experience; four dives is a satisfying visit.

**Pillars:**
1. **Integrity is gameplay.** Every item is server-authored, session-locked, and singular. No dupes, no rollbacks, no lost saves — a *designed* promise the player can verify, not a backend detail.
2. **Find → stow → complete.** Short runs feed a growing vault; sets, not raw counts, create direction and make every find legible as progress.
3. **Trade with strangers safely.** Dupe-proof trades with strict server-side validation and clear rarity legibility — the social layer is protected, not just tolerated.
4. **The vault is the trophy.** The collection is displayable and flex-worthy; showing the shelf is half the reward.

## Comps & Differentiation

| Title | Taking | Deliberately NOT taking |
|---|---|---|
| **Pet Simulator 99** | hatch→collect→upgrade cadence, clear rarity tiers | endless currency inflation, P2W gamepass creep |
| **Adopt Me!** | trading as prestige + social engine | pet-care complexity, heavy UGC trade economy |
| **Murder Mystery 2** | rarity tiers as status, trading as endgame | round-based combat structure |
| **Blox Fruits** | inventory-gated progression | combat depth and build variety |

**Competitive analysis:** direct — other collect-a-thons; indirect — any Roblox game with a tradeable inventory. Every competitor has an active duping/exploit conversation; none can honestly market integrity.

`[ASSUMPTION]` **Differentiators (honest, specific):**
1. **Dupe-proof by construction** — session-locked persistence (ProfileStore lineage) + server-side trade validation means items cannot be minted twice. The claim is architectural, verifiable, and competitors structurally can't match it without the same rewrite.
2. **Sets, not spam** — curated finite set collections rather than infinite item bloat, so completion is actually reachable and progress reads clearly.
3. **Integrity as visible feature** — trade receipts and vault provenance make the security legible in-UI instead of invisible.

*If the edge turns out to be execution and feel, that is what the brief will say — no fabricated moats.*

## Scope & MVP

**Platform (prioritized):** Roblox — **mobile-first UI**, PC parity, console compatibility via Roblox defaults. `[ASSUMPTION]` No native/external surface.

**Team & timeline:** solo developer, part-time. `[ASSUMPTION]` MVP targeted in ~6 weeks part-time; no budget line (personal project). Scope is deliberately sized to one person — every pillar above survives at MVP scale.

**Technical constraints:** Luau + Rojo; server-authoritative everything (per `AGENTS.md` policy — client never touches data APIs); DataStore 4MB/key limit, unified budget model since 2026-07-29, 500MB storage cap; Studio's separate lower rate limits make throttling behavior hard to reproduce locally.

**MVP (validates the core hypothesis: *does find→stow→complete retain, and does the data layer survive real play?*):**
- 1 biome, ~40 oddities across 4 rarity tiers, 3 completable sets
- persistent vault with set completion + stow flow (server-validated)
- ProfileStore-based save with session locking; no item created outside the server
- one trade path (dupe-proof), pack capacity limit
- **no monetization, no combat, no daily-chore systems** — post-MVP gates

Out of scope for MVP: multiple biomes, cosmetics shop, guilds/clans, leaderboards, gamepasses.

## Content & Direction

**Setting:** A ruined seaside observatory and its sealed vaults — cozy, slightly mysterious, not scary. Reads well in low-poly and justifies "rooms full of things to take."

**Narrative:** Minimal. Environmental storytelling plus a curator NPC who names sets. No dialogue trees at MVP.

**Breadth:** 1 biome, 3–5 procedural room layouts, ~40 items, 3 sets, ~15–20 min to first set completion, high replay via rarity odds.

**Art:** stylized low-poly, chunky silhouettes so rarity reads at a glance on a phone screen. `[ASSUMPTION]` Solo-dev feasible: marketplace-safe base assets + custom item meshes.

**Audio:** warm, light, percussive — stow and set-complete sounds are the emotional payload and get the polish budget.

## Risks & Open Questions

1. **Trading is the highest-risk surface** — trade-window dupes, race conditions on simultaneous trade + rejoin. Mitigation: ship *one* server-arbitrated trade path in MVP, prototyped before any second path — this is the mechanic most likely to break the pillar that sells the game.
2. **Solo scope creep** — collectathons balloon (cosmetics, events, shops). Mitigation: the MVP boundary above is a hard gate; anything new goes to `gds-correct-course`.
3. **DataStore throttling invisible in Studio** — failures only appear under real load. Mitigation: retries/backoff from day one; test with simulated budget pressure.
4. **Market saturation** — the genre is crowded. Mitigation: integrity positioning + set-based completion, not feature parity.

**Open questions for GDD/architecture:**
- What is an "oddity"? Item schema, stack rules (stacking vs. unique), how rarity is rolled.
- Trade rules: 1:1? currency leg? cooldowns? What stops shill-account laundering?
- How is integrity *shown* (receipts, provenance) without jargon?
- Daily reward / retention mechanics — post-MVP, but which ones?

**Assumptions to validate first:** players care about the security promise at all (vs. just liking the loop); sets beat unbounded collecting for retention.
