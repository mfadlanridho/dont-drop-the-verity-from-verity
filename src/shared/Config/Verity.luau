--!strict

-- Pickups (GDD 4.1, 4.8).
return table.freeze({
	-- Max live pickups per zone.
	ZoneCap = 60,
	-- Pickups spawned per second while a zone is under its cap.
	RefillPerSecond = 2,

	-- Stack value of one pickup, by tier.
	TierValue = table.freeze({
		Normal = 1,
		Golden = 5,
		Corrupted = 25,
	}),

	-- Tiers that may spawn in each zone, keyed by the zone folder name under Workspace.Map.
	ZoneTiers = table.freeze({
		Zone1 = table.freeze({ "Normal" }),
	}),

	-- Studs from the character root at which a pickup is collected, before the
	-- Magnet upgrade. Not set by the GDD; tune in Q-01.
	PickupRadius = 6,
})
