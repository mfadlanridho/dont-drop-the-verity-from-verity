--!strict

-- Banks a player's whole stack when their character enters a BankZone
-- (GDD 4.3): the stack's value becomes banked Veritys and the stack empties.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)
local StackService = require(script.Parent.StackService)

local ZONE_TAG = "BankZone"

local BankService = {}

local zones: { BasePart } = {}

local function isInZone(position: Vector3): boolean
	for _, zone in zones do
		local offset = zone.CFrame:PointToObjectSpace(position)
		local half = zone.Size / 2
		if math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z then
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

local function bank(player: Player)
	local count = StackService.Get(player)
	local value = StackService.GetValue(player)
	-- Fails while the profile is still loading; the stack is kept and banks
	-- on a later frame.
	if not DataService.AddBanked(player, value) then
		return
	end
	StackService.Clear(player)
	DataService.RecordStack(player, count)
	Remotes.StackBanked:FireClient(player, value, count)
end

-- Polled rather than driven by Touched, which fires unreliably for a
-- character standing still.
local function step()
	for _, player in Players:GetPlayers() do
		if StackService.Get(player) == 0 then
			continue
		end
		local root = livingRoot(player)
		if root and isInZone(root.Position) then
			bank(player)
		end
	end
end

function BankService.Init()
	for _, zone in CollectionService:GetTagged(ZONE_TAG) do
		if zone:IsA("BasePart") then
			table.insert(zones, zone)
		end
	end
	if #zones == 0 then
		warn(`BankService: no part tagged {ZONE_TAG}; stacks cannot be banked`)
	end
end

function BankService.Start()
	RunService.Heartbeat:Connect(step)
end

return BankService
