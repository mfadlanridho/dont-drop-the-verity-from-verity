--!strict

-- Verity Guardian (GDD 4.4).
return table.freeze({
	WalkSpeed = 18,
	-- Players below this stack are never targeted.
	MinTargetStack = 5,
	-- Seconds between target re-evaluations. GDD says "every few seconds".
	RetargetInterval = 3,
	-- Seconds a chase lasts before the Guardian gives up.
	ChaseLeash = 12,
	-- Seconds the Guardian rests after a chase or a hit.
	Cooldown = 6,
})
