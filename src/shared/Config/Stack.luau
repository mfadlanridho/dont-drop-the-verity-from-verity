--!strict

-- Stack (GDD 4.2).
--
-- Balance values, owned and tuned by the meta agent: BaseCapacity,
-- CapacityPerLevel, WalkSpeedPerLevel, SpeedPenaltyPerWeight, MaxSpeedPenalty.
-- tools/economy_sim.py mirrors them. The rest are feel values, owned by gameplay.
return table.freeze({
	-- Capacity is the total weight a stack can hold (weights are in
	-- Config.Verity.Tiers), before any Capacity upgrade.
	BaseCapacity = 10,
	-- Capacity added per Capacity upgrade level (GDD 4.6).
	CapacityPerLevel = 5,
	-- Orbs rendered on the head, one per Verity held; past this the stack
	-- shows a count billboard.
	VisualCap = 30,

	-- Walk speed before any Speed upgrade.
	BaseWalkSpeed = 16,
	-- Walk speed added per Speed upgrade level (GDD 4.6).
	WalkSpeedPerLevel = 1,
	-- Fraction of walk speed lost per unit of weight carried.
	SpeedPenaltyPerWeight = 0.01,
	-- Ceiling on the total fraction lost.
	MaxSpeedPenalty = 0.4,

	-- Player attributes the server keeps current and every client can read.
	-- Number of Veritys held.
	StackAttribute = "Stack",
	-- Total weight held, and the most the player can hold.
	WeightAttribute = "StackWeight",
	CapacityAttribute = "StackCapacity",
	-- What the stack would bank for right now, Multiplier upgrade included.
	ValueAttribute = "StackValue",
	-- One tier Code per Verity held, bottom of the stack first, e.g. "NNGC".
	TiersAttribute = "StackTiers",
	-- True while a pickup within reach is too heavy to fit.
	RefusedAttribute = "StackRefused",

	-- Head stack visuals. Not set by the GDD. Sized so a full visual stack
	-- (VisualCap orbs) stays under the tower's 36 stud ceilings, jump included.
	-- Stack orb size as a fraction of the Verity model, before the tier's own Scale.
	OrbScale = 0.75,
	-- Studs between the centres of neighbouring stack orbs. Below the orb
	-- diameter (2 * OrbScale) the orbs overlap.
	OrbSpacing = 0.75,
	-- Studs between the top of the head and the bottom of the first orb.
	HeadGap = 0.25,

	-- Stack wobble: the stack bends like a pole whose tip trails the head on
	-- a spring. Visual only. Lean is measured at the top of a full visual
	-- stack; shorter stacks bend less.
	-- Spring pull toward upright. Higher is a faster wobble.
	WobbleStiffness = 56,
	-- Spring drag. Higher settles sooner; 2 * sqrt(WobbleStiffness) never overshoots.
	WobbleDamping = 3.75,
	-- Studs of lean per stud the spring is displaced.
	WobbleGain = 3,
	-- Most the stack can lean, in studs. Starting to run at base speed peaks
	-- near 6.4 with the values above, so keep this higher or the swing is cut short.
	WobbleMaxLean = 8,
	-- Studs of slow sway while standing still.
	IdleSway = 0.35,
	-- Idle sway speed, in radians per second.
	IdleSwaySpeed = 1.5,

	-- Carry animations, played on a character while its stack is above zero:
	-- a relaxed hold that cross-fades into a strained one as the stack fills.
	-- Asset ids of the published animations, owned by the game's group and
	-- uploaded by tools/carry_animation.py. If one is emptied it only plays in
	-- Studio, straight from the KeyframeSequence of the same name under
	-- ReplicatedStorage.Assets.Animations (Carry, Strain).
	CarryAnimationId = "rbxassetid://103959159779590",
	StrainAnimationId = "rbxassetid://98274000309647",
	-- How full the stack is (weight / capacity) when strain starts to show.
	-- It grows from there to full strain at capacity.
	StrainStart = 0.5,
	-- Seconds to blend the animations in, out and between each other.
	CarryFadeSeconds = 0.25,
})
