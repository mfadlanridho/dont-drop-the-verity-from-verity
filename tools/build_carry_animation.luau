-- Builds the stack carry animations as KeyframeSequences under
-- ReplicatedStorage.Assets.Animations (Carry and Strain), replacing any
-- existing ones. Not synced by Rojo: paste into the Studio command bar (edit
-- mode) to rebuild after changing the numbers, then save the place. These
-- copies are for previewing only: the game plays the published assets, which
-- tools/carry_animation.py builds and uploads. Keep the pose numbers in step.
--
-- R15 only. Only the upper body is keyed, so walk, idle and jump show through.
-- Carry: both arms reach up to steady the bottom orb and rock gently.
-- Strain: the same hold with the torso hunched, the head tucked and the arms
-- trembling. CarryController cross-fades from Carry to Strain as the stack fills.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Angles in degrees.
-- Raise: how far the upper arm swings up from hanging (180 is straight up the torso).
-- Tilt: how far the raised arm leans in toward the head.
-- Elbow: elbow bend, bringing the hands in over the head.
-- Sway: how far the arms rock to each side over one loop.
-- Lean: how far the torso hunches forward. Tuck: how far the head drops.
local ANIMATIONS = {
	Carry = { Length = 1.2, Raise = 165, Tilt = 22, Elbow = 20, Sway = 4, Lean = 0, Tuck = 0 },
	Strain = { Length = 0.3, Raise = 152, Tilt = 26, Elbow = 30, Sway = 2.5, Lean = 14, Tuck = 12 },
}

local function pose(name: string, parent: Instance, cframe: CFrame?): Pose
	local created = Instance.new("Pose")
	created.Name = name
	-- Weight 0 leaves a joint to whatever else is playing.
	created.Weight = if cframe then 1 else 0
	created.CFrame = cframe or CFrame.identity
	created.EasingStyle = Enum.PoseEasingStyle.Cubic
	created.EasingDirection = Enum.PoseEasingDirection.InOut
	created.Parent = parent
	return created
end

local function build(name: string, spec)
	local raise, tilt, elbow = math.rad(spec.Raise), math.rad(spec.Tilt), math.rad(spec.Elbow)

	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = name
	sequence.Loop = true
	sequence.Priority = Enum.AnimationPriority.Action

	for index, phase in { 0, 1, 0, -1, 0 } do
		local sway = math.rad(spec.Sway) * phase
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = (index - 1) / 4 * spec.Length

		local root = pose("HumanoidRootPart", keyframe)
		local torso = pose(
			"UpperTorso",
			pose("LowerTorso", root),
			if spec.Lean ~= 0 then CFrame.Angles(-math.rad(spec.Lean), 0, 0) else nil
		)
		if spec.Tuck ~= 0 then
			pose("Head", torso, CFrame.Angles(-math.rad(spec.Tuck), 0, 0))
		end
		-- `side` is 1 for the right arm and -1 for the left.
		for prefix, side in { Right = 1, Left = -1 } do
			local upper = pose(
				prefix .. "UpperArm",
				torso,
				CFrame.Angles(0, 0, side * tilt + sway) * CFrame.Angles(raise, 0, 0)
			)
			local lower = pose(prefix .. "LowerArm", upper, CFrame.Angles(elbow + side * sway, 0, 0))
			pose(prefix .. "Hand", lower, CFrame.identity)
		end
		keyframe.Parent = sequence
	end
	return sequence
end

local assets = ReplicatedStorage:FindFirstChild("Assets")
assert(assets, "ReplicatedStorage.Assets is missing")
local folder = assets:FindFirstChild("Animations")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Animations"
	folder.Parent = assets
end
for name, spec in ANIMATIONS do
	local existing = folder:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	build(name, spec).Parent = folder
end
return "built Carry and Strain"
