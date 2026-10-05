--!strict

-- Price formulas shared by the server, which charges them, and the client,
-- which only displays them.

local Config = require(script.Parent.Config.Upgrades)
local Types = require(script.Parent.Types)

local Economy = {}

-- Whole number below 100, two significant digits above, so prices read cleanly.
function Economy.RoundPrice(value: number): number
	if value < 100 then
		return math.floor(value + 0.5)
	end
	local magnitude = 10 ^ (math.floor(math.log10(value)) - 1)
	return math.floor(value / magnitude + 0.5) * magnitude
end

-- Price of going from `level` to `level + 1`, or nil at the max level.
function Economy.UpgradeCost(id: Types.UpgradeId, level: number): number?
	local upgrade = (Config.Upgrades :: any)[id]
	if not upgrade or level >= upgrade.MaxLevel then
		return nil
	end
	return Economy.RoundPrice(upgrade.BaseCost * upgrade.CostGrowth ^ level)
end

return Economy
