--!strict
-- init.server.luau — server entry point. Synchronous Init() pass, then a
-- task.spawn'd Start() pass (architecture decision 2); every later service
-- story hooks into these two passes.
-- Story 1.3 owns the join gate: CharacterAutoLoads stays off until a player
-- passes the gate (no gameplay before the lock), the gate snapshots and
-- releases via DataService, and PlayerAdded / PlayerRemoving drive
-- DataService.startSession / endSession. No Studio special-casing.
-- Story 1.4 owns the remote surface: RemoteService creates the Remotes
-- folder + server→client channels in Init(), the single bootstrap request
-- (RequestSnapshot) is registered here next to the gate push it serves,
-- and the gate pushes snapshots through RemoteService. Rejections are
-- silent to the client and logged server-side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local Validate = require(ReplicatedStorage.Shared.Validate)
local DataService = require(script.Services.DataService)
local RemoteService = require(script.Services.RemoteService)

local REQUEST_SNAPSHOT_NAME = "RequestSnapshot"
local KICK_MESSAGE = "Could not load your data. Please rejoin."
-- Slack past joinLoadTimeout before the backstop kicks: Cancel aborts the
-- load at the deadline but ProfileStore only honors it at poll points, so
-- the gate guarantees a kick no later than timeout + slack.
local BACKSTOP_SLACK_SECONDS = 5

-- UserIds already gated (or gating). PlayerAdded is connected BEFORE the
-- existing-players loop, so a join landing in between would otherwise run
-- the gate twice — and the loser would kick a legitimate in-game player
-- via the double-start guard. Cleared on PlayerRemoving so rejoins gate
-- fresh.
local gated: { [number]: boolean } = {}

local function init(): ()
	Players.CharacterAutoLoads = false
	RemoteService.init()

	-- The pipeline's own bootstrap request: answers a client that missed
	-- the gate push with a fresh snapshot. Registered here (not inside
	-- RemoteService) because it owns snapshot semantics alongside the
	-- gate. No payload by design — any argument is forged traffic.
	RemoteService.register(REQUEST_SNAPSHOT_NAME, function(player: Player, ...: any): Types.ErrorCode?
		local err = Validate.noArgs(...)
		if err ~= nil then
			return err
		end
		local snapshot = DataService.getSnapshot(player)
		if snapshot == nil then
			-- Gate check already passed above us, so this is unreachable
			-- without a race — fail closed anyway, never push defaults.
			return "NO_ACTIVE_PROFILE"
		end
		RemoteService.pushSnapshot(player, snapshot)
		return nil
	end)
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
		local snapshot = DataService.getSnapshot(player)
		if snapshot ~= nil then
			RemoteService.pushSnapshot(player, snapshot)
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
		RemoteService.releasePlayer(leaving)
		DataService.endSession(leaving)
	end)
end

init()
task.spawn(start)
