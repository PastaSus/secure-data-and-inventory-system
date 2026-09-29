-- Schema.spec.luau — TestEZ coverage for the pure migration function.
-- Plain tables in, plain tables out: no Players, no DataStore, no game
-- services. `describe`/`it`/`expect` are TestEZ globals injected by
-- TestPlanner at run time (this file is NOT covered by `selene src/`).

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Schema = require(ReplicatedStorage.Shared.Schema)
	local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

	describe("Schema.defaultProfile", function()
		it("returns current-version defaults with start capacity", function()
			local profile = Schema.defaultProfile()

			expect(profile.schemaVersion).to.equal(Schema.CURRENT_SCHEMA_VERSION)
			expect(profile.capacity).to.equal(8)
			expect(profile.capacity).to.equal(GameConfig.startCapacity)
			expect(next(profile.vault)).to.equal(nil)
			expect(#profile.provenance).to.equal(0)
		end)
	end)

	describe("Schema.migrate", function()
		it("migrates nil input to a fresh default profile", function()
			local migrated = Schema.migrate(nil)

			expect(migrated.schemaVersion).to.equal(1)
			expect(migrated.capacity).to.equal(8)
			expect(next(migrated.vault)).to.equal(nil)
		end)

		it("migrates an empty table to defaults", function()
			local migrated = Schema.migrate({})

			expect(migrated.schemaVersion).to.equal(1)
			expect(migrated.capacity).to.equal(8)
		end)

		it("preserves existing vault entries when migrating an older schema", function()
			local migrated = Schema.migrate({
				vault = { [1] = 3, [7] = 1 },
				capacity = 8,
			})

			expect(migrated.schemaVersion).to.equal(1)
			expect(migrated.vault[1]).to.equal(3)
			expect(migrated.vault[7]).to.equal(1)
			expect(migrated.capacity).to.equal(8)
		end)

		it("is idempotent on current-version input", function()
			local migrated = Schema.migrate({
				schemaVersion = 1,
				vault = { [2] = 5 },
				provenance = {},
				capacity = 12,
			})

			expect(migrated.schemaVersion).to.equal(1)
			expect(migrated.vault[2]).to.equal(5)
			expect(migrated.capacity).to.equal(12)
		end)

		it("repairs corrupt fields and clamps impossible future versions", function()
			local migrated = Schema.migrate({
				schemaVersion = 99,
				vault = { [3] = 2 },
				capacity = 0,
			})

			expect(migrated.schemaVersion).to.equal(Schema.CURRENT_SCHEMA_VERSION)
			expect(migrated.vault[3]).to.equal(2)
			expect(migrated.capacity).to.equal(8)
		end)

		it("drops malformed vault pairs but keeps valid ones", function()
			local migrated = Schema.migrate({
				vault = { [4] = 2, [5] = 0, [6] = -1 },
				capacity = 8,
			})

			expect(migrated.vault[4]).to.equal(2)
			expect(migrated.vault[5]).to.equal(nil)
			expect(migrated.vault[6]).to.equal(nil)
		end)

		it("trims provenance to the newest 50 entries", function()
			local input: { [string]: any } = { capacity = 8, provenance = {} }
			for i = 1, 60 do
				table.insert(input.provenance, { itemDefId = i, source = "dive", acquiredAt = i })
			end

			local migrated = Schema.migrate(input)

			expect(#migrated.provenance).to.equal(50)
			expect(migrated.provenance[1].itemDefId).to.equal(11)
			expect(migrated.provenance[50].itemDefId).to.equal(60)
		end)
	end)
end
