--!strict

-- Owns every player's profile. Other services read and change player data
-- through this module only. Persistence is ProfileStore's: it session-locks
-- each profile to one server, autosaves, retries failed DataStore calls, and
-- saves on leave and on server shutdown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Data)
local Types = require(Shared.Types)
local ProfileStore = (require :: any)(script.Parent.Parent.Vendor.ProfileStore)

type Profile = Types.Profile

local DataService = {}

-- MIGRATIONS[n] upgrades saved data from Version n to n + 1, in place.
local MIGRATIONS: { [number]: (data: any) -> () } = {}

local store: any
-- ProfileStore session objects; `profiles` holds each one's Data table.
local sessions: { [Player]: any } = {}
local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { (Player, Profile) -> () } = {}

-- Brings saved data up to the template's Version. Returns false for data
-- saved by a newer server, which this one must not touch.
local function migrate(data: any): boolean
	local target = Config.Template.Version
	if type(data.Version) ~= "number" or data.Version > target then
		return false
	end
	for version = data.Version, target - 1 do
		local step = MIGRATIONS[version]
		if step then
			step(data)
		end
		data.Version = version + 1
	end
	return true
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
	if sessions[player] then
		return
	end

	local session = store:StartSessionAsync(Config.KeyPrefix .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not session then
		-- Only when the server is shutting down or another server raced us for the profile.
		player:Kick("Your data could not be loaded. Please rejoin.")
		return
	end

	session:AddUserId(player.UserId)
	session:Reconcile()

	if player.Parent ~= Players then
		session:EndSession()
		return
	end
	if not migrate(session.Data) then
		warn(`DataService: {player.Name}'s data is Version {session.Data.Version}, newer than this server`)
		session:EndSession()
		player:Kick("Your data is from a newer version of the game. Please rejoin.")
		return
	end

	session.OnSessionEnd:Connect(function()
		sessions[player] = nil
		profiles[player] = nil
		player:Kick("Your data was loaded on another server. Please rejoin.")
	end)

	local profile = session.Data :: Profile
	sessions[player] = session
	profiles[player] = profile

	replicate(player, profile)
	player:SetAttribute(Config.LoadedAttribute, true)

	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile)
	end
end

local function release(player: Player)
	local session = sessions[player]
	if session then
		session:EndSession()
	end
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
	local name = if RunService:IsStudio() then Config.StudioStoreName else Config.StoreName
	store = ProfileStore.New(name, Config.Template)

	-- Loading yields, so a profile is not ready when a player joins: use
	-- OnProfileLoaded, or handle a nil GetProfile.
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
end

return DataService
