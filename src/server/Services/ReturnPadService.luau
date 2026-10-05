--!strict

-- Sends a character that stays on a ReturnPad to the lobby's ReturnTarget.
-- Only the character moves: the stack is untouched and banks the normal way,
-- by walking into the BankZone.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.ReturnPad)

local PAD_TAG = "ReturnPad"
local TARGET_TAG = "ReturnTarget"

local ReturnPadService = {}

local pads: { BasePart } = {}
local target: BasePart?
-- Seconds each player has spent on a pad without leaving it.
local channel: { [Player]: number } = {}

-- Polled rather than driven by Touched/TouchEnded, which fire unreliably for
-- a character standing still.
local function isOnPad(root: BasePart): boolean
	for _, pad in pads do
		local offset = pad.CFrame:PointToObjectSpace(root.Position)
		local half = pad.Size / 2
		if
			math.abs(offset.X) <= half.X
			and math.abs(offset.Z) <= half.Z
			and offset.Y >= 0
			and offset.Y <= half.Y + Config.MaxHeightAbovePad
		then
			return true
		end
	end
	return false
end

local function livingRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return humanoid.RootPart
end

local function cancel(player: Player)
	if channel[player] then
		channel[player] = nil
		player:SetAttribute(Config.ChannelAttribute, nil)
	end
end

local function step(dt: number)
	local destination = target
	if not destination then
		return
	end

	for _, player in Players:GetPlayers() do
		local root = livingRoot(player)
		if not root or not isOnPad(root) then
			cancel(player)
			continue
		end

		local elapsed = channel[player]
		if not elapsed then
			elapsed = 0
			player:SetAttribute(Config.ChannelAttribute, Workspace:GetServerTimeNow() + Config.ChannelSeconds)
		end
		elapsed += dt
		channel[player] = elapsed

		if elapsed >= Config.ChannelSeconds then
			cancel(player)
			local character = root.Parent :: Model
			character:PivotTo(destination.CFrame)
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

function ReturnPadService.Init()
	for _, pad in CollectionService:GetTagged(PAD_TAG) do
		if pad:IsA("BasePart") then
			table.insert(pads, pad)
		end
	end

	local found = CollectionService:GetTagged(TARGET_TAG)[1]
	if found and found:IsA("BasePart") then
		target = found
	elseif #pads > 0 then
		warn(`ReturnPadService: no part tagged {TARGET_TAG}; return pads will do nothing`)
	end
end

function ReturnPadService.Start()
	Players.PlayerRemoving:Connect(function(player)
		channel[player] = nil
	end)
	RunService.Heartbeat:Connect(step)
end

return ReturnPadService
