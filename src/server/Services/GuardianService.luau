--!strict

-- One Verity Guardian per zone (GDD 4.4). Each hunts the heaviest stack on
-- its floor: it warns the target, chases them along a path, and on reaching
-- them makes them drop their stack. It never targets or enters the safe zone.
-- Server only; clients see the Guardian move and get the hunted warning.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Guardian)
local Region = require(Shared.Region)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local VerityOrb = require(Shared.VerityOrb)
local DropService = require(script.Parent.DropService)
local StackService = require(script.Parent.StackService)

local SPAWN_TAG = "GuardianSpawn"
local SAFE_ZONE_TAG = "SafeZone"
local FOLDER_NAME = "Guardians"
-- Pathfinding label put on safe zones so paths route around them.
local SAFE_ZONE_LABEL = "SafeZone"
-- Close enough to a waypoint to move on to the next one, in studs.
local ARRIVE_DISTANCE = 0.5

type Guardian = {
	zone: string,
	model: Model,
	-- Ground-level points; the model floats HoverHeight above `position`.
	home: Vector3,
	position: Vector3,
	facing: Vector3,
	speed: number,
	leash: number,

	state: Types.GuardianState,
	-- Seconds spent in the current state.
	stateTime: number,
	target: Player?,
	retargetIn: number,

	waypoints: { Vector3 },
	waypointIndex: number,
	repathIn: number,
	-- Bumped whenever the path goal changes, so a slow path result for an
	-- old goal is thrown away.
	pathToken: number,
	pathing: boolean,
}

local GuardianService = {}

local guardians: { Guardian } = {}
local safeZones: { BasePart } = {}

local function flatten(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- Where a living character's feet are, or nil if the player has none.
local function feetOf(player: Player): Vector3?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end
	return root.Position - Vector3.yAxis * (humanoid.HipHeight + root.Size.Y / 2)
end

-- The zone whose floor is nearest in height to `position`.
local function zoneAt(position: Vector3): string?
	local nearest: Guardian? = nil
	for _, guardian in guardians do
		if not nearest or math.abs(guardian.home.Y - position.Y) < math.abs(nearest.home.Y - position.Y) then
			nearest = guardian
		end
	end
	return nearest and nearest.zone
end

-- The player's feet if this Guardian may hunt them right now, else nil.
local function huntable(guardian: Guardian, player: Player): Vector3?
	if StackService.GetWeight(player) < Config.MinTargetWeight or DropService.IsImmune(player) then
		return nil
	end
	local feet = feetOf(player)
	if not feet or zoneAt(feet) ~= guardian.zone or Region.Contains(safeZones, feet) then
		return nil
	end
	return feet
end

-- The heaviest huntable stack on this Guardian's floor.
local function pickTarget(guardian: Guardian): Player?
	local best: Player? = nil
	local bestWeight = 0
	for _, player in Players:GetPlayers() do
		local weight = StackService.GetWeight(player)
		if weight > bestWeight and huntable(guardian, player) then
			best = player
			bestWeight = weight
		end
	end
	return best
end

local function setState(guardian: Guardian, state: Types.GuardianState)
	guardian.state = state
	guardian.stateTime = 0
	guardian.model:SetAttribute("State", state)
end

local function clearPath(guardian: Guardian)
	guardian.waypoints = {}
	guardian.waypointIndex = 1
	guardian.repathIn = 0
	guardian.pathToken += 1
end

-- Computes a path to `goal` in the background. Until it arrives, and if no
-- path exists (a target standing on cover), the Guardian heads straight there.
local function requestPath(guardian: Guardian, goal: Vector3)
	if guardian.pathing then
		return
	end
	guardian.pathing = true
	guardian.pathToken += 1
	local token = guardian.pathToken
	local start = guardian.position

	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = Config.AgentRadius,
			AgentHeight = Config.AgentHeight,
			AgentCanJump = true,
			Costs = { [SAFE_ZONE_LABEL] = math.huge },
		})
		local computed = pcall(function()
			path:ComputeAsync(start, goal)
		end)
		guardian.pathing = false
		if token ~= guardian.pathToken then
			return
		end

		local waypoints: { Vector3 } = {}
		if computed and path.Status == Enum.PathStatus.Success then
			for index, waypoint in path:GetWaypoints() do
				-- The first waypoint is where it already was.
				if index > 1 then
					table.insert(waypoints, waypoint.Position)
				end
			end
		end
		guardian.waypoints = waypoints
		guardian.waypointIndex = 1
	end)
end

-- Moves toward the next waypoint, or straight at `goal` when there is none.
-- Never steps into a safe zone.
local function move(guardian: Guardian, goal: Vector3, dt: number)
	local remaining = guardian.speed * dt
	while remaining > 0 do
		local waypoint = guardian.waypoints[guardian.waypointIndex] or goal
		local offset = waypoint - guardian.position
		local distance = offset.Magnitude
		if distance <= ARRIVE_DISTANCE then
			if not guardian.waypoints[guardian.waypointIndex] then
				break
			end
			guardian.waypointIndex += 1
			continue
		end

		local stride = math.min(remaining, distance)
		local nextPosition = guardian.position + offset.Unit * stride
		if Region.Contains(safeZones, nextPosition + Vector3.yAxis * Config.HoverHeight) then
			break
		end
		guardian.position = nextPosition
		remaining -= stride
		local heading = flatten(offset)
		if heading.Magnitude > 0.01 then
			guardian.facing = heading.Unit
		end
	end
end

