--!strict

-- Stack (GDD 4.2).
return table.freeze({
	-- Max stack before any Capacity upgrade.
	BaseCapacity = 10,
	-- Capacity added per Capacity upgrade level (GDD 4.6).
	CapacityPerLevel = 5,
	-- Orbs rendered on the head; past this the stack shows a count billboard.
	VisualCap = 30,

	-- Walk speed before any Speed upgrade.
	BaseWalkSpeed = 16,
	-- Walk speed added per Speed upgrade level (GDD 4.6).
	WalkSpeedPerLevel = 1,
	-- Fraction of walk speed lost per stacked Verity.
	SpeedPenaltyPerVerity = 0.01,
	-- Ceiling on the total fraction lost.
	MaxSpeedPenalty = 0.4,

	-- Player attributes the server keeps current and every client can read.
	StackAttribute = "Stack",
	CapacityAttribute = "StackCapacity",

	-- Head stack visuals. Not set by the GDD. Sized so a full visual stack
	-- (VisualCap orbs) stays under the tower's 36 stud ceilings, jump included.
	-- Stack orb size as a fraction of the Verity model.
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

	-- Carry animation, played on a character while its stack is above zero.
	-- Asset id of the published animation, e.g. "rbxassetid://123". While it
	-- is empty the animation only plays in Studio, straight from the
	-- KeyframeSequence at ReplicatedStorage.Assets.Animations.Carry.
	CarryAnimationId = "",
	-- Seconds to blend the arms in and out.
	CarryFadeSeconds = 0.25,
})
