--!strict
-- RateLimit.luau — pure per-player per-remote token bucket for FR13's
-- reject-not-queue rule. The clock is an explicit `now` parameter (seconds,
-- same basis as os.clock) so TestEZ can drive time deterministically;
-- RemoteService passes os.clock() at the call site. No game services, no
-- yields — safe to require from both sides of the boundary.

export type Budget = {
	capacity: number,
	refillPerSecond: number,
}

export type Bucket = {
	tokens: number,
	updatedAt: number,
}

local RateLimit = {}

-- A new bucket starts full: a freshly seen player gets the whole budget,
-- and only sustained fire drains it.
function RateLimit.newBucket(budget: Budget, now: number): Bucket
	return { tokens = budget.capacity, updatedAt = now }
end

-- Refills by elapsed * refillPerSecond (capped at capacity), then consumes
-- one token. Returns false when fewer than one token is available — the
-- caller drops the request immediately: no queue, no retry, no waiting.
function RateLimit.tryConsume(bucket: Bucket, budget: Budget, now: number): boolean
	local elapsed = now - bucket.updatedAt
	if elapsed > 0 then
		bucket.tokens = math.min(budget.capacity, bucket.tokens + elapsed * budget.refillPerSecond)
		bucket.updatedAt = now
	end
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

return RateLimit