local function place(guardian: Guardian)
	local centre = guardian.position + Vector3.yAxis * Config.HoverHeight
	guardian.model:PivotTo(CFrame.lookAt(centre, centre + guardian.facing))
end

-- Ends a hunt, tells the target they are no longer hunted and sends the
-- Guardian home to rest.
local function standDown(guardian: Guardian)
	local target = guardian.target
	if target and target.Parent then
		Remotes.GuardianHunt:FireClient(target, false)
	end
	guardian.target = nil
	clearPath(guardian)
	setState(guardian, "Cooldown")
end

local function goHome(guardian: Guardian, dt: number)
	if (guardian.home - guardian.position).Magnitude <= ARRIVE_DISTANCE then
		return
	end
	guardian.repathIn -= dt
	if guardian.repathIn <= 0 and #guardian.waypoints == 0 then
		guardian.repathIn = Config.RepathInterval
		requestPath(guardian, guardian.home)
	end
	move(guardian, guardian.home, dt)
end

local function step(guardian: Guardian, dt: number)
	guardian.stateTime += dt

	if guardian.state == "Idle" then
		goHome(guardian, dt)
		guardian.retargetIn -= dt
		if guardian.retargetIn <= 0 then
			guardian.retargetIn = Config.RetargetInterval
			local target = pickTarget(guardian)
			if target then
				guardian.target = target
				clearPath(guardian)
				setState(guardian, "Hunting")
				Remotes.GuardianHunt:FireClient(target, true)
			end
		end
	elseif guardian.state == "Hunting" or guardian.state == "Chasing" then
		local target = guardian.target
		local feet = target and huntable(guardian, target)
		if not target or not feet then
			standDown(guardian)
		elseif guardian.state == "Hunting" then
			-- Stands still and faces the target while they are warned.
			local heading = flatten(feet - guardian.position)
			if heading.Magnitude > 0.01 then
				guardian.facing = heading.Unit
			end
			if guardian.stateTime >= Config.TelegraphSeconds then
				setState(guardian, "Chasing")
			end
		elseif guardian.stateTime >= guardian.leash then
			standDown(guardian)
		else
			guardian.repathIn -= dt
			if guardian.repathIn <= 0 then
				guardian.repathIn = Config.RepathInterval
				requestPath(guardian, feet)
			end
			move(guardian, feet, dt)
			if (feet - guardian.position).Magnitude <= Config.AttackRange then
				setState(guardian, "Attacking")
				DropService.Drop(target)
				standDown(guardian)
			end
		end
	elseif guardian.state == "Cooldown" then
		goHome(guardian, dt)
		if guardian.stateTime >= Config.Cooldown then
			setState(guardian, "Idle")
		end
	end

	place(guardian)
end

-- The builder's rig if it exists, else a giant Corrupted orb.
local function createModel(): Model?
	local serverAssets = ServerStorage:FindFirstChild("Assets")
	local rig = serverAssets and serverAssets:FindFirstChild("Guardian")
	local model: Model
	if rig and rig:IsA("Model") then
		model = rig:Clone()
	else
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local verity = assets and assets:FindFirstChild("Verity")
		if not verity or not verity:IsA("Model") then
			return nil
		end
		model = VerityOrb.Create(verity, "Corrupted", Config.PlaceholderScale)
	end

	-- Moved by this service, not by physics, and never in a player's way.
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	model.Name = "Guardian"
	return model
end

function GuardianService.Init()
	safeZones = Region.Tagged(SAFE_ZONE_TAG)
	-- Without this a path to a target on the far side runs through the
	-- lobby, and the Guardian stalls at the safe zone's edge.
	for _, zone in safeZones do
		if not zone:FindFirstChildOfClass("PathfindingModifier") then
			local modifier = Instance.new("PathfindingModifier")
			modifier.Label = SAFE_ZONE_LABEL
			modifier.Parent = zone
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace

	for _, spawn in CollectionService:GetTagged(SPAWN_TAG) do
		local parent = spawn.Parent
		if not spawn:IsA("BasePart") or not parent then
			continue
		end
		local model = createModel()
		if not model then
			warn("GuardianService: no Guardian rig and no Verity model to stand in for it; no Guardians will spawn")
			return
		end

		local overrides = (Config.Zones :: { [string]: { WalkSpeed: number?, ChaseLeash: number? } })[parent.Name] or {}
		local home = spawn.Position - Vector3.yAxis * (spawn.Size.Y / 2)
		local guardian: Guardian = {
			zone = parent.Name,
			model = model,
			home = home,
			position = home,
			facing = -Vector3.zAxis,
			speed = overrides.WalkSpeed or Config.WalkSpeed,
			leash = overrides.ChaseLeash or Config.ChaseLeash,
			state = "Idle",
			stateTime = 0,
			target = nil,
			retargetIn = Config.RetargetInterval,
			waypoints = {},
			waypointIndex = 1,
			repathIn = 0,
			pathToken = 0,
			pathing = false,
		}
		model:SetAttribute("Zone", guardian.zone)
		setState(guardian, "Idle")
		place(guardian)
		model.Parent = folder
		table.insert(guardians, guardian)
	end

	if #guardians == 0 then
		warn(`GuardianService: no parts tagged {SPAWN_TAG}; no Guardians will spawn`)
	end
end

function GuardianService.Start()
	Players.PlayerRemoving:Connect(function(player)
		for _, guardian in guardians do
			if guardian.target == player then
				standDown(guardian)
			end
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		for _, guardian in guardians do
			step(guardian, dt)
		end
	end)
end

return GuardianService
