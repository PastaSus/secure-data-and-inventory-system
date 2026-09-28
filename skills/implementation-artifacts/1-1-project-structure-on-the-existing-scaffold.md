# Story 1.1: Project Structure on the Existing Scaffold

Status: ready-for-dev

## Story

As a developer,
I want the Rojo scaffold reorganized into the architecture's project structure with the pinned toolchain working,
so that every later story lands files in the right place and quality gates run from the first commit.

## Acceptance Criteria

1. **Given** the existing hello-world scaffold (`src/server/init.server.luau`, `src/client/init.client.luau`, `src/shared/Hello.luau`)
   **When** I run `aftman install` and the build/lint commands from the architecture's Development Environment section
   **Then** Rojo builds `secure-data-and-inventory-system.rbxlx` which opens in Roblox Studio
   **And** `stylua --check src/` and `selene src/` both pass with zero findings
2. **Given** the architecture's Project Structure
   **When** the reorganization is done
   **Then** the folders it specifies exist under `src/` (`shared/Config/`, `server/Services/`, `client/Controllers/`, plus `tests/`) ready for later stories to fill
3. Toolchain is complete and pinned per architecture: `aftman.toml` includes Wally `0.3.2` alongside Rojo `7.7.0`, stylua `2.5.2`, selene `0.31.0`.
4. Quality gates run locally with the documented command prefix and pass.

## Tasks / Subtasks

- [ ] Add Wally to the toolchain (AC: 3)
  - [ ] Add `wally = "UpliftGames/wally@0.3.2"` to `aftman.toml` `[tools]`
  - [ ] Run `aftman trust UpliftGames/wally` first (aftman refuses untrusted sources), then `aftman install`
  - [ ] Confirm all four binaries resolve under `~/.aftman/bin`
- [ ] Create the directory skeleton (AC: 2)
  - [ ] `src/shared/Config/`, `src/server/Services/`, `src/client/Controllers/`, `tests/`
  - [ ] Note: empty dirs are invisible to Rojo builds (only on-disk) — that is expected; do NOT add placeholder `.luau` files just to make folders appear
- [ ] Verify build (AC: 1)
  - [ ] `PATH="$HOME/.aftman/bin:$PATH" rojo build default.project.json -o "secure-data-and-inventory-system.rbxlx"`
  - [ ] Open the built `.rbxlx` in Roblox Studio and confirm it starts (Baseplate + hello-world output)
- [ ] Verify lint/format gates (AC: 1, 4)
  - [ ] `PATH="$HOME/.aftman/bin:$PATH" stylua --check src/` → zero findings
  - [ ] `PATH="$HOME/.aftman/bin:$PATH" selene src/` → zero findings
  - [ ] If either flags existing scaffold code, fix minimally (this story owns a clean baseline)
- [ ] Do NOT touch these — owned by later stories (scope guard)
  - [ ] `wally.toml` / `wally.lock` / ProfileStore → Story 1.2
  - [ ] `tests/*.spec.luau` content and TestEZ runner → Story 1.2
  - [ ] Deleting `src/shared/Hello.luau` → when services land (architecture note), not here

## Dev Notes

**Architecture patterns and constraints**

- Organization: *layer-first, domain within*. The `server / shared / client` split IS the security boundary from `AGENTS.md` — the path alone shows whether code may touch data [Source: game-architecture.md#Organization Pattern].
- Architectural boundaries that apply from this story onward:
  1. Path is permission — `src/server/` may touch DataStores; `src/client/` never; `src/shared/` must never `require` server/client.
  2. Only `DataService` reads/writes `Profile.Data`. 3. Only `RemoteService` registers remote handlers. 4. Config tables are read-only. 5. Client never computes authoritative state. 6. No cross-layer `require` except client/server → shared [Source: game-architecture.md#Architectural Boundaries].
- Rojo map `default.project.json` is the source of truth for instance paths — do not hand-edit `*.rbxlx`; change `src/` and rebuild [Source: AGENTS.md].
- Entry points stay at `src/server/init.server.luau` (Init() pass then Start() pass) and `src/client/init.client.luau` (controllers started in order) [Source: game-architecture.md#Directory Structure].

**Naming conventions** (enforced by review later; stylua won't catch these)

- Modules PascalCase matching primary export (`VaultService.luau`); entry points `init.server.luau`/`init.client.luau`; specs `<Module>.spec.luau`.
- Functions/locals camelCase; constants UPPER_SNAKE; error codes UPPER_SNAKE strings; config keys camelCase; game assets snake_case [Source: game-architecture.md#Naming Conventions].

**Source tree components to touch**

- Modify: `aftman.toml` (add wally).
- Create (dirs only): `src/shared/Config/`, `src/server/Services/`, `src/client/Controllers/`, `tests/`.
- Verify-only: `default.project.json`, `stylua.toml`, `selene.toml`, `src/*/init.*`, `src/shared/Hello.luau`.
- Reference: `tests/project.json` (test-only Rojo map) is listed in the architecture tree but belongs with the TestEZ story — skip it here.

**Testing standards summary**

- TestEZ `0.4.2` for pure server logic; specs live in `tests/`, NOT in the production place. No tests are written in this story — it only guarantees the gates (`stylua`, `selene`) pass [Source: game-architecture.md#Testing Strategy; epics.md Story 1.2].

**Known environment gotchas**

- Toolchain is NOT on PATH: every invocation needs `PATH="$HOME/.aftman/bin:$PATH"` prefix [Source: AGENTS.md].
- Indentation is Tabs — run stylua, never hand-format [Source: AGENTS.md; stylua.toml].
- Windows/bash environment: use forward slashes in paths; quote paths with spaces.

### Project Structure Notes

- Target layout matches the architecture tree exactly: `src/shared/{Config/,Types.luau,...}`, `src/server/Services/`, `src/client/Controllers/` — this story creates the container folders only; module files arrive with their owning stories (no speculative files).
- Current state: `src/` contains only `client/init.client.luau`, `server/init.server.luau`, `shared/Hello.luau`. No conflicts or variances detected between the scaffold and the target structure.

### Project Context Rules

No `project-context.md` exists; `AGENTS.md` is the equivalent authority. Rules for this story:

- All DataStore access server-side only; client never reads/writes player data [Source: AGENTS.md#Policy].
- Never hand-edit `*.rbxlx` (gitignored build output) — change `src/` and rebuild [Source: AGENTS.md#Policy].
- `rojo`/`aftman`/`stylua`/`selene` live in `~/.aftman/bin`, not on PATH — prefix every command [Source: AGENTS.md#Running and verifying].
- Verify with: `stylua --check src/` and `selene src/` — both must pass before review [Source: AGENTS.md#Running and verifying].
- Requires are Roblox instance-based (`require(script.Parent.X)`); there is deliberately no `.luaurc` [Source: AGENTS.md#Conventions].

### References

- [Source: skills/planning-artifacts/game-architecture.md#Project Structure] — full directory tree and system location mapping.
- [Source: skills/planning-artifacts/game-architecture.md#Development Environment] — prerequisites, setup commands, first steps.
- [Source: skills/planning-artifacts/epics.md#Story 1.1] — canonical acceptance criteria.
- [Source: AGENTS.md] — policy, PATH caveat, build/verify commands, conventions.
- [Source: skills/planning-artifacts/implementation-readiness-report-2026-09-28.md] — readiness READY; story flagged "keep Story 1.4 lean" (not this story) — no other constraints.

## Dev Agent Record

### Agent Model Used

opencode/mimo-v2.6-flash-free (story creation; dev agent will fill in its own model here)

### Debug Log References

### Completion Notes List

### File List
