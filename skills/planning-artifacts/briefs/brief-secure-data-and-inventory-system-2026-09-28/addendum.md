# Addendum — Curio Vault brief

Research depth for downstream `gds-gdd` / architecture work. Not part of the 1–2 page brief.

## 1. Decision: system + game (both), game first

The folder name describes a system. Decision: build the **standalone experience as the primary deliverable**, with the data + inventory layer written as a self-contained module from day one (server-only API, no gameplay coupling).

Rationale: a security claim is unprovable without live players under real exploit pressure; a library with no flagship has no adoption story; and the GDS workflow (brief → architecture → epics → stories) assumes a game to design. The game gives the system a reason to exist and a test bed; the system gives the game its one honest differentiator.

If the project pivots to library-first, the extraction cost is already designed down: the module boundary is the deliverable.

## 2. Ecosystem research (2026-09-28)

### 2.1 Persistence libraries

- **ProfileService** (loleris/MadStudioRoblox) — session-locked savable tables, auto-save spread across the save loop, MetaTags/GlobalUpdates; targets item-loss and item-duplication loopholes from multi-server edits. **Repo archived — no longer supported.** 325 GitHub stars; DevForum thread 376K views / 1,312 replies. https://github.com/MadStudioRoblox/ProfileService
- **ProfileStore** — live successor. Session locking + auto-save, `Steal`/`Cancel` params, mock DataStore when API access is off; designed to "prevent item duping in a game with trading." Not for leaderboards/global state. 171K views / 394 replies. https://github.com/MadStudioRoblox/ProfileStore · https://devforum.roblox.com/t/profilestore-save-your-player-data-easy-datastore-module/836549
- **DataStore2** (Kampfkarren) — caching wrapper, ordered-backup saving, serializer hooks (inventory precedent: item-ID compression). **No session locking** — forum consensus: you must add it yourself. Adopters: Dungeon Quest (600M+ visits), Baldi's Basics (140M). https://kampfkarren.github.io/Roblox · https://devforum.roblox.com/t/should-i-use-profileservice-datastore2-or-datastoreservice/1611913
- **Knit** (Sleitnick) — service/controller + remote networking layer. 630 stars, **archived**; not a persistence layer. Pattern reference only. https://github.com/Sleitnick/Knit
- Others (Suphi's DataService, Scribe, DocumentService, VirtualStore, Nexus) — adoption UNVERIFIED.

**Working choice:** ProfileStore for persistence (session locking is non-negotiable for the integrity pillar); networking layer decision deferred to `gds-game-architecture`.

### 2.2 Exploit surface and failure modes

- **Never trust the client** — exploiters control local state, fire remotes at arbitrary frequency with arbitrary args, and can hold network ownership. https://create.roblox.com/docs/en-us/scripting/security/security-tactics
- **Remote spam/forgery** — engine ceiling ~500 req/s/client; needs per-player server-side rate limits, item-name whitelisting, and server-authoritative prices/values. https://gmmarket.me/community/post/roblox-remoteevent-security-how-exploits-work-and-how-to-stop-them-never-trust-t
- **Negative / NaN / infinity quantities** — `NaN` bypasses `< 0` and `> max` range checks; `-1` quantity can *grant* currency. Validate `x == x`, `math.floor` + clamp, require `quantity > 0`. https://create.roblox.com/docs/en-us/scripting/security/client-server-boundary
- **Duping via rejoin/trade race** — trade, leave, save fails, rejoin with original items. Session locking is the documented counter. `SetAsync` causes cross-server inconsistency; `UpdateAsync` reads-before-writes at read+write budget cost. https://create.roblox.com/docs/en-us/scripting/security/client-server-boundary
- **DataStore loss/throttle** — 4MB/key, 25MB/min read, 4MB/min write throughput, `*Throttle` error codes; Studio has separate, lower limits. https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits
- **Ownership checks** — verify an Instance actually belongs to the requesting player's Backpack/Character before acting on it.

### 2.3 Platform changes 2025–2026

- **Unified per-experience DataStore budget** (in-game + Open Cloud merged), base raised to 300 + CCU multiplier; **storage 100MB → 500MB**; live **2026-07-29**. https://devforum.roblox.com/t/unifying-data-stores-open-cloud-and-game-apis-and-increasing-storage-limits/4739240
- Per-key limit still 4MB (raise debate Apr 2025). https://devforum.roblox.com/t/increase-data-store-limit-from-4mb-to-8mb-or-more/3633015
- **MemoryStoreService** gains `MemoryStoreHashMap`; per-structure limits replaced by global per-partition throttle; quota `1000 + 120×CCU` req/min. https://create.roblox.com/docs/cloud-services/memory-stores
- `SetRateLimitForRequestType` (v709) lets servers tune budget. https://create.roblox.com/docs/reference/engine/classes/DataStoreService
- Data Stores Observability dashboard updates (2025). https://devforum.roblox.com/t/powerful-updates-for-data-stores-observability-dashboard/3774411/8

## 3. Comparable scale (Sept 2026)

| Title | ~Live CCU | All-time visits |
|---|---|---|
| Steal an Egg | 1.7–2.4M | 1.9B |
| Blox Fruits | 300–750K | ~64B |
| Murder Mystery 2 | 200–330K | 30.2B |
| Adopt Me! | 143–190K | 44.7B |
| Pet Simulator 99 | 48–78K | 2.6B |

Sources: https://bloxodes.com/stats/games · https://bloxodes.com/stats · https://www.robloxtracker.net/rankings/top-visits

*Why these loops work mechanically (rarity tiers, trading, limiteds) — UNVERIFIED, not sourced.*

## 4. Technical constraints to carry into architecture

- Server-only DataStore access; client requests via RemoteEvents, server validates (matches `AGENTS.md` Policy).
- 4MB/key cap → item schema must be compact (DataStore2-style item-ID compression is the known precedent); avoid storing per-item blobs when an ID + count suffices.
- Session locking required for any item that can be traded — ProfileStore.
- Rate-limit/backoff retries from day one; Studio cannot reproduce real throttle behavior.
- Mobile-first UI constraint affects every inventory screen decision in the GDD/UX work.
