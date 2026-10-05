--!strict

-- Warns the local player while a Guardian is hunting them (GDD 4.4: being
-- hunted must never be a surprise), and tells them when a hit spills their
-- stack.
--
-- The UI itself is built in Studio at StarterGui.HuntedHud; this finds its
-- parts by name and shows them, so keep the instance names stable:
-- Warning and Dropped (Message).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local GUI_NAME = "HuntedHud"
local GUI_WAIT_SECONDS = 10
-- Seconds the "You dropped" note stays up.
local DROPPED_NOTE_SECONDS = 3

local player = Players.LocalPlayer

local HuntedController = {}

-- False if the Studio-built UI was not found.
local ready = false
local warning: Frame
local dropped: Frame
local droppedLabel: TextLabel
-- Counts dropped notes so an older one's timer does not hide a newer note.
local droppedNote = 0

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
	local gui = player:WaitForChild("PlayerGui"):WaitForChild(GUI_NAME, GUI_WAIT_SECONDS)
	if not gui then
		warn(`HuntedController: StarterGui.{GUI_NAME} is missing; the hunted warning is off`)
		return
	end

	warning = gui:WaitForChild("Warning") :: Frame
	dropped = gui:WaitForChild("Dropped") :: Frame
	droppedLabel = dropped:WaitForChild("Message") :: TextLabel
	warning.Visible = false
	dropped.Visible = false
	ready = true
end

function HuntedController.Start()
	if not ready then
		return
	end
	Remotes.GuardianHunt.OnClientEvent:Connect(onHunt)
	Remotes.StackDropped.OnClientEvent:Connect(onDropped)
end

return HuntedController
