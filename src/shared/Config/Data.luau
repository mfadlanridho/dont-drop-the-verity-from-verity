--!strict

-- Player data (GDD 4.6, 4.7, 7).
return table.freeze({
	-- DataStore that holds live player profiles. Renaming it abandons every save.
	StoreName = "PlayerData",
	-- Studio play sessions save here instead, so testing never touches live profiles.
	StudioStoreName = "PlayerData_Studio",
	-- Profile key is this prefix plus the UserId.
	KeyPrefix = "Player_",

	-- A new player's profile. A new field only needs a default here; it is
	-- filled into older profiles on load. When a field changes meaning, bump
	-- Version and add the matching step to MIGRATIONS in DataService.
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
