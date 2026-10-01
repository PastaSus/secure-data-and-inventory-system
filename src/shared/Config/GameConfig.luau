--!strict
-- GameConfig.luau — gameplay numbers, server-authoritative.
-- Story 1.2 scope: ONLY startCapacity. Pack size, trade timeout, rarity
-- weights arrive with the stories that need them (data created only
-- when required). Read-only by convention AND enforcement (frozen).

local GameConfig = {
	startCapacity = 8,
	-- Maximum seconds the join gate waits for ProfileStore session lock
	-- acquisition before failing closed (kick). Owned by the join gate.
	joinLoadTimeout = 10,
}

table.freeze(GameConfig)

return GameConfig
