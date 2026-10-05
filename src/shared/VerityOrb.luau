--!strict

-- Builds a Verity orb of a given tier from the Verity model, so world pickups
-- and stack orbs look the same.

local Config = require(script.Parent.Config.Verity)
local Types = require(script.Parent.Types)

local VerityOrb = {}

-- A copy of `model` sized and tinted for `tier`. `scale` is the size of a
-- Normal orb as a fraction of the model.
function VerityOrb.Create(model: Model, tier: Types.VerityTier, scale: number): Model
	local look = Config.Tiers[tier] :: { Scale: number, Color: Color3? }
	local orb = model:Clone()
	orb:ScaleTo(scale * look.Scale)

	local primary = orb.PrimaryPart
	if primary and look.Color then
		primary.Color = look.Color
	end
	return orb
end

return VerityOrb
