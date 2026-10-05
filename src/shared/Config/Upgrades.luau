--!strict

-- Upgrade prices (GDD 4.6). What a level does lives with the system it
-- changes: Config.Stack (Capacity, Speed) and Config.Verity (Magnet, Multiplier).
--
-- The price of the next level is BaseCost * CostGrowth ^ currentLevel, rounded
-- by Economy.RoundPrice. tools/economy_sim.py mirrors these numbers; change
-- both together and rerun it to check pacing.
return table.freeze({
	Upgrades = table.freeze({
		Capacity = table.freeze({ BaseCost = 10, CostGrowth = 1.22, MaxLevel = 40 }),
		Speed = table.freeze({ BaseCost = 25, CostGrowth = 1.45, MaxLevel = 10 }),
		Magnet = table.freeze({ BaseCost = 20, CostGrowth = 1.45, MaxLevel = 10 }),
		Multiplier = table.freeze({ BaseCost = 50, CostGrowth = 2, MaxLevel = 9 }),
	}),

	-- Display order in the shop.
	Order = table.freeze({ "Capacity", "Speed", "Magnet", "Multiplier" }),

	-- Shortest time between one player's purchase requests, in seconds.
	PurchaseCooldown = 0.1,
})
