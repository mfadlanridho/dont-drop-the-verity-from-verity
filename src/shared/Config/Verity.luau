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

	-- CollectionService tag on every live pickup. Each also carries `Tier` and
	-- `Value` attributes.
	PickupTag = "VerityPickup",

	-- Spawn placement. None of these are set by the GDD.
	-- Studs from the bottom of the spawn region (ground level) to the orb centre.
	HoverHeight = 2.5,
	-- A spawn point is rejected if any part is within this many studs. Keep it
	-- below HoverHeight or the ground itself rejects every point.
	ClearanceRadius = 2,
	-- Points tried per spawn before giving up until the next refill tick.
	SpawnAttempts = 8,
	-- Diameter of the stand-in orb used until ReplicatedStorage.Assets.Verity exists.
	PlaceholderDiameter = 3,

	-- Studs from the character root at which a pickup is collected, before the
	-- Magnet upgrade. Not set by the GDD; tune in Q-01.
	PickupRadius = 6,
	-- Studs added to the pickup radius per Magnet upgrade level (GDD 4.6).
	PickupRadiusPerLevel = 2,
	-- A pickup is worth its value times (1 + this per Multiplier upgrade level).
	MultiplierPerLevel = 1,
})
