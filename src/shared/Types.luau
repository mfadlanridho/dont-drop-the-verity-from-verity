--!strict

-- A service (server) or controller (client). Every Init runs before any Start,
-- so Init must not depend on another module's state; Start may.
export type Module = {
	Init: (() -> ())?,
	Start: (() -> ())?,
}

export type VerityTier = "Normal" | "Golden" | "Corrupted"

export type GuardianState = "Idle" | "Hunting" | "Chasing" | "Attacking" | "Cooldown"

export type UpgradeId = "Capacity" | "Speed" | "Magnet" | "Multiplier"

-- A player's saved data. Defaults live in Config.Data.Template.
export type Profile = {
	Version: number,
	Banked: number,
	TotalBanked: number,
	Rebirths: number,
	TallestStack: number,
	Upgrades: { [UpgradeId]: number },
}

return nil
