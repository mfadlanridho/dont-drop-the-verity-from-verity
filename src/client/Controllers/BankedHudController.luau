--!strict

-- Shows the local player's banked Veritys (GDD 4.3). The value is the Player
-- attribute DataService keeps current; this only draws it. Plain on purpose:
-- the ui-artist styles it later, so keep the instance names stable.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Data"))
local Format = require(Shared:WaitForChild("Format"))

local BANKED_ATTRIBUTE = "Banked"

local player = Players.LocalPlayer

local BankedHudController = {}

local label: TextLabel

local function update()
	local banked = player:GetAttribute(BANKED_ATTRIBUTE)
	if player:GetAttribute(Config.LoadedAttribute) ~= true or typeof(banked) ~= "number" then
		label.Text = "Banked: ..."
		return
	end
	label.Text = `Banked: {Format.Number(banked)}`
end

function BankedHudController.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BankedHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1

	local frame = Instance.new("Frame")
	frame.Name = "Banked"
	frame.AnchorPoint = Vector2.new(0, 0.5)
	frame.Position = UDim2.new(0, 12, 0.5, 0)
	frame.Size = UDim2.fromOffset(170, 40)
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 0.4
	frame.BorderSizePixel = 0
	frame.Parent = gui

	label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 22
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = frame

	gui.Parent = player:WaitForChild("PlayerGui")
end

function BankedHudController.Start()
	player:GetAttributeChangedSignal(BANKED_ATTRIBUTE):Connect(update)
	player:GetAttributeChangedSignal(Config.LoadedAttribute):Connect(update)
	update()
end

return BankedHudController
