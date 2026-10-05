--!strict

-- Warns the local player while a Guardian is hunting them (GDD 4.4: being
-- hunted must never be a surprise), and tells them when a hit spills their
-- stack. Plain on purpose: the ui-artist adds the audio cue and screen effect
-- later, so keep the instance names stable.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))

-- Seconds the "You dropped" note stays up.
local DROPPED_NOTE_SECONDS = 3
local WARNING_COLOR = Color3.fromRGB(200, 40, 40)

local player = Players.LocalPlayer

local HuntedController = {}

local warning: Frame
local dropped: Frame
local droppedLabel: TextLabel
-- Counts dropped notes so an older one's timer does not hide a newer note.
local droppedNote = 0

local function panel(name: string, parent: Instance, text: string): (Frame, TextLabel)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Size = UDim2.fromOffset(320, 44)
	frame.BackgroundColor3 = WARNING_COLOR
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 22
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = frame
	return frame, label
end

local function onHunt(isHunted: boolean)
	warning.Visible = isHunted == true
end

local function onDropped(count: number)
	-- A hit ends the hunt; the server's own "no longer hunted" follows.
	warning.Visible = false
	if typeof(count) ~= "number" or count <= 0 then
		return
	end

	droppedNote += 1
	local note = droppedNote
	droppedLabel.Text = `You dropped {Format.Number(count)} {if count == 1 then "Verity" else "Veritys"}!`
	dropped.Visible = true
	task.delay(DROPPED_NOTE_SECONDS, function()
		if droppedNote == note then
			dropped.Visible = false
		end
	end)
end

function HuntedController.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HuntedHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2

	-- Below the top bar, above the return countdown.
	warning = panel("Warning", gui, "The Guardian is hunting you!")
	warning.Position = UDim2.new(0.5, 0, 0, 56)

	dropped, droppedLabel = panel("Dropped", gui, "")
	dropped.Position = UDim2.new(0.5, 0, 0, 108)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function HuntedController.Start()
	Remotes.GuardianHunt.OnClientEvent:Connect(onHunt)
	Remotes.StackDropped.OnClientEvent:Connect(onDropped)
end

return HuntedController
