--!strict

-- Player data (GDD 4.6, 4.7, 7).
return table.freeze({
	-- A new player's profile. Bump Version when a field changes meaning; a new
	-- field only needs a default here, DataService fills it into older profiles.
	Template = table.freeze({
		Version = 1,
		-- Spendable currency.
		Banked = 0,
		-- Lifetime banked Veritys; never reset, feeds the leaderboard.
		TotalBanked = 0,
		Rebirths = 0,
		-- Largest stack ever banked in one trip.
		TallestStack = 0,
		-- Level per upgrade, 0 = not bought.
		Upgrades = table.freeze({
			Capacity = 0,
			Speed = 0,
			Magnet = 0,
			Multiplier = 0,
		}),
	}),

	-- Top-level number fields mirrored to Player attributes of the same name,
	-- so the client can read them without a remote.
	ReplicatedFields = table.freeze({ "Banked", "TotalBanked", "Rebirths", "TallestStack" }),
	-- Upgrade levels are mirrored as this prefix plus the upgrade id, e.g. `UpgradeCapacity`.
	UpgradeAttributePrefix = "Upgrade",
	-- Player attribute set to true once the profile is ready to read.
	LoadedAttribute = "DataLoaded",
})
