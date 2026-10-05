--!strict

-- Dropping on a Guardian hit (GDD 4.5). A hit drops the whole stack.
return table.freeze({
	-- Seconds before scattered pickups despawn.
	DespawnSeconds = 10,
	-- Seconds the hit player cannot be hit again.
	ImmunitySeconds = 3,

	-- Not set by the GDD.
	-- Scattered pickups land in a ring this far from the hit player, in studs.
	-- Keep the inner edge beyond Config.Verity.PickupRadius so the stack is
	-- not simply picked straight back up.
	ScatterMinRadius = 8,
	ScatterMaxRadius = 14,
	-- Seconds before a scattered pickup can be collected by anyone.
	PickupDelay = 0.75,
	-- Most pickups one hit scatters. The rest of a larger stack is lost, to
	-- keep a huge drop from flooding the server with parts.
	MaxScattered = 40,
})
