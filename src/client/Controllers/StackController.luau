--!strict

-- Renders every player's stack on their head (GDD 4.2). The size comes from
-- the Player attribute StackService keeps current; this only draws it. Past
-- the visual cap no more orbs are added and a count billboard appears instead.
--
-- The orbs are anchored and placed every frame so the stack can wobble: it
-- bends like a pole whose tip trails the head on a spring.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Stack"))

local STACK_FOLDER_NAME = "VerityStack"
local TEMPLATE_WAIT_SECONDS = 10
local HEAD_WAIT_SECONDS = 10
-- Studs.
local BILLBOARD_SIZE = Vector2.new(5, 2)
-- The spring is advanced in steps no longer than this, so it stays stable and
-- keeps real time at low frame rates.
local SPRING_STEP = 1 / 60
-- Longest frame the spring tries to catch up on after a hitch.
local MAX_FRAME_TIME = 0.25
-- Height of the orb column in a full visual stack; lean is measured at its top.
local FULL_HEIGHT = math.max(Config.VisualCap - 1, 1) * Config.OrbSpacing

type Visual = {
	head: BasePart,
	folder: Folder,
	orbs: { Model },
	-- Each orb's PrimaryPart and its CFrame this frame, index-matched with `orbs`.
	parts: { BasePart },
	cframes: { CFrame },
	billboard: BillboardGui,
	label: TextLabel,
	-- Horizontal world position of the spring that the top of the stack follows.
	tip: Vector3,
	tipVelocity: Vector3,
	-- Offsets the idle sway so stacks do not move in unison.
	phase: number,
}

local StackController = {}

local template: Model?
local orbRadius = 0
local visuals: { [Player]: Visual } = {}

local function flatten(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- Height of the centre of the orb at `index`, above the centre of the head.
local function orbHeight(head: BasePart, index: number): number
	return head.Size.Y / 2 + Config.HeadGap + orbRadius + (index - 1) * Config.OrbSpacing
end

local function createOrb(): Model?
	local source = template
	if not source then
		return nil
	end

	local orb = source:Clone()
	local primary = orb.PrimaryPart
	if not primary then
		orb:Destroy()
		return nil
	end

	-- The PrimaryPart stays anchored and is moved each frame; anything else in
	-- the model rides it. Nothing in a stack orb takes part in physics or queries.
	for _, part in orb:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = part == primary
			part.Massless = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			if part ~= primary then
				local constraint = Instance.new("WeldConstraint")
				constraint.Part0 = primary
				constraint.Part1 = part
				constraint.Parent = part
			end
		end
	end
	return orb
end

local function createVisual(player: Player, head: BasePart): Visual
	local folder = Instance.new("Folder")
	folder.Name = STACK_FOLDER_NAME

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Count"
	billboard.Size = UDim2.fromScale(BILLBOARD_SIZE.X, BILLBOARD_SIZE.Y)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, orbRadius + BILLBOARD_SIZE.Y / 2, 0)
	billboard.Enabled = false
	billboard.Parent = folder

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = billboard

	-- Inside the character, so it is cleaned up with it on respawn.
	folder.Parent = head.Parent
	return {
		head = head,
		folder = folder,
		orbs = {},
		parts = {},
		cframes = {},
		billboard = billboard,
		label = label,
		tip = flatten(head.Position),
		tipVelocity = Vector3.zero,
		phase = player.UserId % 628 / 100,
	}
end

-- Advances the spring and returns how far the top of a full stack leans.
local function stepSpring(visual: Visual, dt: number, now: number): Vector3
	local anchor = flatten(visual.head.Position)
	local remaining = math.min(dt, MAX_FRAME_TIME)
	while remaining > 0 do
		local step = math.min(remaining, SPRING_STEP)
		remaining -= step
		local acceleration = (anchor - visual.tip) * Config.WobbleStiffness
			- visual.tipVelocity * Config.WobbleDamping
		visual.tipVelocity += acceleration * step
		visual.tip += visual.tipVelocity * step
	end

	-- Also catches teleports, which would otherwise whip the stack across the map.
	local displacement = visual.tip - anchor
	local limit = Config.WobbleMaxLean / Config.WobbleGain
	if displacement.Magnitude > limit then
		displacement = displacement.Unit * limit
		visual.tip = anchor + displacement
		-- Carry the tip along with the head. Stopping it dead would leave it
		-- pinned at the limit for as long as the player keeps moving.
		visual.tipVelocity = flatten(visual.head.AssemblyLinearVelocity)
	end

	local angle = now * Config.IdleSwaySpeed + visual.phase
	local idle = Vector3.new(math.sin(angle), 0, math.cos(angle * 0.7)) * Config.IdleSway
	return displacement * Config.WobbleGain + idle
