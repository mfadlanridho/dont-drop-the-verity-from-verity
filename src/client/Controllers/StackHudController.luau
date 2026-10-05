--!strict

-- Shows the local player's load (weight against capacity), what the stack
-- would bank for, how much the load slows them, a warning while a Verity in
-- reach is too heavy to fit, a note when the stack is banked, and the return
-- pad countdown. Every value comes from the server; this only draws them. Plain on purpose: the ui-artist styles it
-- later, so keep the instance names stable.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Stack"))
local ReturnConfig = require(Shared.Config:WaitForChild("ReturnPad"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))

-- Seconds the "Banked +n" note stays up.
local BANKED_NOTE_SECONDS = 2
local FILL_COLOR = Color3.fromRGB(255, 221, 51)
local REFUSED_COLOR = Color3.fromRGB(230, 70, 70)

local player = Players.LocalPlayer

local StackHudController = {}

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
	fill.BackgroundColor3 = if refused then REFUSED_COLOR else FILL_COLOR
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

local function label(name: string, parent: Instance, textSize: number): TextLabel
	local created = Instance.new("TextLabel")
	created.Name = name
	created.BackgroundTransparency = 1
	created.Font = Enum.Font.FredokaOne
	created.TextSize = textSize
	created.TextColor3 = Color3.new(1, 1, 1)
	created.TextStrokeTransparency = 0.4
	created.Parent = parent
	return created
end

local function panel(name: string, parent: Instance): Frame
	local created = Instance.new("Frame")
	created.Name = name
	created.BackgroundColor3 = Color3.new(0, 0, 0)
	created.BackgroundTransparency = 0.4
	created.BorderSizePixel = 0
	created.Parent = parent
	return created
end

function StackHudController.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "StackHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1

	-- Bottom centre, clear of the mobile thumbstick and jump button.
	local load = panel("Load", gui)
	load.AnchorPoint = Vector2.new(0.5, 1)
	load.Position = UDim2.new(0.5, 0, 1, -24)
	load.Size = UDim2.new(0.3, 0, 0, 30)
	local limits = Instance.new("UISizeConstraint")
	limits.MinSize = Vector2.new(180, 30)
	limits.MaxSize = Vector2.new(320, 30)
	limits.Parent = load

	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = FILL_COLOR
	fill.BorderSizePixel = 0
	fill.Parent = load

	amount = label("Amount", load, 20)
	amount.Size = UDim2.fromScale(1, 1)
	amount.ZIndex = 2

	value = label("Value", load, 18)
	value.AnchorPoint = Vector2.new(0, 1)
	value.Position = UDim2.new(0, 0, 0, -4)
	value.Size = UDim2.new(0.6, 0, 0, 22)
	value.TextXAlignment = Enum.TextXAlignment.Left

	speed = label("Speed", load, 18)
	speed.AnchorPoint = Vector2.new(1, 1)
	speed.Position = UDim2.new(1, 0, 0, -4)
	speed.Size = UDim2.new(0.4, 0, 0, 22)
	speed.TextXAlignment = Enum.TextXAlignment.Right

	-- Shares the slot above with TooHeavy; a stack that was just banked is
	-- empty, so the two do not show together for long.
	banked = label("Banked", load, 20)
	banked.AnchorPoint = Vector2.new(0.5, 1)
	banked.Position = UDim2.new(0.5, 0, 0, -52)
	banked.Size = UDim2.new(1, 0, 0, 24)
	banked.Visible = false

	tooHeavy = label("TooHeavy", load, 20)
	tooHeavy.AnchorPoint = Vector2.new(0.5, 1)
	tooHeavy.Position = UDim2.new(0.5, 0, 0, -28)
	tooHeavy.Size = UDim2.new(1, 0, 0, 24)
	tooHeavy.Text = "Too heavy"
	tooHeavy.TextColor3 = REFUSED_COLOR
	tooHeavy.Visible = false

	returnFrame = panel("Return", gui)
	returnFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	returnFrame.Position = UDim2.fromScale(0.5, 0.3)
	returnFrame.Size = UDim2.fromOffset(220, 40)
	returnFrame.Visible = false

	countdown = label("Countdown", returnFrame, 22)
	countdown.Size = UDim2.fromScale(1, 1)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function StackHudController.Start()
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
