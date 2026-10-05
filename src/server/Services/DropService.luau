--!strict

-- Spills a player's whole stack when the Guardian hits them (GDD 4.5): the
-- Veritys scatter around them as pickups anyone can collect, and the player
-- cannot be hit again for a short while.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Drop)
local VerityConfig = require(Shared.Config.Verity)
local Remotes = require(Shared.Remotes)
local StackService = require(script.Parent.StackService)
local VerityService = require(script.Parent.VerityService)

-- How far above and below the player to look for ground under a scatter point.
local GROUND_PROBE_UP = 4
local GROUND_PROBE_DOWN = 12

local DropService = {}

local rng = Random.new()
-- os.clock() time until which each player cannot be hit.
local immuneUntil: { [Player]: number } = {}

-- Orb centres for `count` pickups in a ring around `origin`, each resting
-- above whatever ground is under it. A point with no ground under it (off a
-- ledge, inside a wall) falls back to the player's own position.
local function scatterPoints(origin: Vector3, count: number, character: Model): { Vector3 }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(excluded, player.Character)
		end
	end
	params.FilterDescendantsInstances = excluded

	local points = table.create(count)
	for index = 1, count do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = rng:NextNumber(Config.ScatterMinRadius, Config.ScatterMaxRadius)
		local flat = origin + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local hit = Workspace:Raycast(
			flat + Vector3.yAxis * GROUND_PROBE_UP,
			-Vector3.yAxis * (GROUND_PROBE_UP + GROUND_PROBE_DOWN),
			params
		)
		points[index] = if hit then hit.Position + Vector3.yAxis * VerityConfig.HoverHeight else origin
	end
	return points
end

function DropService.IsImmune(player: Player): boolean
	local untilTime = immuneUntil[player]
	return untilTime ~= nil and os.clock() < untilTime
end

-- Drops the player's whole stack around their character and starts their
-- immunity. Returns how many Veritys they lost.
function DropService.Drop(player: Player): number
	immuneUntil[player] = os.clock() + Config.ImmunitySeconds

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	-- Top of the stack first.
	local tiers = StackService.Clear(player)
	if character and root and root:IsA("BasePart") then
		local scattered = math.min(#tiers, Config.MaxScattered)
		for index, point in scatterPoints(root.Position, scattered, character) do
			VerityService.SpawnDropped(tiers[index], point, Config.PickupDelay, Config.DespawnSeconds)
		end
	end

	Remotes.StackDropped:FireClient(player, #tiers)
	return #tiers
end

function DropService.Init()
	Players.PlayerRemoving:Connect(function(player)
		immuneUntil[player] = nil
	end)
end

return DropService
