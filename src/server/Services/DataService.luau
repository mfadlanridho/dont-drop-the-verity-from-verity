--!strict

-- Owns every player's profile. Other services read and change player data
-- through this module only. Profiles live in memory for the session; DataStore
-- persistence arrives with M-02 behind the same API.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Data)
local Types = require(Shared.Types)

type Profile = Types.Profile

local DataService = {}

local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { (Player, Profile) -> () } = {}

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value :: any do
		copy[key] = deepCopy(child)
	end
	return copy :: any
end

-- Adds any field the template has and `data` lacks, so profiles saved before
-- a field existed pick up its default.
local function reconcile(data: { [any]: any }, template: { [any]: any })
	for key, default in template do
		if data[key] == nil then
			data[key] = deepCopy(default)
		elseif type(default) == "table" and type(data[key]) == "table" then
			reconcile(data[key], default)
		end
	end
end

local function isCount(value: unknown): boolean
	return type(value) == "number" and value >= 0 and value % 1 == 0 and value < math.huge
end

local function replicate(player: Player, profile: Profile)
	local fields = profile :: any
	for _, field in Config.ReplicatedFields do
		player:SetAttribute(field, fields[field])
	end
	for id, level in profile.Upgrades :: { [string]: number } do
		player:SetAttribute(Config.UpgradeAttributePrefix .. id, level)
	end
end

local function load(player: Player)
	if profiles[player] then
		return
	end

	local profile = {} :: any
	reconcile(profile, Config.Template)
	profiles[player] = profile

	replicate(player, profile)
	player:SetAttribute(Config.LoadedAttribute, true)

	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile)
	end
end

local function release(player: Player)
	profiles[player] = nil
end

-- The player's profile, or nil while it is loading or after they leave.
-- Treat it as read-only: change it through Update so the client mirror stays in sync.
function DataService.GetProfile(player: Player): Profile?
	return profiles[player]
end

-- Calls `callback` for every profile already loaded and every one loaded later.
function DataService.OnProfileLoaded(callback: (Player, Profile) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile)
	end
end

-- Runs `mutate` on the player's profile and mirrors the result to the client.
-- `mutate` must not yield. Returns false if the player has no profile.
function DataService.Update(player: Player, mutate: (Profile) -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	mutate(profile)
	replicate(player, profile)
	return true
end

-- Credits banked Veritys and counts them toward the lifetime total.
function DataService.AddBanked(player: Player, amount: number): boolean
	if not isCount(amount) then
		warn(`DataService.AddBanked: invalid amount {amount}`)
		return false
	end
	return DataService.Update(player, function(profile)
		profile.Banked += amount
		profile.TotalBanked += amount
	end)
end

-- Deducts banked Veritys if the player can afford it. Returns whether it did.
function DataService.TrySpend(player: Player, amount: number): boolean
	if not isCount(amount) then
		warn(`DataService.TrySpend: invalid amount {amount}`)
		return false
	end
	local profile = profiles[player]
	if not profile or profile.Banked < amount then
		return false
	end
	return DataService.Update(player, function(p)
		p.Banked -= amount
	end)
end

-- Raises TallestStack if `size` beats the player's record.
function DataService.RecordStack(player: Player, size: number): boolean
	if not isCount(size) then
		warn(`DataService.RecordStack: invalid size {size}`)
		return false
	end
	local profile = profiles[player]
	if not profile or size <= profile.TallestStack then
		return false
	end
	return DataService.Update(player, function(p)
		p.TallestStack = size
	end)
end

function DataService.Init()
	-- Connected in Init so every profile for a player already in the server
	-- exists before any service's Start runs.
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		load(player)
	end
end

return DataService
