--!strict

-- Sells upgrade levels for banked Veritys (GDD 4.6). The client names the
-- upgrade it wants; the price and the level come from the server. The systems
-- an upgrade affects read its level from the profile themselves.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Upgrades)
local Economy = require(Shared.Economy)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local DataService = require(script.Parent.DataService)

local UpgradeService = {}

-- os.clock() of each player's last purchase request.
local lastRequest: { [Player]: number } = {}

-- Buys one level of `id`. Returns whether it was bought and, if not, why:
-- "NotLoaded", "MaxLevel" or "CannotAfford".
function UpgradeService.Buy(player: Player, id: Types.UpgradeId): (boolean, string?)
	local profile = DataService.GetProfile(player)
	if not profile then
		return false, "NotLoaded"
	end

	local level = profile.Upgrades[id] or 0
	local cost = Economy.UpgradeCost(id, level)
	if not cost then
		return false, "MaxLevel"
	end
	if profile.Banked < cost then
		return false, "CannotAfford"
	end

	DataService.Update(player, function(data)
		data.Banked -= cost
		data.Upgrades[id] = level + 1
	end)
	return true, nil
end

local function onBuyRequest(player: Player, id: unknown): (boolean, string?)
	local now = os.clock()
	local last = lastRequest[player]
	if last and now - last < Config.PurchaseCooldown then
		return false, "TooFast"
	end
	lastRequest[player] = now

	if type(id) ~= "string" or (Config.Upgrades :: any)[id] == nil then
		return false, "Invalid"
	end
	return UpgradeService.Buy(player, id :: any)
end

function UpgradeService.Start()
	Remotes.BuyUpgrade.OnServerInvoke = onBuyRequest
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return UpgradeService