end

local function place(visual: Visual, dt: number, now: number)
	local count = #visual.parts
	local head = visual.head
	if count == 0 or not head:IsDescendantOf(Workspace) then
		return
	end

	local lean = stepSpring(visual, dt, now)
	local origin = head.Position
	local look = flatten(head.CFrame.LookVector)
	look = if look.Magnitude > 0.01 then look.Unit else -Vector3.zAxis

	for index = 1, count do
		-- 0 at the head, 1 at the top of a full stack. Squared, so the base
		-- stays planted and the top swings the most.
		local fraction = (index - 1) * Config.OrbSpacing / FULL_HEIGHT
		local position = origin + Vector3.yAxis * orbHeight(head, index) + lean * (fraction * fraction)
		-- Tilt each orb along the curve so the faces lean with the stack.
		local up = (Vector3.yAxis + lean * (2 * fraction / FULL_HEIGHT)).Unit
		local right = look:Cross(up).Unit
		visual.cframes[index] = CFrame.fromMatrix(position, right, up, right:Cross(up))
	end

	Workspace:BulkMoveTo(visual.parts, visual.cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

local function render(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	local visual = visuals[player]
	if not visual or visual.head ~= head or not visual.folder.Parent then
		visual = createVisual(player, head)
		visuals[player] = visual
	end

	local stack = player:GetAttribute(Config.StackAttribute)
	local size = if typeof(stack) == "number" then stack else 0
	local shown = math.min(size, Config.VisualCap)

	for index = #visual.orbs + 1, shown do
		local orb = createOrb()
		if not orb then
			break
		end
		local primary = orb.PrimaryPart :: BasePart
		-- Start in place; the next frame applies the wobble.
		primary.CFrame = CFrame.new(head.Position + Vector3.yAxis * orbHeight(head, index))
		orb.Parent = visual.folder
		visual.orbs[index] = orb
		visual.parts[index] = primary
		visual.cframes[index] = primary.CFrame
	end
	for index = #visual.orbs, shown + 1, -1 do
		visual.orbs[index]:Destroy()
		visual.orbs[index] = nil
		visual.parts[index] = nil
		visual.cframes[index] = nil
	end

	-- The count rides the top orb, so it sways with the stack.
	visual.billboard.Adornee = visual.parts[#visual.parts] or head
	visual.billboard.Enabled = size > Config.VisualCap
	visual.label.Text = tostring(size)
end

local function onCharacter(player: Player, character: Model)
	if character:WaitForChild("Head", HEAD_WAIT_SECONDS) and player.Character == character then
		render(player)
	end
end

local function track(player: Player)
	player:GetAttributeChangedSignal(Config.StackAttribute):Connect(function()
		render(player)
	end)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

function StackController.Init()
	local assets = ReplicatedStorage:WaitForChild("Assets", TEMPLATE_WAIT_SECONDS)
	local found = assets and assets:WaitForChild("Verity", TEMPLATE_WAIT_SECONDS)
	if found and found:IsA("Model") and found.PrimaryPart then
		local scaled = found:Clone()
		scaled:ScaleTo(Config.OrbScale)
		template = scaled
		orbRadius = (scaled.PrimaryPart :: BasePart).Size.Y / 2
	else
		warn("StackController: ReplicatedStorage.Assets.Verity is missing or has no PrimaryPart; stacks will show no orbs")
	end
end

function StackController.Start()
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		visuals[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		track(player)
	end

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		for _, visual in visuals do
			place(visual, dt, now)
		end
	end)
end

return StackController
