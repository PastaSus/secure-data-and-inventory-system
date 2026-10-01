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

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local DataService = require(script.Services.DataService)

local REMOTES_FOLDER_NAME = "Remotes"
local SNAPSHOT_EVENT_NAME = "Snapshot"
local KICK_MESSAGE = "Could not load your data. Please rejoin."
-- Slack past joinLoadTimeout before the backstop kicks: Cancel aborts the
-- load at the deadline but ProfileStore only honors it at poll points, so
-- the gate guarantees a kick no later than timeout + slack.
local BACKSTOP_SLACK_SECONDS = 5

local snapshotEvent: RemoteEvent?

-- UserIds already gated (or gating). PlayerAdded is connected BEFORE the
-- existing-players loop, so a join landing in between would otherwise run
-- the gate twice — and the loser would kick a legitimate in-game player
-- via the double-start guard. Cleared on PlayerRemoving so rejoins gate
-- fresh.
local gated: { [number]: boolean } = {}

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

-- Restores the engine's default respawn that CharacterAutoLoads = false
-- disables: after death, wait out RespawnTime and reload the character.
-- Wired per gate-passed player only (failed gates are kicked, never linger).
local function watchCharacter(player: Player, character: Model): ()
	-- A character without a Humanoid cannot die, so there is nothing to
	-- restore when the wait times out.
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.Died:Connect(function()
		task.wait(Players.RespawnTime)
		if player.Parent == Players then
			player:LoadCharacter()
		end
	end)
end

local function gatePlayer(player: Player): ()
	if gated[player.UserId] then
		return
	end
	gated[player.UserId] = true

	local finished = false
	task.delay(GameConfig.joinLoadTimeout + BACKSTOP_SLACK_SECONDS, function()
		if not finished and player.Parent == Players then
			player:Kick(KICK_MESSAGE)
		end
	end)

	if DataService.startSession(player) then
		local event = snapshotEvent
		local snapshot = DataService.getSnapshot(player)
		if event ~= nil and snapshot ~= nil then
			event:FireClient(player, snapshot)
			player.CharacterAdded:Connect(function(character: Model)
				watchCharacter(player, character)
			end)
			if player.Parent == Players then
				player:LoadCharacter()
			end
		elseif player.Parent == Players then
			-- Gate passed but the data vanished (no snapshot): fail closed.
			player:Kick(KICK_MESSAGE)
		end
	elseif player.Parent == Players then
		player:Kick(KICK_MESSAGE)
	end
	finished = true
end

local function start(): ()
	Players.PlayerAdded:Connect(gatePlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(gatePlayer, player)
	end
	Players.PlayerRemoving:Connect(function(leaving: Player)
		gated[leaving.UserId] = nil
		DataService.endSession(leaving)
	end)
end

init()
task.spawn(start)
