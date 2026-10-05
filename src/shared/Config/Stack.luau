--!strict

-- Stack (GDD 4.2).
return table.freeze({
	-- Max stack before any Capacity upgrade.
	BaseCapacity = 10,
	-- Orbs rendered on the head; past this the stack shows a count billboard.
	VisualCap = 30,

	-- Walk speed before any Speed upgrade.
	BaseWalkSpeed = 16,
	-- Fraction of walk speed lost per stacked Verity.
	SpeedPenaltyPerVerity = 0.01,
	-- Ceiling on the total fraction lost.
	MaxSpeedPenalty = 0.4,
})
