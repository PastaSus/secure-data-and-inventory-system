--!strict
-- DataService.luau — the ONLY module allowed to touch Profile.Data.
-- Story 1.2 scope: session-lock acquisition + migration, nothing else.
-- NO kick, NO snapshot push, NO PlayerAdded wiring, NO EndSession —
-- Story 1.3 owns the join gate. A handlerless DataService nobody calls
-- yet is CORRECT at the end of this story.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schema = require(ReplicatedStorage.Shared.Schema)
local ProfileStore = require(script.Parent.Parent.ServerPackages.ProfileStore)

local STORE_NAME = "PlayerStore"
local KEY_PREFIX = "Player_"

local PlayerStore = ProfileStore.New(STORE_NAME, Schema.defaultProfile())

local DataService = {}

local _profiles: { [number]: any } = {}

function DataService.profileKey(userId: number): string
	return KEY_PREFIX .. tostring(userId)
end

-- Obtains the ProfileStore session lock for a joining player, then runs
-- the forward-only migration so the data Story 1.3 snapshots is already
-- migrated. Returns true on lock+migrate success, false on ANY failure.
-- Never yields past the ProfileStore boundary; never touches DataStoreService.
function DataService.startSession(player: Player): boolean
	local key = DataService.profileKey(player.UserId)

	local ok, profile = pcall(function()
		return PlayerStore:StartSessionAsync(key, {
			Cancel = function(): boolean
				return player.Parent ~= Players
			end,
		})
	end)

	if not ok or profile == nil then
		return false
	end

	if type(profile.Data) ~= "table" then
		return false
	end

	local migrateOk = pcall(function()
		Schema.migrate(profile.Data)
	end)
	if not migrateOk then
		return false
	end

	_profiles[player.UserId] = profile
	return true
end

return DataService
