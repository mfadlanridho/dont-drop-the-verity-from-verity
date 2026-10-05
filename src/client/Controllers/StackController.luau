--!strict

-- Renders every player's stack on their head (GDD 4.2). The size comes from
-- the Player attribute StackService keeps current; this only draws it. Past
-- the visual cap no more orbs are added and a count billboard appears instead.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Stack"))

local STACK_FOLDER_NAME = "VerityStack"
local TEMPLATE_WAIT_SECONDS = 10
local HEAD_WAIT_SECONDS = 10
-- Studs.
local BILLBOARD_SIZE = Vector2.new(5, 2)

type Visual = {
	head: BasePart,
	folder: Folder,
	orbs: { Model },
	billboard: BillboardGui,
	label: TextLabel,
}

local StackController = {}

local template: Model?
local orbRadius = 0
local visuals: { [Player]: Visual } = {}

-- Height of the centre of the orb at `index`, above the centre of the head.
local function orbHeight(head: BasePart, index: number): number
	return head.Size.Y / 2 + Config.HeadGap + orbRadius + (index - 1) * Config.OrbSpacing
end

local function createOrb(head: BasePart, index: number): Model?
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

	-- The template is an anchored world pickup; a stack orb rides the head
	-- and must not affect the character's physics or anyone's queries.
	for _, part in orb:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
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

	local weld = Instance.new("Weld")
	weld.Part0 = head
	weld.Part1 = primary
	weld.C0 = CFrame.new(0, orbHeight(head, index), 0)
	weld.Parent = primary
	return orb
end

local function createVisual(head: BasePart): Visual
	local folder = Instance.new("Folder")
	folder.Name = STACK_FOLDER_NAME

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Count"
	billboard.Adornee = head
	billboard.Size = UDim2.fromScale(BILLBOARD_SIZE.X, BILLBOARD_SIZE.Y)
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
	return { head = head, folder = folder, orbs = {}, billboard = billboard, label = label }
end

local function render(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	local visual = visuals[player]
	if not visual or visual.head ~= head or not visual.folder.Parent then
		visual = createVisual(head)
		visuals[player] = visual
	end

	local stack = player:GetAttribute(Config.StackAttribute)
	local size = if typeof(stack) == "number" then stack else 0
	local shown = math.min(size, Config.VisualCap)

	for index = #visual.orbs + 1, shown do
		local orb = createOrb(head, index)
		if not orb then
			break
		end
		orb.Parent = visual.folder
		visual.orbs[index] = orb
	end
	for index = #visual.orbs, shown + 1, -1 do
		visual.orbs[index]:Destroy()
		visual.orbs[index] = nil
	end

	visual.billboard.Enabled = size > Config.VisualCap
	visual.label.Text = tostring(size)
	visual.billboard.StudsOffsetWorldSpace =
		Vector3.new(0, orbHeight(head, #visual.orbs) + orbRadius + BILLBOARD_SIZE.Y / 2, 0)
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
end

return StackController
