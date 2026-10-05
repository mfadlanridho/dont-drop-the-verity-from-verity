--!strict

-- Owns every player's stack (GDD 4.2): collects pickups in range, enforces
-- capacity and applies the speed penalty. The count is mirrored to a Player
-- attribute so every client can render it; clients never send stack amounts.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Stack)
local VerityConfig = require(Shared.Config.Verity)
local Types = require(Shared.Types)
local DataService = require(script.Parent.DataService)
local VerityService = require(script.Parent.VerityService)

local StackService = {}

local stacks: { [Player]: number } = {}

-- Upgrade level, or 0 while the profile is still loading.
local function level(player: Player, id: Types.UpgradeId): number
	local profile = DataService.GetProfile(player)
	return if profile then profile.Upgrades[id] or 0 else 0
end

local function setStack(player: Player, size: number)
	if stacks[player] ~= size then
		stacks[player] = size
		player:SetAttribute(Config.StackAttribute, size)
	end
end

local function livingHumanoid(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return humanoid
end

-- Collects every pickup within reach until the stack is full, and returns
-- the new stack size. A full stack leaves pickups in the world.
local function collect(player: Player, root: BasePart, pickups: { Instance }, size: number, capacity: number): number
	if size >= capacity then
		return size
	end

	local radius = VerityConfig.PickupRadius + level(player, "Magnet") * VerityConfig.PickupRadiusPerLevel
	local multiplier = 1 + level(player, "Multiplier") * VerityConfig.MultiplierPerLevel
	local origin = root.Position

	for _, pickup in pickups do
		if not pickup:IsA("PVInstance") or (pickup:GetPivot().Position - origin).Magnitude > radius then
			continue
		end
		-- nil when another player took it earlier this frame.
		local value = VerityService.Collect(pickup)
		if value then
			size = math.min(size + value * multiplier, capacity)
			if size >= capacity then
				break
			end
		end
	end
	return size
end

local function step()
	local pickups = CollectionService:GetTagged(VerityConfig.PickupTag)

	for _, player in Players:GetPlayers() do
		local capacity = StackService.GetCapacity(player)
		if player:GetAttribute(Config.CapacityAttribute) ~= capacity then
			player:SetAttribute(Config.CapacityAttribute, capacity)
		end

		local humanoid = livingHumanoid(player)
		local root = humanoid and humanoid.RootPart
		if not humanoid or not root then
			-- A stack does not survive death; otherwise resetting would be a
			-- free trip back to the bank.
			setStack(player, 0)
			continue
		end

		local size = collect(player, root, pickups, stacks[player] or 0, capacity)
		setStack(player, size)

		local penalty = math.min(size * Config.SpeedPenaltyPerVerity, Config.MaxSpeedPenalty)
		local speed = (Config.BaseWalkSpeed + level(player, "Speed") * Config.WalkSpeedPerLevel) * (1 - penalty)
		if humanoid.WalkSpeed ~= speed then
			humanoid.WalkSpeed = speed
		end
	end
end

function StackService.Get(player: Player): number
	return stacks[player] or 0
end

function StackService.GetCapacity(player: Player): number
	return Config.BaseCapacity + level(player, "Capacity") * Config.CapacityPerLevel
end

-- Takes up to `amount` Veritys off the stack and returns how many were taken.
function StackService.Remove(player: Player, amount: number): number
	local size = stacks[player] or 0
	local taken = math.clamp(math.floor(amount), 0, size)
	setStack(player, size - taken)
	return taken
end

-- Empties the stack and returns what it held.
function StackService.Clear(player: Player): number
	return StackService.Remove(player, math.huge)
end

function StackService.Init()
	Players.PlayerAdded:Connect(function(player)
		setStack(player, 0)
	end)
	Players.PlayerRemoving:Connect(function(player)
		stacks[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		setStack(player, 0)
	end
end

function StackService.Start()
	RunService.Heartbeat:Connect(step)
end

return StackService
