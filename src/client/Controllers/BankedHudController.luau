--!strict

-- Shows the local player's banked Veritys (GDD 4.3). The value is the Player
-- attribute DataService keeps current; this only draws it.
--
-- The UI itself is built in Studio at StarterGui.BankedHud; this finds its
-- parts by name and fills them in, so keep the instance names stable:
-- Banked (Amount).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Data"))
local Format = require(Shared:WaitForChild("Format"))

local GUI_NAME = "BankedHud"
local GUI_WAIT_SECONDS = 10
local BANKED_ATTRIBUTE = "Banked"

local player = Players.LocalPlayer

local BankedHudController = {}

-- False if the Studio-built UI was not found.
local ready = false
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
	local gui = player:WaitForChild("PlayerGui"):WaitForChild(GUI_NAME, GUI_WAIT_SECONDS)
	if not gui then
		warn(`BankedHudController: StarterGui.{GUI_NAME} is missing; the banked HUD is off`)
		return
	end

	label = gui:WaitForChild("Banked"):WaitForChild("Amount") :: TextLabel
	ready = true
end

function BankedHudController.Start()
	if not ready then
		return
	end
	player:GetAttributeChangedSignal(BANKED_ATTRIBUTE):Connect(update)
	player:GetAttributeChangedSignal(Config.LoadedAttribute):Connect(update)
	update()
end

return BankedHudController
