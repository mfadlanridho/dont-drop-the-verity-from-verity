--!strict

-- Owns every player's stack (GDD 4.2): which Veritys they hold, bottom first.
-- Collects pickups in range that fit the remaining capacity, and applies the
-- speed penalty. Capacity and the penalty count weight; banking counts value.
-- The stack is mirrored to Player attributes so every client can render it;
-- clients never send stack amounts.

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

type Tier = Types.VerityTier

type Stack = {
	tiers: { Tier },
	weight: number,
	-- Sum of tier values, before the Multiplier upgrade.
	baseValue: number,
}

local TIERS = VerityConfig.Tiers :: { [Tier]: { Value: number, Weight: number, Code: string } }

local StackService = {}

local stacks: { [Player]: Stack } = {}

-- Upgrade level, or 0 while the profile is still loading.
local function level(player: Player, id: Types.UpgradeId): number
	local profile = DataService.GetProfile(player)
	return if profile then profile.Upgrades[id] or 0 else 0
end

local function setAttribute(player: Player, name: string, value: any)
	if player:GetAttribute(name) ~= value then
		player:SetAttribute(name, value)
	end
end

-- Mirrors the stack to the player's attributes after it changes.
local function publish(player: Player, stack: Stack)
	local codes = table.create(#stack.tiers)
	for index, tier in stack.tiers do
		codes[index] = TIERS[tier].Code
	end
	setAttribute(player, Config.TiersAttribute, table.concat(codes))
	setAttribute(player, Config.StackAttribute, #stack.tiers)
	setAttribute(player, Config.WeightAttribute, stack.weight)
end

local function push(stack: Stack, tier: Tier)
	table.insert(stack.tiers, tier)
	stack.weight += TIERS[tier].Weight
	stack.baseValue += TIERS[tier].Value
end

-- Takes up to `count` Veritys off the top and returns them, top first.
local function pop(player: Player, count: number): { Tier }
	local stack = stacks[player]
	local removed: { Tier } = {}
	if not stack then
		return removed
	end

	for _ = 1, math.min(count, #stack.tiers) do
		local tier = table.remove(stack.tiers) :: Tier
		stack.weight -= TIERS[tier].Weight
		stack.baseValue -= TIERS[tier].Value
		table.insert(removed, tier)
	end
	if #removed > 0 then
		publish(player, stack)
	end
	return removed
end

local function livingHumanoid(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return humanoid
end

-- Collects every pickup within reach whose whole weight fits the room left.
-- One that does not fit stays in the world. Returns whether anything was taken.
local function collect(player: Player, stack: Stack, root: BasePart, pickups: { Instance }, capacity: number): boolean
	local room = capacity - stack.weight
	if room <= 0 then
		return false
	end

	local radius = VerityConfig.PickupRadius + level(player, "Magnet") * VerityConfig.PickupRadiusPerLevel
	local origin = root.Position
	local collected = false

	for _, pickup in pickups do
		if not pickup:IsA("PVInstance") or (pickup:GetPivot().Position - origin).Magnitude > radius then
			continue
		end
		-- nil when another player took it earlier this frame.
		local tier = VerityService.GetTier(pickup)
		if tier and TIERS[tier].Weight <= room and VerityService.Collect(pickup) then
			push(stack, tier)
			room -= TIERS[tier].Weight
			collected = true
			if room <= 0 then
				break
			end
		end
	end
	return collected
end

local function step()
	local pickups = CollectionService:GetTagged(VerityConfig.PickupTag)

	for _, player in Players:GetPlayers() do
		local stack = stacks[player]
		if not stack then
			continue
		end

		local capacity = StackService.GetCapacity(player)
		setAttribute(player, Config.CapacityAttribute, capacity)
		-- Not folded into publish: a Multiplier purchase changes it without
		-- the stack changing.
		setAttribute(player, Config.ValueAttribute, StackService.GetValue(player))

		local humanoid = livingHumanoid(player)
		local root = humanoid and humanoid.RootPart
		if not humanoid or not root then
			-- A stack does not survive death; otherwise resetting would be a
			-- free trip back to the bank.
			pop(player, math.huge)
			continue
		end

		if collect(player, stack, root, pickups, capacity) then
			publish(player, stack)
		end

		local penalty = math.min(stack.weight * Config.SpeedPenaltyPerWeight, Config.MaxSpeedPenalty)
		local speed = (Config.BaseWalkSpeed + level(player, "Speed") * Config.WalkSpeedPerLevel) * (1 - penalty)
		if humanoid.WalkSpeed ~= speed then
			humanoid.WalkSpeed = speed
		end
	end
end

local function add(player: Player)
	local stack: Stack = { tiers = {}, weight = 0, baseValue = 0 }
	stacks[player] = stack
	publish(player, stack)
end

-- Number of Veritys held.
function StackService.Get(player: Player): number
	local stack = stacks[player]
	return if stack then #stack.tiers else 0
end

-- Total weight held, out of GetCapacity.
function StackService.GetWeight(player: Player): number
	local stack = stacks[player]
	return if stack then stack.weight else 0
end

function StackService.GetCapacity(player: Player): number
	return Config.BaseCapacity + level(player, "Capacity") * Config.CapacityPerLevel
end

-- What the stack would bank for right now, Multiplier upgrade included.
function StackService.GetValue(player: Player): number
	local stack = stacks[player]
	if not stack then
		return 0
	end
	return stack.baseValue * (1 + level(player, "Multiplier") * VerityConfig.MultiplierPerLevel)
end

-- A copy of the tiers held, bottom of the stack first.
function StackService.GetTiers(player: Player): { Tier }
	local stack = stacks[player]
	return if stack then table.clone(stack.tiers) else {}
end

-- Takes up to `count` Veritys off the top of the stack and returns their
-- tiers, top first.
function StackService.Remove(player: Player, count: number): { Tier }
	return pop(player, math.max(math.floor(count), 0))
end

-- Empties the stack and returns the tiers it held, top first.
function StackService.Clear(player: Player): { Tier }
	return pop(player, math.huge)
end

function StackService.Init()
	Players.PlayerAdded:Connect(add)
	Players.PlayerRemoving:Connect(function(player)
		stacks[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		add(player)
	end
end

function StackService.Start()
	RunService.Heartbeat:Connect(step)
end

return StackService
