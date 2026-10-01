--!strict
-- init.client.luau — client entry point. Story 1.4: pushed snapshots land
-- in StateMirror and views render from the mirror only. The one
-- client→server request in this story is the bootstrap RequestSnapshot:
-- fired once, AFTER the Snapshot listener is connected, so a gate push
-- that raced ahead of this script is recovered by the request path.
-- No other client-to-server traffic exists (ADR-002; no RemoteFunctions).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Log)
local StateMirror = require(script.Controllers.StateMirror)
local MirrorTestView = require(script.Controllers.MirrorTestView)

local REMOTES_FOLDER_NAME = "Remotes"
local SNAPSHOT_EVENT_NAME = "Snapshot"
local REQUEST_EVENT_NAME = "RequestSnapshot"
local WAIT_TIMEOUT_SECONDS = 10

local remotes = ReplicatedStorage:WaitForChild(REMOTES_FOLDER_NAME, WAIT_TIMEOUT_SECONDS)
if remotes == nil then
	Log.warn("Client", "mirror unavailable", { reason = "remotes_timeout" })
else
	local snapshotEvent = remotes:WaitForChild(SNAPSHOT_EVENT_NAME, WAIT_TIMEOUT_SECONDS)
	if snapshotEvent == nil or not snapshotEvent:IsA("RemoteEvent") then
		Log.warn("Client", "mirror unavailable", { reason = "snapshot_missing" })
	else
		snapshotEvent.OnClientEvent:Connect(function(...: any): ()
			StateMirror.apply(...)
		end)
		MirrorTestView.start()
		local requestEvent = remotes:WaitForChild(REQUEST_EVENT_NAME, WAIT_TIMEOUT_SECONDS)
		if requestEvent ~= nil and requestEvent:IsA("RemoteEvent") then
			requestEvent:FireServer()
		else
			Log.warn("Client", "snapshot request unavailable", { reason = "request_missing" })
		end
	end
end
