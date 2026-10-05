-- Builds the stack carry animation as a KeyframeSequence at
-- ReplicatedStorage.Assets.Animations.Carry, replacing any existing one.
-- Not synced by Rojo: paste into the Studio command bar (edit mode) to
-- rebuild after changing the numbers, then save the place. To ship it, the
-- sequence must be published from the game owner's account (right-click it,
-- Save to Roblox) and its asset id put in Config.Stack.CarryAnimationId.
--
-- R15 only. Both arms reach up to steady the bottom orb and rock gently from
-- side to side. Only the arms are keyed, so walk, idle and jump show through.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Shoulder: how far the upper arm swings up from hanging (180 is straight up).
local RAISE = math.rad(165)
-- Shoulder: how far the raised arm leans in toward the head.
local TILT = math.rad(22)
-- Elbow bend, bringing the hands in over the head.
local ELBOW = math.rad(20)
-- How far the arms rock to each side.
local SWAY = math.rad(4)
local LENGTH = 1.2

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

-- `side` is 1 for the right arm and -1 for the left; `phase` runs -1 to 1.
local function arm(prefix: string, side: number, phase: number, torso: Pose)
	local sway = SWAY * phase
	local upper = pose(
		prefix .. "UpperArm",
		torso,
		CFrame.Angles(0, 0, side * TILT + sway) * CFrame.Angles(RAISE, 0, 0)
	)
	local lower = pose(prefix .. "LowerArm", upper, CFrame.Angles(ELBOW + side * sway, 0, 0))
	pose(prefix .. "Hand", lower, CFrame.identity)
end

local sequence = Instance.new("KeyframeSequence")
sequence.Name = "Carry"
sequence.Loop = true
sequence.Priority = Enum.AnimationPriority.Action

for index, phase in { 0, 1, 0, -1, 0 } do
	local keyframe = Instance.new("Keyframe")
	keyframe.Time = (index - 1) / 4 * LENGTH
	local root = pose("HumanoidRootPart", keyframe)
	local torso = pose("UpperTorso", pose("LowerTorso", root))
	arm("Right", 1, phase, torso)
	arm("Left", -1, phase, torso)
	keyframe.Parent = sequence
end

local assets = ReplicatedStorage:FindFirstChild("Assets")
assert(assets, "ReplicatedStorage.Assets is missing")
local folder = assets:FindFirstChild("Animations")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Animations"
	folder.Parent = assets
end
local existing = folder:FindFirstChild(sequence.Name)
if existing then
	existing:Destroy()
end
sequence.Parent = folder
return sequence:GetFullName()
