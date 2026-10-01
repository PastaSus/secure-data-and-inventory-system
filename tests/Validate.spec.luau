-- Validate.spec.luau — TestEZ coverage for the pure RemoteService payload
-- validators. Plain values in, ErrorCode? out: no Players, no DataStore,
-- no game services. `describe`/`it`/`expect` are TestEZ globals injected by
-- TestPlanner at run time (this file is NOT covered by `selene src/`).

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Validate = require(ReplicatedStorage.Shared.Validate)

	describe("Validate.noArgs", function()
		it("accepts an empty payload", function()
			expect(Validate.noArgs()).to.equal(nil)
		end)

		it("rejects any client-supplied argument", function()
			expect(Validate.noArgs(1)).to.equal("INVALID_PAYLOAD")
			expect(Validate.noArgs("junk")).to.equal("INVALID_PAYLOAD")
			expect(Validate.noArgs({})).to.equal("INVALID_PAYLOAD")
		end)

		it("rejects an explicit nil argument", function()
			expect(Validate.noArgs(nil)).to.equal("INVALID_PAYLOAD")
		end)
	end)
end
