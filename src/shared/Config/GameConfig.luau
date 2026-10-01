--!strict
-- GameConfig.luau — gameplay numbers, server-authoritative.
-- Story 1.2 scope: ONLY startCapacity. Pack size, trade timeout, rarity
-- weights arrive with the stories that need them (data created only
-- when required). Read-only by convention AND enforcement (frozen).
-- Story 1.3 added: joinLoadTimeout (join-gate robustness number).
-- Story 1.4 adds: the default token-bucket budget for EVERY client
-- remote (FR13). A per-remote override table is added only when a remote
-- genuinely needs a different budget.

local GameConfig = {
	startCapacity = 8,
	-- Maximum seconds the join gate waits for ProfileStore session lock
	-- acquisition before failing closed (kick). Owned by the join gate.
	joinLoadTimeout = 10,
	-- Default rate-limit budget per player per remote: a burst of 15
	-- passes instantly, sustained fire is capped at 5/s, anything past
	-- the bucket is rejected, never queued. Owned by RemoteService.
	remoteRateCapacity = 15,
	remoteRateRefillPerSecond = 5,
}

table.freeze(GameConfig)

return GameConfig
