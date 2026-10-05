--!strict

-- Verity Guardian (GDD 4.4).
return table.freeze({
	WalkSpeed = 18,
	-- Players carrying less than this weight are never targeted. Among the
	-- rest the Guardian picks the heaviest stack on its floor.
	MinTargetWeight = 5,
	-- Seconds between target searches while idle. GDD says "every few seconds".
	RetargetInterval = 3,
	-- Seconds a chase lasts before the Guardian gives up.
	ChaseLeash = 12,
	-- Seconds the Guardian rests after a chase or a hit.
	Cooldown = 6,

	-- Per-floor overrides of the values above, keyed by the zone folder name
	-- under Workspace.Map (GDD 4.8: faster on later floors, longer leash on the last).
	Zones = table.freeze({
		Zone2 = table.freeze({ WalkSpeed = 20 }),
		Zone3 = table.freeze({ WalkSpeed = 22, ChaseLeash = 16 }),
	}),

	-- Not set by the GDD.
	-- Seconds between picking a target and starting to move, while the target
	-- is warned.
	TelegraphSeconds = 1.5,
	-- Studs from the Guardian's ground point to the target's feet at which it hits.
	AttackRange = 6,
	-- Seconds between path recalculations during a chase.
	RepathInterval = 0.4,
	-- Studs from the ground to the centre of the Guardian.
	HoverHeight = 6,
	-- Size of the stand-in Guardian, a Corrupted orb, as a multiple of the
	-- Verity model. Used until ServerStorage.Assets.Guardian exists.
	PlaceholderScale = 3.5,
	-- Pathfinding agent size. Narrower than the Guardian looks, so it can
	-- thread between cover.
	AgentRadius = 3,
	AgentHeight = 6,
})
