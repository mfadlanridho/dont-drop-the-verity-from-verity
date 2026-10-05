--!strict

-- Pickups (GDD 4.1, 4.8).
return table.freeze({
	-- Max live pickups per zone.
	ZoneCap = 60,
	-- Pickups spawned per second while a zone is under its cap.
	RefillPerSecond = 2,

	-- Value is what one Verity banks for. Weight is what it takes up of the
	-- stack's capacity and what slows the carrier; a Verity is only picked up
	-- if its whole weight fits. Better tiers bank more per unit of weight.
	-- Code is the tier's letter in the StackTiers attribute. Scale and Color
	-- set the orb apart from the Verity model; no Color keeps the model's own.
	Tiers = table.freeze({
		Normal = table.freeze({ Value = 1, Weight = 1, Code = "N", Scale = 1 }),
		Golden = table.freeze({ Value = 5, Weight = 3, Code = "G", Scale = 1.2, Color = Color3.fromRGB(255, 170, 0) }),
		Corrupted = table.freeze({
			Value = 25,
			Weight = 10,
			Code = "C",
			Scale = 1.5,
			Color = Color3.fromRGB(90, 30, 130),
		}),
	}),

	-- Tiers that may spawn in each zone, keyed by the zone folder name under
	-- Workspace.Map. Each spawn picks one of the zone's tiers at random.
	ZoneTiers = table.freeze({
		Zone1 = table.freeze({ "Normal" }),
		Zone2 = table.freeze({ "Normal", "Golden" }),
		Zone3 = table.freeze({ "Golden", "Corrupted" }),
	}),

	-- CollectionService tag on every live pickup. Each also carries `Tier`,
	-- `Value` and `Weight` attributes.
	PickupTag = "VerityPickup",

	-- Spawn placement. None of these are set by the GDD.
	-- Studs from the bottom of the spawn region (ground level) to the orb centre.
	HoverHeight = 2.5,
	-- A spawn point is rejected if any part is within this many studs. Keep it
	-- below HoverHeight or the ground itself rejects every point.
	ClearanceRadius = 2,
	-- Points tried per spawn before giving up until the next refill tick.
	SpawnAttempts = 8,

	-- Studs from the character root at which a pickup is collected, before the
	-- Magnet upgrade. Not set by the GDD; tune in Q-01.
	PickupRadius = 6,
	-- Studs added to the pickup radius per Magnet upgrade level (GDD 4.6).
	PickupRadiusPerLevel = 2,
	-- A carried Verity banks for its value times (1 + this per Multiplier
	-- upgrade level). The multiplier does not change its weight.
	MultiplierPerLevel = 1,
})
