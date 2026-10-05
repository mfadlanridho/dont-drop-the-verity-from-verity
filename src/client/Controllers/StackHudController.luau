--!strict

-- Shows the local player's load (weight against capacity), what the stack
-- would bank for, how much the load slows them, a warning while a Verity in
-- reach is too heavy to fit, a note when the stack is banked, and the return
-- pad countdown. Every value comes from the server; this only draws them.
--
-- The UI itself is built in Studio at StarterGui.StackHud; this finds its
-- parts by name and fills them in, so keep the instance names stable:
-- Load (Fill, Amount, Value, Speed, TooHeavy, Banked) and Return (Countdown).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Stack"))
local ReturnConfig = require(Shared.Config:WaitForChild("ReturnPad"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local GUI_NAME = "StackHud"
local GUI_WAIT_SECONDS = 10
-- Seconds the "Banked +n" note stays up.
local BANKED_NOTE_SECONDS = 2

local player = Players.LocalPlayer

local StackHudController = {}

-- False if the Studio-built UI was not found.
local ready = false
local fillColor: Color3
local refusedColor: Color3
local fill: Frame
local amount: TextLabel
local value: TextLabel
local speed: TextLabel
local tooHeavy: TextLabel
local banked: TextLabel
-- Counts banked notes so an older one's timer does not hide a newer note.
local bankedNote = 0
local returnFrame: Frame
local countdown: TextLabel

local function number(attribute: string): number
	local found = player:GetAttribute(attribute)
	return if typeof(found) == "number" then found else 0
end

local function updateLoad()
	local weight = number(Config.WeightAttribute)
	local capacity = number(Config.CapacityAttribute)
	local refused = player:GetAttribute(Config.RefusedAttribute) == true

	fill.Size = UDim2.fromScale(if capacity > 0 then math.clamp(weight / capacity, 0, 1) else 0, 1)
	fill.BackgroundColor3 = if refused then refusedColor else fillColor
	amount.Text = `{Format.Number(weight)} / {Format.Number(capacity)}`
	value.Text = `Carrying: {Format.Number(number(Config.ValueAttribute))}`
	-- Share of walk speed left after the load's penalty, as StackService applies it.
	local penalty = math.min(weight * Config.SpeedPenaltyPerWeight, Config.MaxSpeedPenalty)
	speed.Text = `Speed: {math.floor((1 - penalty) * 100 + 0.5)}%`
	tooHeavy.Visible = refused
end

local function showBanked(amount: number)
	bankedNote += 1
	local note = bankedNote
	banked.Text = `Banked +{Format.Number(amount)}`
	banked.Visible = true
	task.delay(BANKED_NOTE_SECONDS, function()
		if bankedNote == note then
			banked.Visible = false
		end
	end)
end

local function updateReturn()
	local returnAt = player:GetAttribute(ReturnConfig.ChannelAttribute)
	if typeof(returnAt) ~= "number" then
		returnFrame.Visible = false
		return
	end
	local remaining = math.max(returnAt - Workspace:GetServerTimeNow(), 0)
	countdown.Text = string.format("Returning in %.1f", remaining)
	returnFrame.Visible = true
end

function StackHudController.Init()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild(GUI_NAME, GUI_WAIT_SECONDS)
	if not gui then
		warn(`StackHudController: StarterGui.{GUI_NAME} is missing; the stack HUD is off`)
		return
	end

	local load = gui:WaitForChild("Load")
	fill = load:WaitForChild("Fill") :: Frame
	amount = load:WaitForChild("Amount") :: TextLabel
	value = load:WaitForChild("Value") :: TextLabel
	speed = load:WaitForChild("Speed") :: TextLabel
	tooHeavy = load:WaitForChild("TooHeavy") :: TextLabel
	banked = load:WaitForChild("Banked") :: TextLabel
	returnFrame = gui:WaitForChild("Return") :: Frame
	countdown = returnFrame:WaitForChild("Countdown") :: TextLabel

	-- Both bar colours are set in Studio: the bar's own colour, and its
	-- RefusedColor attribute for while a pickup is too heavy.
	fillColor = fill.BackgroundColor3
	local refused = fill:GetAttribute("RefusedColor")
	refusedColor = if typeof(refused) == "Color3" then refused else fillColor

	banked.Visible = false
	tooHeavy.Visible = false
	returnFrame.Visible = false
	ready = true
end

function StackHudController.Start()
	if not ready then
		return
	end
	for _, attribute in
		{ Config.WeightAttribute, Config.CapacityAttribute, Config.ValueAttribute, Config.RefusedAttribute }
	do
		player:GetAttributeChangedSignal(attribute):Connect(updateLoad)
	end
	updateLoad()
	Remotes.StackBanked.OnClientEvent:Connect(showBanked)

	-- The countdown ticks between attribute changes, so it is redrawn each frame.
	RunService.RenderStepped:Connect(updateReturn)
end

return StackHudController
