--!strict

-- A service (server) or controller (client). Every Init runs before any Start,
-- so Init must not depend on another module's state; Start may.
export type Module = {
	Init: (() -> ())?,
	Start: (() -> ())?,
}

export type VerityTier = "Normal" | "Golden" | "Corrupted"

export type GuardianState = "Idle" | "Hunting" | "Chasing" | "Attacking" | "Cooldown"

return nil
