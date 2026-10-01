--!strict
-- DataService.luau — the ONLY module allowed to touch Profile.Data.
-- Story 1.3 scope: session-lock acquisition + migration (1.2), plus the
-- join-gate half owned by this story: store-init containment, a bounded
-- load (join timeout via Cancel deadline), session release on leave,
-- double-start refusal, snapshot reads for the wire, and structured Log
-- output on every path. The gate WIRING (kick, release, snapshot push)
-- lives in init.server.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Log = require(ReplicatedStorage.Shared.Log)
local Schema = require(ReplicatedStorage.Shared.Schema)
local Types = require(ReplicatedStorage.Shared.Types)
local ProfileStore = require(script.Parent.Parent.ServerPackages.ProfileStore)

local STORE_NAME = "PlayerStore"
local KEY_PREFIX = "Player_"

-- Store creation runs inside a pcall so a throwing constructor degrades to
-- "every join fails closed" instead of crashing every requirer.
local storeOk, storeOrErr = pcall(function()
	return ProfileStore.New(STORE_NAME, Schema.defaultProfile())
end)
local PlayerStore = if storeOk then storeOrErr else nil
if not storeOk then
	Log.error("DataService", "store init failed", { err = tostring(storeOrErr) })
end

local DataService = {}

local _profiles: { [number]: any } = {}

-- Releases a live profile without touching the registry. Wrapped in pcall:
-- Decision 14 requires containment at every DataStore-adjacent boundary,
-- and the save `EndSession` triggers runs DataStore I/O.
local function releaseLive(profile: any): ()
	pcall(function()
		profile:EndSession()
	end)
end

function DataService.profileKey(userId: number): string
	return KEY_PREFIX .. tostring(userId)
end

-- Registry-only check for the RemoteService pipeline gate: does this
-- server hold a live session for the player? No copy, no yields. Callers
-- treat false as "gate closed", never as "serve defaults". Added by
-- Story 1.4; startSession/endSession/getSnapshot contracts unchanged.
function DataService.hasSession(player: Player): boolean
	return _profiles[player.UserId] ~= nil
end

-- Obtains the ProfileStore session lock for a joining player, then runs
-- the forward-only migration so the data the gate snapshots is already
-- migrated. Returns true on lock+migrate success, false on ANY failure.
-- Never yields past the ProfileStore boundary; never touches DataStoreService.
-- The load is bounded: Cancel aborts past GameConfig.joinLoadTimeout (the
-- vendored ProfileStore polls cancel_condition in its retry loop and
-- returns nil on cancel), so a hung DataStore call fails closed.
function DataService.startSession(player: Player): boolean
	if PlayerStore == nil then
		Log.error("DataService", "session start failed", { player = player.UserId, reason = "store_init_failed" })
		return false
	end
	if _profiles[player.UserId] ~= nil then
		Log.warn("DataService", "session start refused", { player = player.UserId, reason = "double_start" })
		return false
	end

	local key = DataService.profileKey(player.UserId)
	local deadline = os.clock() + GameConfig.joinLoadTimeout

	local ok, profile = pcall(function()
		return PlayerStore:StartSessionAsync(key, {
			Cancel = function(): boolean
				return player.Parent ~= Players or os.clock() >= deadline
			end,
		})
	end)

	if not ok or profile == nil then
		local reason = "lock_failed"
		if player.Parent ~= Players then
			reason = "player_left"
		elseif os.clock() >= deadline then
			reason = "timeout"
		end
		Log.error("DataService", "session start failed", { player = player.UserId, reason = reason })
		return false
	end

	if type(profile.Data) ~= "table" then
		-- The lock is already held here but the profile is unusable and
		-- will never be registered: release it so the kicked player's
		-- rejoin does not hit a lock conflict.
		releaseLive(profile)
		Log.error("DataService", "session start failed", { player = player.UserId, reason = "bad_data" })
		return false
	end

	local migrateOk = pcall(function()
		Schema.migrate(profile.Data)
	end)
	if not migrateOk then
		-- Same leak as above: migrate threw (possibly after partial
		-- in-place mutation — harmless, the next join re-migrates
		-- idempotently), so release before failing closed.
		releaseLive(profile)
		Log.error("DataService", "session start failed", { player = player.UserId, reason = "migrate_failed" })
		return false
	end

	_profiles[player.UserId] = profile
	Log.info("DataService", "session opened", { player = player.UserId })
	return true
end

-- Releases the session lock and forgets the profile. Profile:EndSession
-- self-guards on IsActive, so calling it on a stale entry is safe.
-- Wired to PlayerRemoving by init.server.luau.
function DataService.endSession(player: Player): ()
	local profile = _profiles[player.UserId]
	_profiles[player.UserId] = nil
	if profile ~= nil then
		releaseLive(profile)
	end
end

-- Reads the held profile for the wire as a plain deep copy. Returns nil
-- when the player holds no profile — callers must treat nil as "gate
-- closed", never as "send defaults".
function DataService.getSnapshot(player: Player): Types.ProfileData?
	local profile = _profiles[player.UserId]
	if profile == nil then
		return nil
	end
	return Schema.snapshot(profile.Data)
end

return DataService
