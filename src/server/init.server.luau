--!strict
-- init.server.luau — server entry point. Synchronous Init() pass, then a
-- task.spawn'd Start() pass (architecture decision 2); every later service
-- story hooks into these two passes.
-- Story 1.3 owns the join gate: CharacterAutoLoads stays off until a player
-- passes the gate (no gameplay before the lock), the Snapshot remote is
-- bootstrapped at runtime, and PlayerAdded / PlayerRemoving drive
-- DataService.startSession / endSession. No Studio special-casing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Services.DataService)

local REMOTES_FOLDER_NAME = "Remotes"
local SNAPSHOT_EVENT_NAME = "Snapshot"
local KICK_MESSAGE = "Could not load your data. Please rejoin."

local snapshotEvent: RemoteEvent?

local function init(): ()
	Players.CharacterAutoLoads = false

	local remotes = Instance.new("Folder")
	remotes.Name = REMOTES_FOLDER_NAME
	remotes.Parent = ReplicatedStorage

	local event = Instance.new("RemoteEvent")
	event.Name = SNAPSHOT_EVENT_NAME
	event.Parent = remotes
	snapshotEvent = event
end

local function gatePlayer(player: Player): ()
	if DataService.startSession(player) then
		local event = snapshotEvent
		local snapshot = DataService.getSnapshot(player)
		if event ~= nil and snapshot ~= nil then
			event:FireClient(player, snapshot)
		end
		if player.Parent == Players then
			player:LoadCharacter()
		end
	elseif player.Parent == Players then
		player:Kick(KICK_MESSAGE)
	end
end

local function start(): ()
	Players.PlayerAdded:Connect(gatePlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(gatePlayer, player)
	end
	Players.PlayerRemoving:Connect(function(leaving: Player)
		DataService.endSession(leaving)
	end)
end

init()
task.spawn(start)
