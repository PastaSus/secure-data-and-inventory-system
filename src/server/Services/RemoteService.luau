--!strict
-- RemoteService.luau — the ONLY module that registers remote handlers.
-- Every client→server request flows through one pipeline: per-player
-- per-remote rate-limit check → active-profile gate check →
-- pcall(validate + apply). Handlers return nil (accepted) or an ErrorCode
-- (rejected); rejections are logged with a reason and never answered to
-- the client — an exploiter gets no signal. Unexpected faults log as
-- errors and reach the player only as a generic Notify message.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Log = require(ReplicatedStorage.Shared.Log)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)
local Types = require(ReplicatedStorage.Shared.Types)
local DataService = require(script.Parent.DataService)

local REMOTES_FOLDER_NAME = "Remotes"
local SNAPSHOT_EVENT_NAME = "Snapshot"
local NOTIFY_EVENT_NAME = "Notify"

local RemoteService = {}

-- Module-scope budget built once from the frozen GameConfig (not per
-- request): the default bucket for every client remote.
local RATE_BUDGET: RateLimit.Budget = {
	capacity = GameConfig.remoteRateCapacity,
	refillPerSecond = GameConfig.remoteRateRefillPerSecond,
}

local remotes: Folder? = nil
local snapshotEvent: RemoteEvent? = nil
local notifyEvent: RemoteEvent? = nil
local handlers: { [string]: (Player, ...any) -> Types.ErrorCode? } = {}
local buckets: { [number]: { [string]: RateLimit.Bucket } } = {}

-- Creates the Remotes folder and the two server→client channels. The
-- client→server events are created lazily by register(). Must run in the
-- server Init() pass, before any client can fire.
function RemoteService.init(): ()
	local folder = Instance.new("Folder")
	folder.Name = REMOTES_FOLDER_NAME
	folder.Parent = ReplicatedStorage
	remotes = folder

	local snapshot = Instance.new("RemoteEvent")
	snapshot.Name = SNAPSHOT_EVENT_NAME
	snapshot.Parent = folder
	snapshotEvent = snapshot

	local notify = Instance.new("RemoteEvent")
	notify.Name = NOTIFY_EVENT_NAME
	notify.Parent = folder
	notifyEvent = notify
end

local function reject(player: Player, remoteName: string, reason: Types.ErrorCode): ()
	Log.warn("RemoteService", "rejected", { player = player.UserId, remote = remoteName, reason = reason })
end

local function onServerEvent(remoteName: string, player: Player, ...: any): ()
	-- (1) Rate limit: cheap bound on per-remote work, runs first.
	local playerBuckets = buckets[player.UserId]
	if playerBuckets == nil then
		playerBuckets = {}
		buckets[player.UserId] = playerBuckets
	end
	local bucket = playerBuckets[remoteName]
	if bucket == nil then
		bucket = RateLimit.newBucket(RATE_BUDGET, os.clock())
		playerBuckets[remoteName] = bucket
	end
	if not RateLimit.tryConsume(bucket, RATE_BUDGET, os.clock()) then
		reject(player, remoteName, "RATE_LIMITED")
		return
	end

	-- (2) Gate: no handler serves a player without an active profile.
	if not DataService.hasSession(player) then
		reject(player, remoteName, "NO_ACTIVE_PROFILE")
		return
	end

	-- (3) The handler validates its own payload (Validate.*) and applies;
	-- pcall contains unexpected faults so they never escape the handler.
	local handler = handlers[remoteName]
	if handler == nil then
		Log.error("RemoteService", "missing handler", { remote = remoteName })
		return
	end
	local ok, err = pcall(handler, player, ...)
	if not ok then
		Log.error(
			"RemoteService",
			"handler fault",
			{ player = player.UserId, remote = remoteName, err = tostring(err) }
		)
		RemoteService.notify(player, "Something went wrong — nothing was changed.")
		return
	end
	if err ~= nil then
		reject(player, remoteName, err)
	end
end

-- Registers one client→server remote. Creates the RemoteEvent on demand
-- and connects OnServerEvent exactly once. Registering before init() (no
-- folder) or twice is refused with Log.error — never a second connection.
function RemoteService.register(name: string, handler: (Player, ...any) -> Types.ErrorCode?): ()
	local folder = remotes
	if folder == nil then
		Log.error("RemoteService", "register before init", { remote = name })
		return
	end
	if handlers[name] ~= nil then
		Log.error("RemoteService", "duplicate registration", { remote = name })
		return
	end
	local existing = folder:FindFirstChild(name)
	local event: RemoteEvent
	if existing == nil then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	elseif existing:IsA("RemoteEvent") then
		event = existing
	else
		Log.error("RemoteService", "remote name collision", { remote = name })
		return
	end
	handlers[name] = handler
	event.OnServerEvent:Connect(function(player: Player, ...: any)
		onServerEvent(name, player, ...)
	end)
end

-- Pushes a snapshot to one player. The snapshot must be a
-- Schema.snapshot copy (server-authoritative data); callers never build
-- one by hand. Drops with a warning when the event or player is gone.
function RemoteService.pushSnapshot(player: Player, snapshot: Types.ProfileData): ()
	local event = snapshotEvent
	if event == nil or player.Parent ~= Players then
		Log.warn("RemoteService", "snapshot push dropped", { player = player.UserId })
		return
	end
	event:FireClient(player, snapshot)
end

-- Generic player feedback channel (architecture: Notify). Only the fault
-- path uses it at this story — rejections are silent by design.
function RemoteService.notify(player: Player, message: string): ()
	local event = notifyEvent
	if event == nil or player.Parent ~= Players then
		Log.warn("RemoteService", "notify dropped", { player = player.UserId })
		return
	end
	event:FireClient(player, message)
end

-- Drops every rate-limit bucket for a leaving player. Called from the
-- existing PlayerRemoving connection in init.server.luau.
function RemoteService.releasePlayer(player: Player): ()
	buckets[player.UserId] = nil
end

return RemoteService
