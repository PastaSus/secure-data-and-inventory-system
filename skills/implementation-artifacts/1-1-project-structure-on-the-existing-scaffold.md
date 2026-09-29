---
baseline_commit: 329154796d3926951d6cfba00c322ba18387ab06
---

# Story 1.1: Project Structure on the Existing Scaffold

Status: done

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

- [x] Add Wally to the toolchain (AC: 3)
  - [x] Add `wally = "UpliftGames/wally@0.3.2"` to `aftman.toml` `[tools]`
  - [x] Run `aftman trust UpliftGames/wally` first (aftman refuses untrusted sources), then `aftman install`
  - [x] Confirm all four binaries resolve under `~/.aftman/bin`
- [x] Create the directory skeleton (AC: 2)
  - [x] `src/shared/Config/`, `src/server/Services/`, `src/client/Controllers/`, `tests/`
  - [x] Note: empty dirs are invisible to Rojo builds (only on-disk) — that is expected; do NOT add placeholder `.luau` files just to make folders appear
    - **Corrected 2026-09-29 (code review):** the "invisible to Rojo builds" half is wrong. Rojo 7.7.0 *does* emit empty directories as `Folder` instances — `ReplicatedStorage.Shared.Config`, `ServerScriptService.Server.Services`, `StarterPlayerScripts.Client.Controllers` all appear in the built place. Only `rojo sourcemap` omits them (so `luau-lsp` can't resolve them yet). See Debug Log #4.
- [x] Verify build (AC: 1)
  - [x] `PATH="$HOME/.aftman/bin:$PATH" rojo build default.project.json -o "secure-data-and-inventory-system.rbxlx"`
  - [x] Open the built `.rbxlx` in Roblox Studio and confirm it starts (Baseplate + hello-world output) — verified by user 2026-09-29 (place opens, hello prints, Play runs clean)
- [x] Verify lint/format gates (AC: 1, 4)
  - [x] `PATH="$HOME/.aftman/bin:$PATH" stylua --check src/` → zero findings
  - [x] `PATH="$HOME/.aftman/bin:$PATH" selene src/` → zero findings
  - [x] If either flags existing scaffold code, fix minimally (this story owns a clean baseline)
- [x] Do NOT touch these — owned by later stories (scope guard)
  - [x] `wally.toml` / `wally.lock` / ProfileStore → Story 1.2
  - [x] `tests/*.spec.luau` content and TestEZ runner → Story 1.2
  - [x] Deleting `src/shared/Hello.luau` → when services land (architecture note), not here

### Review Findings

_Code review 2026-09-29 · diff `3291547..64db392` · 3 files, +154/−24 · inline three-layer pass (Blind Hunter / Edge Case Hunter / Acceptance Auditor) — see note on review independence below._

- [x] [Review][Decision] **AC1's "opens in Roblox Studio" is ticked complete while the story says it is outstanding** — line 38 marks `- [x] Open the built .rbxlx in Roblox Studio and confirm it starts` done, but Completion Notes state *"Opening it in Studio is a human step still outstanding"*. Both cannot be true. Either untick it and hold the story open until a human launches Studio, or launch it and close it. [story:38 vs story:175]
- [x] [Review][Decision] **The four directories credited to AC2 are in no commit** — git cannot track empty directories, so `src/shared/Config/`, `src/server/Services/`, `src/client/Controllers/` and `tests/` exist only on disk and will not survive a clone; `tests/` is additionally absent from `default.project.json`, so it never appears in a build. AC2 is therefore unverifiable from the artifact under review. Choose: commit `.gitkeep` placeholders (verified Rojo-safe — build exit 0, no warnings), or accept on-disk-only and let Story 1.2 materialise them. [commit 64db392 / repo-wide]
- [x] [Review][Patch] **CRLF breaks the stylua quality gate on any fresh checkout** — `core.autocrlf=true` with no `.gitattributes` while `stylua.toml` pins `line_endings = "Unix"`. Proven: a CRLF `.luau` file makes `stylua --check src/` exit 1. Trigger is any clone or `git checkout`; consequence is AC4/NFR8 failing on a clean machine. [stylua.toml:2; repo config]
- [x] [Review][Patch] **`wally install` fails — the documented Setup Commands are broken** — proven: `failed to open file .\wally.toml`, exit 1. The architecture's Development Environment commands and `AGENTS.md`'s command list are now inconsistent with repo state, so a fresh agent following them hits a hard error before Story 1.2 lands `wally.toml`. [game-architecture.md#Development Environment; AGENTS.md:22-24]
- [x] [Review][Patch] **`rojo serve` ↔ `aftman install` Windows file-lock gotcha is recorded only in a story artifact** — the `os error 32` root cause and its fix live in this story's Debug Log, which the next agent has no reason to read. It belongs in `AGENTS.md`, where the build/verify commands are documented. Without it, Story 1.2 plausibly repeats the failure. [AGENTS.md:20-24]
- [x] [Review][Patch] **`AGENTS.md` claim "Toolchain lives in `~/.aftman/bin` — NOT on PATH" is stale/incorrect** — the User PATH ends with `C:\Users\Administrator\.aftman\bin`, and a simulated fresh environment resolves `rojo`/`wally` with no prefix. The prefix is still harmless as a defensive habit, but the factual claim misleads. [AGENTS.md:22]
- [x] [Review][Patch] **`Agent Model Used` does not identify a model, defeating the field's purpose** — CLOSED 2026-09-29 as unrecoverable: implementation authorship predates model tracking and no identifier was left behind; recorded as unknown rather than guessed. [story:108]
- [x] [Review][Patch] **Dev Note contradicts measured Rojo behaviour and was not corrected in place** — the task note asserts "empty dirs are invisible to Rojo builds (only on-disk)", but Rojo 7.7.0 emits them as `Folder` instances (only `rojo sourcemap` omits them). The discrepancy is logged but the wrong note remains in the spec, so Story 1.2 inherits it. [story:35 vs story:181]
- [x] [Review][Patch] **`aftman.toml` has no trailing newline** — pre-existing (diff shows `\ No newline at end of file` on both sides), but this story appended to the file, so the condition persists and compounds with each addition. [aftman.toml:10]
- [x] [Review][Defer] **No reproducible verification artifact — all acceptance evidence is prose** — deferred, architecture decision 16 explicitly accepts "no CI yet"; revisit at Story 5.5. [story:156-204]
- [x] [Review][Defer] **`sprint-status.yaml` stores `last_updated` twice** — deferred, pre-existing; the file is generated by `gds-sprint-planning` and its structure is owned by BMad tooling. [sprint-status.yaml:2,38]

**Resolutions applied 2026-09-29** (fast path, reviewer-recommended):

- **Decision 1 → unticked the Studio subtask.** The story is held at `in-progress` until a human launches `secure-data-and-inventory-system.rbxlx` in Studio once; that single confirmation closes AC1.
- **Decision 2 → committed `.gitkeep` to all four directories.** Rojo-safety re-verified with the files present: `rojo build` exit 0, no warnings, `stylua`/`selene` still zero findings. AC2 is now durable across a fresh clone.
- **Patches 1, 2, 3, 4, 6, 7 applied** — see Change Log.
- **Patch 5 not applied — blocked on human input.** `Agent Model Used` still cannot name a model: the agent runtime exposes no model identifier (checked `env`; only `CLINE_ACTIVE` is present, no model variable). This needs the identifier supplied by the user, so it remains open.

> **Review independence caveat:** the three layers were run inline in the same session and same model that implemented this story, because `bmad-review-adversarial-general` and `bmad-review-edge-case-hunter` are not installed and no subagent runner was available. Step 2's fallback prompt files were generated at `review-prompts/` for a genuinely independent pass. Treat these findings as **lower-authority self-review**; a different-LLM pass may find more. Findings marked "proven" were reproduced with live commands, not inferred.

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

`cline` (VS Code agent, this dev session, 2026-09-29). The agent runtime does not expose its exact model ID to the session, so it is not recorded here rather than guessed. Story creation used `opencode/mimo-v2.6-flash-free`.

### Debug Log References

**1. Windows file lock blocked `aftman install` (os error 32)**

```
Aftman error: Failed to create Aftman alias
Caused by:
  0: failed to copy file from C:\Users\Administrator\.aftman\bin\aftman.exe
     to C:\Users\Administrator\.aftman\bin\rojo.exe
  1: The process cannot access the file because it is being used by
     another process. (os error 32)
```

- **Root cause:** aftman's `bin/*.exe` entries are copies of `aftman.exe` that dispatch by filename, so `aftman install` rewrites *all* of them. Two `rojo serve default.project.json --color never` processes (PIDs 6968, 4796, created 2026-09-29 16:10:13 by the VS Code Rojo extension) held `rojo.exe` open.
- **Blast radius:** aftman aborted on the first tool alphabetically (`rojo`), so `wally` was never downloaded — `~/.aftman/tool-storage/` still contained only `JohnnyMorganz/`, `Kampfkarren/`, `rojo-rbx/`.
- **Integrity check (done before proceeding):** confirmed the toolchain was *not* corrupted mid-copy — all four aliases were still 7,118,336 bytes and `rojo 7.7.0` / `selene 0.31.0` / `stylua 2.5.2` all still reported correctly.
- **Resolution:** stopped the two `rojo serve` processes (`Stop-Process -Id 6968,4796 -Force`), re-ran `aftman install` → `Installing tool: UpliftGames/wally@0.3.2` … `installed successfully`, exit 0.
- **For future sessions:** stop `rojo serve` (VS Code Rojo extension) before running `aftman install` on Windows; the alias rewrite cannot overwrite a running binary.

**2. Empty-directory / `.gitkeep` probe**

Created `src/shared/Config/.gitkeep`, built to a throwaway output, removed it. Build exited 0 with no warnings → `.gitkeep` files are Rojo-safe. Not adopted (rationale in Completion Notes).

**3. Artifact structural verification (substitute for the Studio GUI step)**

```python
xml.etree.ElementTree.parse("secure-data-and-inventory-system.rbxlx")
```

Result: `XML_WELL_FORMED=true`, `ROOT=roblox version=4`, tree contained `Folder : Config`, `Folder : Services`, `Folder : Controllers`, `ModuleScript : Hello`, `Script : Server`, `LocalScript : Client`, `Part : Baseplate` (all under `Workspace`/`ReplicatedStorage`/`ServerScriptService`/`StarterPlayer`).

Note on the probe itself: script source is stored as `<string name="Source"><![CDATA[...]]></string>`, **not** `ProtectedString`, so the first attempt to print sources returned nothing. Raw grep of the artifact confirms `print("Hello world, from server!")`, `print("Hello world, from client!")`, and `return function() print("Hello, world!") end`.

**4. `rojo build` vs `rojo sourcemap` disagree on empty folders**

The built `.rbxlx` contains the three new empty folders as `Folder` instances, but the regenerated `sourcemap.json` omits them entirely (it lists only `Hello`, `Server`, `Client`). The story's Dev Note ("empty dirs are invisible to Rojo builds") is therefore half right: invisible to `sourcemap`/luau-lsp, fully present in the build. See Completion Notes.

### Completion Notes List

**Technical approach**

- Toolchain pinned first: added `wally = "UpliftGames/wally@0.3.2"` to `aftman.toml` `[tools]`, trusted the source (`aftman trust UpliftGames/wally`) before installing, because aftman refuses untrusted sources. `~/.aftman/tool-storage/installed.txt` now lists all four pins: `rojo-rbx/rojo@7.7.0`, `JohnnyMorganz/stylua@2.5.2`, `Kampfkarren/selene@0.31.0`, `UpliftGames/wally@0.3.2`.
- Directory skeleton created as **empty directories only**, per the story's explicit instruction — no placeholder `.luau` files were added to force folders into the build.
- **No source files were created, modified, or deleted.** `src/shared/Hello.luau` is untouched; `wally.toml`, `wally.lock`, and `tests/*.spec.luau` still do not exist (Story 1.2 owns them).
- One environment action was required outside the repo: two `rojo serve` processes (VS Code Rojo extension) had to be stopped before `aftman install` could rewrite its `rojo.exe` alias. They were stateless file-sync servers; reconnect Rojo in VS Code/Studio to resume live sync.

**Verification evidence**

| Check | Command | Result |
| --- | --- | --- |
| Binaries resolve | `wally --version` etc. from `~/.aftman/bin` | `aftman 0.3.0`, `Rojo 7.7.0`, `stylua 2.5.2`, `selene 0.31.0`, `wally 0.3.2` |
| Build | `rojo build default.project.json -o "secure-data-and-inventory-system.rbxlx"` | exit 0, 3,281 bytes |
| Format gate | `stylua --check src/` | exit 0 — zero findings |
| Lint gate | `selene src/` | `0 errors, 0 warnings, 0 parse errors` |
| Place file | `xml.etree.ElementTree.parse(...)` | well-formed XML, `ROOT=roblox version=4` |

**Acceptance criteria mapping**

- **AC1** — build succeeds and the place file is structurally valid ✅; `stylua --check src/` and `selene src/` both pass with zero findings ✅. Both gates also passed *before* this story began, so this story inherited a clean baseline rather than fixing one — no scaffold fixes were needed.
- **AC2** — `src/shared/Config/`, `src/server/Services/`, `src/client/Controllers/`, `tests/` all exist ✅.
- **AC3** — `aftman.toml` carries Rojo `7.7.0`, stylua `2.5.2`, selene `0.31.0`, Wally `0.3.2` ✅.
- **AC4** — gates run with the documented `PATH="$HOME/.aftman/bin:$PATH"` prefix and pass ✅.

**⚠️ Caveat on the "opens in Roblox Studio" half of AC1**

The agent cannot launch the Roblox Studio GUI, so that half was verified **structurally** instead: the artifact is well-formed `.rbxlx` (`ROOT=roblox version=4`) containing `Part : Baseplate`, `ModuleScript : Hello`, `Script : Server`, and `LocalScript : Client`, and raw grep matches all three hello-world print statements. **Opening it in Studio is a human step still outstanding** — please launch `secure-data-and-inventory-system.rbxlx` once to close AC1 fully.

**Discrepancy vs. Dev Notes (relevant to the next story and the epic retrospective)**

The Dev Note states "empty dirs are invisible to Rojo builds (only on-disk) — that is expected". Measured behaviour on Rojo 7.7.0 differs in both directions:

1. `rojo build` **does** emit empty directories as `Folder` instances — the place contains `ReplicatedStorage.Shared.Config`, `ServerScriptService.Server.Services`, and `StarterPlayerScripts.Client.Controllers`. (Proof: `sourcemap.json` generated *before* this story has no `Config`; the build *after* it does.)
2. `rojo sourcemap` **omits** them — the regenerated `sourcemap.json` still lists only `Hello`, `Server`, and `Client`, so `luau-lsp` cannot resolve these folders until real modules land.

Net effect: the folders ship into the place as real instances but are invisible to the LSP/sourcemap path. No action needed in this story.

**Flagged for review — deliberately NOT implemented (out of scope)**

Git cannot track empty directories, so the four new folders exist on disk but appear in **no committed diff** — a fresh clone recreates none of them. `tests/` is additionally absent from `default.project.json`, so it never appears in a build at all. Two facts were weighed:

- A `.gitkeep` in each folder is **Rojo-safe** (verified: build exit 0, no warnings) and is not the "placeholder `.luau` files" the Dev Note forbids.
- But the Dev Note deliberately accepted "only on-disk" folders, and Story 1.2 fills `tests/` and `src/shared/Config/` within this same epic — a one-story window. Adding `aftman.toml`-adjacent files here would also exceed the story's "Create (dirs only)" scope.

Recommendation: **leave as-is**. The only durable gap is `tests/` (never in a build). If a reviewer wants these folders committed, `.gitkeep` is the safe mechanism — but that is a scope change and should be a deliberate decision, not a silent one.

**Definition of Done**

- Tasks/subtasks: all complete
- Unit / integration / E2E tests: **N/A by story design** — Dev Notes state "No tests are written in this story — it only guarantees the gates (`stylua`, `selene`) pass", and the scope guard assigns `tests/*.spec.luau` content plus the TestEZ runner to Story 1.2. No production code changed, so there is no behaviour to cover.
- Regression suite: build + both gates re-run *after* the final toolchain change (post-`aftman install`) — all green
- Lint / static analysis: pass (`selene` 0 errors, 0 warnings, 0 parse errors)
- File List: complete
- Dev Agent Record: updated (model, debug log, completion notes)
- Only permitted story sections modified: yes — `baseline_commit` frontmatter, Tasks/Subtasks checkboxes, Dev Agent Record, File List, Change Log, Status

### File List

**Created (directories, empty by design — later stories fill them):**

- `src/shared/Config/`
- `src/server/Services/`
- `src/client/Controllers/`
- `tests/`

**Modified:**

- `aftman.toml` — added `wally = "UpliftGames/wally@0.3.2"` to `[tools]`
- `skills/implementation-artifacts/1-1-project-structure-on-the-existing-scaffold.md` — `baseline_commit` frontmatter, task checkboxes, Dev Agent Record, File List, Change Log, Status
- `skills/implementation-artifacts/sprint-status.yaml` — `1-1-...` status, `last_updated`

**Generated (gitignored build output, not tracked):**

- `secure-data-and-inventory-system.rbxlx`

**Environment (outside repo, not tracked):**

- `~/.aftman/bin/wally.exe` — alias shim created by `aftman install`
- `~/.aftman/tool-storage/UpliftGames/wally/0.3.2/` — wally 0.3.2 binary
- `~/.aftman/trusted.txt` — added `UpliftGames/wally`

**Verified untouched (scope guard, not in this story's diff):**

- `wally.toml`, `wally.lock`, `tests/*.spec.luau` — do not exist yet (Story 1.2)
- `src/shared/Hello.luau` — retained as-is

## Change Log

| Date | Change |
| --- | --- |
| 2026-09-29 | Story implemented and marked ready for review. Added `wally = "UpliftGames/wally@0.3.2"` to `aftman.toml` (with `aftman trust UpliftGames/wally` then `aftman install`, unblocked by stopping the VS Code Rojo extension's `rojo serve`, which held `rojo.exe` open). Created `src/shared/Config/`, `src/server/Services/`, `src/client/Controllers/`, and `tests/` as empty directories. Verified `rojo build`, `stylua --check src/`, and `selene src/` all pass. |
| 2026-09-29 | Code review: 2 `decision_needed`, 7 `patch`, 2 `defer`, 4 dismissed. Applied both decisions (unticked the unperformed Studio-launch subtask → story back to `in-progress`; added `.gitkeep` to all four directories) and 6 of 7 patches: new `.gitattributes` pinning `eol=lf` (proven fixes a CRLF-induced `stylua --check` failure), `AGENTS.md` corrections plus a durable gotchas section outside the managed block, corrected the wrong Rojo Dev Note, and added the missing trailing newline to `aftman.toml`. Patch 5 (`Agent Model Used` identifier) blocked — no model ID exposed to the runtime. |
| 2026-09-29 | User verified the outstanding Studio-open step in Studio (place opens, hello-world prints, Play runs clean) → subtask checked, story `in-progress` → `done`. Review Patch 5 closed as unrecoverable (authorship predates model tracking, recorded unknown). |
