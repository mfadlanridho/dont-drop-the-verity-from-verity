--!strict

-- Dropping on a Guardian hit (GDD 4.5).
return table.freeze({
	-- Fraction of the stack dropped, rounded up.
	DropFraction = 0.5,
	-- Seconds before scattered pickups despawn.
	DespawnSeconds = 10,
	-- Seconds the hit player cannot be hit again.
	ImmunitySeconds = 3,
})
