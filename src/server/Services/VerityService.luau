--!strict

-- Spawns Verity pickups in each zone's spawn regions, up to the zone cap, and
-- refills at a fixed rate (GDD 4.1). Collection rules live in StackService;
-- this service only owns the pickups themselves.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Verity)
local Types = require(Shared.Types)

local REGION_TAG = "VeritySpawnRegion"
local WEIGHT_ATTRIBUTE = "Weight"
local PICKUP_FOLDER_NAME = "Pickups"
local TEMPLATE_NAME = "Verity"

type Zone = {
	name: string,
	regions: { BasePart },
	tiers: { Types.VerityTier },
	count: number,
	-- Fractional pickups owed by the refill rate.
	budget: number,
}

local VerityService = {}

local rng = Random.new()
local zones: { Zone } = {}
local zoneOfPickup: { [Instance]: Zone } = {}
local pickupFolder: Folder
local template: PVInstance?

-- Relative chance of a region receiving the next pickup. Read live so the
-- attribute can be retuned in Studio during a playtest.
local function weightOf(region: BasePart): number
	local weight = region:GetAttribute(WEIGHT_ATTRIBUTE)
	if typeof(weight) ~= "number" then
		return 1
	end
	return math.max(weight, 0)
end

local function pickRegion(zone: Zone): BasePart?
	local total = 0
	for _, region in zone.regions do
		total += weightOf(region)
	end
	if total <= 0 then
		return nil
	end

	local roll = rng:NextNumber() * total
	for _, region in zone.regions do
		roll -= weightOf(region)
		if roll <= 0 then
			return region
		end
	end
	return zone.regions[#zone.regions]
end

-- A clear point at orb height inside one of the zone's regions, or nil if
-- every attempt landed on cover, the dais or another pickup.
local function findSpawnPoint(zone: Zone): Vector3?
	for _ = 1, Config.SpawnAttempts do
		local region = pickRegion(zone)
		if not region then
			return nil
		end

		local size = region.Size
		local point = region.CFrame:PointToWorldSpace(Vector3.new(
			(rng:NextNumber() - 0.5) * size.X,
			-size.Y / 2 + Config.HoverHeight,
			(rng:NextNumber() - 0.5) * size.Z
		))
		if #Workspace:GetPartBoundsInRadius(point, Config.ClearanceRadius) == 0 then
			return point
		end
	end
	return nil
end

local function createOrb(): PVInstance
	if template then
		return template:Clone()
	end

	local orb = Instance.new("Part")
	orb.Name = TEMPLATE_NAME
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.one * Config.PlaceholderDiameter
	orb.Color = Color3.fromRGB(255, 221, 51)
	orb.Material = Enum.Material.Neon
	orb.Anchored = true
	orb.CanCollide = false
	return orb
end

local function release(pickup: Instance)
	local zone = zoneOfPickup[pickup]
	if zone then
		zoneOfPickup[pickup] = nil
		zone.count -= 1
	end
end

local function spawnPickup(zone: Zone): boolean
	local point = findSpawnPoint(zone)
	if not point then
		return false
	end

	local tier = zone.tiers[rng:NextInteger(1, #zone.tiers)]
	local pickup = createOrb()
	pickup:SetAttribute("Tier", tier)
	pickup:SetAttribute("Value", Config.TierValue[tier])
	pickup:PivotTo(CFrame.new(point))
	pickup.Parent = pickupFolder
	CollectionService:AddTag(pickup, Config.PickupTag)

	zoneOfPickup[pickup] = zone
	zone.count += 1
	pickup.Destroying:Once(function()
		release(pickup)
	end)
	return true
end

local function refill(zone: Zone, dt: number)
	if zone.count >= Config.ZoneCap then
		zone.budget = 0
		return
	end

	zone.budget += dt * Config.RefillPerSecond
	while zone.budget >= 1 and zone.count < Config.ZoneCap do
		zone.budget -= 1
		if not spawnPickup(zone) then
			break
		end
	end
end

-- Removes a live pickup from the world and returns its stack value, or nil if
-- it is not a live pickup (already collected, or never one). The caller is
-- responsible for deciding the player is allowed to collect it.
function VerityService.Collect(pickup: Instance): number?
	if not zoneOfPickup[pickup] then
		return nil
	end
	local value = pickup:GetAttribute("Value")
	release(pickup)
	pickup:Destroy()
	return if typeof(value) == "number" then value else nil
end

function VerityService.Init()
	pickupFolder = Instance.new("Folder")
	pickupFolder.Name = PICKUP_FOLDER_NAME
	pickupFolder.Parent = Workspace

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local found = assets and assets:FindFirstChild(TEMPLATE_NAME)
	if found and found:IsA("PVInstance") then
		template = found
	else
		warn("VerityService: ReplicatedStorage.Assets.Verity is missing; using a placeholder orb")
	end

	-- A zone is the folder under Workspace.Map that holds the regions.
	local byName: { [string]: Zone } = {}
	for _, region in CollectionService:GetTagged(REGION_TAG) do
		local parent = region.Parent
		if not region:IsA("BasePart") or not parent then
			continue
		end

		local zone = byName[parent.Name]
		if not zone then
			local tiers = (Config.ZoneTiers :: any)[parent.Name]
			if not tiers then
				warn(`VerityService: no ZoneTiers config for {parent:GetFullName()}; skipping its spawn regions`)
				continue
			end
			zone = { name = parent.Name, regions = {}, tiers = tiers, count = 0, budget = 0 }
			byName[parent.Name] = zone
			table.insert(zones, zone)
		end
		table.insert(zone.regions, region)
	end

	if #zones == 0 then
		warn(`VerityService: no parts tagged {REGION_TAG}; no pickups will spawn`)
	end
end

function VerityService.Start()
	-- A fresh server starts full rather than making the first player wait.
	for _, zone in zones do
		for _ = 1, Config.ZoneCap do
			spawnPickup(zone)
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		for _, zone in zones do
			refill(zone, dt)
		end
	end)
end

return VerityService
