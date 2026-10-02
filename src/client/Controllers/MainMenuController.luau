--!strict
-- MainMenuController.luau — Story 1.5: the game's main menu. Appears only
-- once the session gate has opened, observed client-side as the first
-- snapshot landing in StateMirror (the gate push IS the signal — no new
-- server code exists for the menu). Entry points: Dive (primary, bottom-
-- center thumb zone), Vault and Trade (visibly placeholder — Story 5.1 owns
-- navigation, so placeholder activation is local-only feedback and never
-- fires a remote). The stats panel is the 1.4 proof view rehomed: vault
-- used / capacity + item count, derived from the mirror only. Every button
-- is Selectable + wired through Activated so touch, mouse click, and
-- Roblox default gamepad navigation reach the same controls (NFR5).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Log)
local StateMirror = require(script.Parent.StateMirror)

local MENU_NAME = "MainMenu"
local PLACEHOLDER_NOTE = "Coming in a later epic — placeholder"

local MainMenuController = {}

local root: Frame? = nil
local noteLabel: TextLabel? = nil
local vaultLabel: TextLabel? = nil
local itemsLabel: TextLabel? = nil

local function setText(label: TextLabel?, text: string): ()
	if label ~= nil then
		label.Text = text
	end
end

local function render(): ()
	local data = StateMirror.get()
	if data == nil or root == nil then
		if root ~= nil then
			root.Visible = false
		end
		return
	end
	root.Visible = true
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

local function makeLabel(parent: Instance, name: string, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 0.4
	label.TextScaled = true
	label.Text = ""
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, name: string, text: string, position: UDim2, size: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = position
	button.Size = size
	button.Selectable = true
	button.TextScaled = true
	button.Parent = parent
	return button
end

local function onPlaceholder(entry: string): ()
	return function(): ()
		setText(noteLabel, ("%s: %s"):format(entry, PLACEHOLDER_NOTE))
		Log.info("MainMenu", "placeholder entry activated", { entry = entry })
	end
end

function MainMenuController.start(): ()
	local player = Players.LocalPlayer
	if player == nil then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	if playerGui == nil then
		return
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = MENU_NAME
	screen.ResetOnSpawn = false
	screen.Parent = playerGui

	local menu = Instance.new("Frame")
	menu.Name = "MenuRoot"
	menu.AnchorPoint = Vector2.new(0.5, 0.5)
	menu.Position = UDim2.fromScale(0.5, 0.5)
	menu.Size = UDim2.fromScale(1, 1)
	menu.BackgroundTransparency = 1
	menu.Active = false
	menu.Visible = false
	menu.Parent = screen
	root = menu

	local title = makeLabel(menu, "Title", UDim2.fromScale(0.5, 0.1), UDim2.fromScale(0.8, 0.1))
	title.Text = "CURIO VAULT"
	title.BackgroundTransparency = 1

	vaultLabel = makeLabel(menu, "VaultUsage", UDim2.fromScale(0.5, 0.24), UDim2.fromScale(0.6, 0.07))
	itemsLabel = makeLabel(menu, "ItemCount", UDim2.fromScale(0.5, 0.33), UDim2.fromScale(0.6, 0.07))

	noteLabel = makeLabel(menu, "PlaceholderNote", UDim2.fromScale(0.5, 0.45), UDim2.fromScale(0.85, 0.06))
	noteLabel.BackgroundTransparency = 1

	local vaultButton = makeButton(menu, "VaultEntry", "Vault", UDim2.fromScale(0.28, 0.6), UDim2.fromScale(0.4, 0.1))
	local tradeButton = makeButton(menu, "TradeEntry", "Trade", UDim2.fromScale(0.72, 0.6), UDim2.fromScale(0.4, 0.1))
	local diveButton = makeButton(menu, "DiveEntry", "Dive", UDim2.fromScale(0.5, 0.8), UDim2.fromScale(0.7, 0.12))

	vaultButton.Activated:Connect(onPlaceholder("Vault")())
	tradeButton.Activated:Connect(onPlaceholder("Trade")())
	diveButton.Activated:Connect(onPlaceholder("Dive")())

	StateMirror.onChange(render)
	render()
end

return MainMenuController
