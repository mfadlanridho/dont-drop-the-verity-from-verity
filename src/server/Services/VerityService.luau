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
local VerityOrb = require(Shared.VerityOrb)

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
-- `zone` is nil for a dropped pickup, which counts toward no zone's cap.
-- `armedAt` is the os.clock() time from which it can be collected.
local live: { [Instance]: { zone: Zone?, tier: Types.VerityTier, armedAt: number } } = {}
local pickupFolder: Folder
-- One ready-made orb per tier, cloned for each spawn.
local templates: { [Types.VerityTier]: Model } = {}

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

local function release(pickup: Instance)
	local record = live[pickup]
	if record then
		live[pickup] = nil
		if record.zone then
			record.zone.count -= 1
		end
	end
end

local function createPickup(tier: Types.VerityTier, point: Vector3, zone: Zone?, armDelay: number): Model?
	local template = templates[tier]
	if not template then
		return nil
	end

	local pickup = template:Clone()
	pickup:SetAttribute("Tier", tier)
	pickup:SetAttribute("Value", Config.Tiers[tier].Value)
	pickup:SetAttribute("Weight", Config.Tiers[tier].Weight)
	pickup:PivotTo(CFrame.new(point))
	pickup.Parent = pickupFolder
	CollectionService:AddTag(pickup, Config.PickupTag)

	live[pickup] = { zone = zone, tier = tier, armedAt = os.clock() + armDelay }
	if zone then
		zone.count += 1
	end
	pickup.Destroying:Once(function()
		release(pickup)
	end)
	return pickup
end

local function spawnPickup(zone: Zone): boolean
	local point = findSpawnPoint(zone)
	if not point then
		return false
	end
	local tier = zone.tiers[rng:NextInteger(1, #zone.tiers)]
	return createPickup(tier, point, zone, 0) ~= nil
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

-- The tier of a pickup that can be collected right now, or nil if it cannot
-- (already collected, never a pickup, or a dropped one that is not armed yet).
function VerityService.GetTier(pickup: Instance): Types.VerityTier?
	local record = live[pickup]
	if not record or os.clock() < record.armedAt then
		return nil
	end
	return record.tier
end

-- Puts a pickup of `tier` at `point` (the orb's centre) outside any zone's
-- cap. It cannot be collected for `armDelay` seconds and despawns after
-- `lifetime` seconds if nobody takes it.
function VerityService.SpawnDropped(tier: Types.VerityTier, point: Vector3, armDelay: number, lifetime: number)
	local pickup = createPickup(tier, point, nil, armDelay)
	if pickup then
		pickup:SetAttribute("Dropped", true)
		task.delay(lifetime, function()
			if live[pickup] then
				pickup:Destroy()
			end
		end)
	end
end

-- Removes a live pickup from the world and returns its tier, or nil if it is
-- not a live pickup. The caller is responsible for deciding the player is
-- allowed to collect it.
function VerityService.Collect(pickup: Instance): Types.VerityTier?
	local record = live[pickup]
	if not record or os.clock() < record.armedAt then
		return nil
	end
	release(pickup)
	pickup:Destroy()
	return record.tier
end

function VerityService.Init()
	pickupFolder = Instance.new("Folder")
	pickupFolder.Name = PICKUP_FOLDER_NAME
	pickupFolder.Parent = Workspace

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local model = assets and assets:FindFirstChild(TEMPLATE_NAME)
	if model and model:IsA("Model") then
		for tier in Config.Tiers :: { [Types.VerityTier]: any } do
			templates[tier] = VerityOrb.Create(model, tier, 1)
		end
	else
		warn("VerityService: ReplicatedStorage.Assets.Verity is missing; no pickups will spawn")
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
