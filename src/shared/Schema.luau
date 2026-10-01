--!strict
-- Schema.luau — minimal v1 profile schema + forward-only migration.
-- Pure module: plain tables in, plain tables out. No DataStore, no game
-- services, no yields. Safe to require from both sides of the boundary
-- (only GameConfig/Types requires, both plain-table constant modules).

local GameConfig = require(script.Parent.Config.GameConfig)
local Types = require(script.Parent.Types)

local Schema = {}

Schema.CURRENT_SCHEMA_VERSION = 1
Schema.MAX_PROVENANCE_ENTRIES = 50

function Schema.defaultProfile(): Types.ProfileData
	return {
		schemaVersion = Schema.CURRENT_SCHEMA_VERSION,
		vault = {},
		provenance = {},
		capacity = GameConfig.startCapacity,
	}
end

local function isPositiveInteger(value: any): boolean
	return type(value) == "number" and value > 0 and value < math.huge and math.floor(value) == value
end

local function isUsableTimestamp(value: any): boolean
	return type(value) == "number" and value == value and value >= 0 and value < math.huge
end

-- migrate normalizes in place AND returns the table, so callers can use
-- either form. In-place matters for Profile.Data: DataService must not
-- replace the reference ProfileStore is tracking.
function Schema.migrate(data: any): Types.ProfileData
	if type(data) ~= "table" then
		return Schema.defaultProfile()
	end

	-- schemaVersion: coerce garbage to 0, clamp the future down.
	-- Forward-only chain below then lifts everything to current, so the
	-- stored version never decreases on a real profile. (Review decision
	-- 2026-09-29: clamping an impossible future version is corruption
	-- repair, not a backward migration — no newer client can exist.)
	-- `version ~= version` catches NaN, which defeats every comparison.
	local version = data.schemaVersion
	if type(version) ~= "number" or version ~= version or version < 0 then
		version = 0
	end
	if version > Schema.CURRENT_SCHEMA_VERSION then
		version = Schema.CURRENT_SCHEMA_VERSION
	end

	-- Forward-only migration chain. Each step moves data exactly one
	-- version up; future versions add their own `if version < N` block.
	-- v0 (missing/unknown) -> v1: minimal fields take defaults below.
	if version < 1 then
		version = 1
	end
	data.schemaVersion = version

	-- vault: compact {[itemDefId]: count}; preserve valid pairs, drop
	-- anything malformed (non-integer ids, non-positive counts).
	-- String keys are coerced: a DataStore/JSON round-trip stringifies
	-- numeric keys, and dropping them would permanently delete items.
	local cleanVault: { [number]: number } = {}
	if type(data.vault) == "table" then
		for rawId, count in pairs(data.vault) do
			local itemDefId = rawId
			if type(rawId) == "string" then
				itemDefId = tonumber(rawId)
			end
			if isPositiveInteger(itemDefId) and isPositiveInteger(count) then
				cleanVault[itemDefId] = count
			end
		end
	end
	data.vault = cleanVault

	-- provenance: keep well-formed entries only; oldest rotates out
	-- (ADR-004). `pairs` (not `ipairs`) so a sparse array keeps everything
	-- past a hole; sorting by acquiredAt makes the trim keep the newest,
	-- with dateless entries (0) first out.
	local cleanProvenance: { Types.ProvenanceEntry } = {}
	if type(data.provenance) == "table" then
		for _, entry in pairs(data.provenance) do
			if type(entry) == "table" and isPositiveInteger(entry.itemDefId) and type(entry.source) == "string" then
				local acquiredAt = 0
				if isUsableTimestamp(entry.acquiredAt) then
					acquiredAt = entry.acquiredAt
				end
				table.insert(cleanProvenance, {
					itemDefId = entry.itemDefId,
					source = entry.source,
					acquiredAt = acquiredAt,
				})
			end
		end
	end
	table.sort(cleanProvenance, function(a, b)
		return a.acquiredAt < b.acquiredAt
	end)
	while #cleanProvenance > Schema.MAX_PROVENANCE_ENTRIES do
		table.remove(cleanProvenance, 1)
	end
	data.provenance = cleanProvenance

	-- capacity: corrupt values fall back to start; only the server ever
	-- grants more (set completion, Epic 3).
	if not isPositiveInteger(data.capacity) then
		data.capacity = GameConfig.startCapacity
	end

	-- Unknown extra fields pass through untouched (forward compatible).
	return data
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy: { [any]: any } = {}
	for key, item in pairs(value) do
		copy[deepCopy(key)] = deepCopy(item)
	end
	return copy
end

-- snapshot returns a plain deep copy of a migrated profile: field values
-- only, no shared references. The copy DataService hands to the wire must
-- never alias Profile.Data, so client-side mutation can never touch the
-- server's authoritative table. Call only with migrated data (the gate
-- runs migrate first and refuses to continue on failure).
function Schema.snapshot(data: Types.ProfileData): Types.ProfileData
	if type(data) ~= "table" then
		return Schema.defaultProfile()
	end
	local source: any = data
	return {
		schemaVersion = source.schemaVersion,
		vault = deepCopy(source.vault),
		provenance = deepCopy(source.provenance),
		capacity = source.capacity,
	}
end

return Schema
