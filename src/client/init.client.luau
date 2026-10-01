--!strict
-- init.client.luau — client entry point. Story 1.3: receive the initial
-- data snapshot the join gate pushes once the player passes it, and hold
-- it in a local read-only table. Advisory data only — the client never
-- computes authoritative state. Story 1.4 replaces this holder with
-- StateMirror. No client-to-server traffic exists in this story.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Log)

local REMOTES_FOLDER_NAME = "Remotes"
local SNAPSHOT_EVENT_NAME = "Snapshot"
local WAIT_TIMEOUT_SECONDS = 10

local initialSnapshot: { [string]: any }? = nil

local function deepFreeze(value: any): ()
	if type(value) ~= "table" then
		return
	end
	for _, item in pairs(value) do
		deepFreeze(item)
	end
	table.freeze(value)
end

local remotes = ReplicatedStorage:WaitForChild(REMOTES_FOLDER_NAME, WAIT_TIMEOUT_SECONDS)
if remotes == nil then
	Log.warn("Client", "snapshot receive unavailable", { reason = "remotes_timeout" })
else
	local event = remotes:WaitForChild(SNAPSHOT_EVENT_NAME, WAIT_TIMEOUT_SECONDS)
	if event == nil or not event:IsA("RemoteEvent") then
		Log.warn("Client", "snapshot receive unavailable", { reason = "snapshot_missing" })
	else
		event.OnClientEvent:Connect(function(...: any): ()
			local payload = ...
			if type(payload) == "table" then
				initialSnapshot = payload
				deepFreeze(initialSnapshot)
			end
		end)
	end
end
