--!strict
-- MirrorTestView.luau — TEMPORARY proof view for Story 1.4 (AC7). Renders
-- vault usage + item count from StateMirror only, proving the server→client
-- round trip. Story 1.5 rehomes this into the main menu. Nothing here is
-- authoritative and nothing here is enforced: both numbers are display
-- derivations from the mirror. `used` = distinct item ids with count > 0;
-- slot semantics are Epic 3's to define, this is display-only.

local Players = game:GetService("Players")

local StateMirror = require(script.Parent.StateMirror)

local VIEW_NAME = "MirrorTestView"
local PLACEHOLDER_VAULT = "Vault: — / —"
local PLACEHOLDER_ITEMS = "Items: —"

local MirrorTestView = {}

local vaultLabel: TextLabel? = nil
local itemsLabel: TextLabel? = nil

local function setText(label: TextLabel?, text: string): ()
	if label ~= nil then
		label.Text = text
	end
end

local function render(): ()
	local data = StateMirror.get()
	if data == nil then
		setText(vaultLabel, PLACEHOLDER_VAULT)
		setText(itemsLabel, PLACEHOLDER_ITEMS)
		return
	end
	local used = 0
	local total = 0
	local vault = data.vault
	if type(vault) == "table" then
		for _, itemCount in pairs(vault) do
			if type(itemCount) == "number" and itemCount > 0 then
				used += 1
				total += itemCount
			end
		end
	end
	local capacity = data.capacity
	if type(capacity) ~= "number" then
		capacity = 0
	end
	setText(vaultLabel, ("Vault: %d / %d"):format(used, capacity))
	setText(itemsLabel, ("Items: %d"):format(total))
end

local function makeLabel(parent: Instance, name: string, yOffset: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.fromOffset(220, 28)
	label.Position = UDim2.fromOffset(12, yOffset)
	label.BackgroundTransparency = 0.4
	label.TextScaled = true
	label.Text = ""
	label.Parent = parent
	return label
end

function MirrorTestView.start(): ()
	local player = Players.LocalPlayer
	if player == nil then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	if playerGui == nil then
		return
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = VIEW_NAME
	screen.ResetOnSpawn = false
	screen.Parent = playerGui

	vaultLabel = makeLabel(screen, "VaultUsage", 12)
	itemsLabel = makeLabel(screen, "ItemCount", 44)

	StateMirror.onChange(render)
	render()
end

return MirrorTestView
