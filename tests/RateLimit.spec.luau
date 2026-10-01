-- RateLimit.spec.luau — TestEZ coverage for the pure per-player per-remote
-- token bucket (FR13 reject-not-queue). Time is an explicit `now` argument
-- (seconds, os.clock basis) so refill is deterministic without task.wait.
-- `describe`/`it`/`expect` are TestEZ globals injected by TestPlanner at
-- run time (this file is NOT covered by `selene src/`).

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RateLimit = require(ReplicatedStorage.Shared.RateLimit)

	local function budget(capacity: number, refillPerSecond: number): RateLimit.Budget
		return { capacity = capacity, refillPerSecond = refillPerSecond }
	end

	describe("RateLimit", function()
		it("a new bucket starts full and accepts exactly capacity consumes", function()
			local cfg = budget(3, 1)
			local bucket = RateLimit.newBucket(cfg, 0)

			expect(RateLimit.tryConsume(bucket, cfg, 0)).to.equal(true)
			expect(RateLimit.tryConsume(bucket, cfg, 0)).to.equal(true)
			expect(RateLimit.tryConsume(bucket, cfg, 0)).to.equal(true)
			expect(RateLimit.tryConsume(bucket, cfg, 0)).to.equal(false)
		end)

		it("a drained bucket stays rejected instead of queueing", function()
			local cfg = budget(1, 1)
			local bucket = RateLimit.newBucket(cfg, 0)

			expect(RateLimit.tryConsume(bucket, cfg, 0)).to.equal(true)
			expect(RateLimit.tryConsume(bucket, cfg, 0)).to.equal(false)
			expect(RateLimit.tryConsume(bucket, cfg, 0)).to.equal(false)
		end)

		it("refills proportionally with elapsed time", function()
			local cfg = budget(5, 1)
			local bucket = RateLimit.newBucket(cfg, 0)
			for _ = 1, 5 do
				RateLimit.tryConsume(bucket, cfg, 0)
			end
			expect(RateLimit.tryConsume(bucket, cfg, 0)).to.equal(false)

			expect(RateLimit.tryConsume(bucket, cfg, 2)).to.equal(true)
			expect(RateLimit.tryConsume(bucket, cfg, 2)).to.equal(true)
			expect(RateLimit.tryConsume(bucket, cfg, 2)).to.equal(false)
		end)

		it("caps refill at capacity no matter how much time passes", function()
			local cfg = budget(3, 10)
			local bucket = RateLimit.newBucket(cfg, 0)
			RateLimit.tryConsume(bucket, cfg, 0)
			RateLimit.tryConsume(bucket, cfg, 0)
			RateLimit.tryConsume(bucket, cfg, 0)

			expect(RateLimit.tryConsume(bucket, cfg, 1000)).to.equal(true)
			expect(RateLimit.tryConsume(bucket, cfg, 1000)).to.equal(true)
			expect(RateLimit.tryConsume(bucket, cfg, 1000)).to.equal(true)
			expect(RateLimit.tryConsume(bucket, cfg, 1000)).to.equal(false)
		end)

		it("never refills without elapsed time", function()
			local cfg = budget(2, 100)
			local bucket = RateLimit.newBucket(cfg, 5)

			RateLimit.tryConsume(bucket, cfg, 5)
			RateLimit.tryConsume(bucket, cfg, 5)

			expect(RateLimit.tryConsume(bucket, cfg, 5)).to.equal(false)
		end)

		it("accrues fractional refill across calls", function()
			local cfg = budget(2, 1)
			local bucket = RateLimit.newBucket(cfg, 0)
			RateLimit.tryConsume(bucket, cfg, 0)
			RateLimit.tryConsume(bucket, cfg, 0)

			expect(RateLimit.tryConsume(bucket, cfg, 0.5)).to.equal(false)
			expect(RateLimit.tryConsume(bucket, cfg, 1)).to.equal(true)
		end)
	end)
end
