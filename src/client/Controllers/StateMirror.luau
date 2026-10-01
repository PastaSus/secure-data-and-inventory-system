--!strict
-- StateMirror.luau — the client's read-only mirror of server state.
-- Server pushes snapshots (gate push, or the answer to RequestSnapshot);
-- this module deep-freezes them and is the ONLY thing views render from.
-- Firing a remote is the only client input path — nothing on the client
-- writes into the mirror except `apply`. Deltas have no producer at
-- Story 1.4 (nothing mutates player data yet), so there are snapshots
-- plus change subscriptions only — no Signal, no delta channel.

local StateMirror = {}

local snapshot: { [string]: any }? = nil
local subscribers: { (any) -> () } = {}

local function deepFreeze(value: any): ()
	if type(value) ~= "table" then
		return
	end
	for _, item in pairs(value) do
		deepFreeze(item)
	end
	table.freeze(value)
end

-- Stores a pushed snapshot, frozen so client-side mutation is impossible
-- by construction, then notifies subscribers. Non-table payloads are
-- ignored (fail closed — the mirror keeps the last good snapshot).
function StateMirror.apply(payload: any): ()
	if type(payload) ~= "table" then
		return
	end
	deepFreeze(payload)
	snapshot = payload
	for _, callback in ipairs(subscribers) do
		callback(snapshot)
	end
end

function StateMirror.get(): { [string]: any }?
	return snapshot
end

function StateMirror.onChange(callback: (any) -> ()): ()
	table.insert(subscribers, callback)
end

return StateMirror
