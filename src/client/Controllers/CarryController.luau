--!strict

-- Plays the carry animations on the local character while its stack is above
-- zero: a relaxed hold that cross-fades into a strained one as the stack
-- fills. Animations played on your own character replicate to everyone else,
-- so each client only drives itself.

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Stack"))

-- A track at weight 0 stops contributing and can pop when it comes back.
local MIN_WEIGHT = 0.01

local player = Players.LocalPlayer

local CarryController = {}

local carryAnimation: Animation?
local strainAnimation: Animation?
local carryTrack: AnimationTrack?
local strainTrack: AnimationTrack?

-- The published asset, or in Studio a temporary id for the unpublished
-- KeyframeSequence of that name so it can be previewed before it is uploaded.
local function createAnimation(assetId: string, name: string): Animation?
	local id: string? = if assetId ~= "" then assetId else nil
	if not id and RunService:IsStudio() then
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local folder = assets and assets:FindFirstChild("Animations")
		local sequence = folder and folder:FindFirstChild(name)
		if sequence and sequence:IsA("KeyframeSequence") then
			id = KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
		end
	end
	if not id then
		warn(`CarryController: no {name} animation; set its id in Config.Stack`)
		return nil
	end

	local animation = Instance.new("Animation")
	animation.Name = name
	animation.AnimationId = id
	return animation
end

local function number(attribute: string): number
	local value = player:GetAttribute(attribute)
	return if typeof(value) == "number" then value else 0
end

-- Plays `track` at `weight`, or stops it when the weight is zero.
local function blend(track: AnimationTrack?, weight: number)
	if not track then
		return
	end
	if weight <= 0 then
		if track.IsPlaying then
			track:Stop(Config.CarryFadeSeconds)
		end
	elseif track.IsPlaying then
		track:AdjustWeight(weight, Config.CarryFadeSeconds)
	else
		track:Play(Config.CarryFadeSeconds, weight)
	end
end

local function update()
	local weight = number(Config.WeightAttribute)
	local capacity = number(Config.CapacityAttribute)
	if weight <= 0 or capacity <= 0 then
		blend(carryTrack, 0)
		blend(strainTrack, 0)
		return
	end

	-- 0 until the stack is StrainStart full, rising to 1 at capacity.
	local strain = if strainTrack
		then math.clamp((weight / capacity - Config.StrainStart) / (1 - Config.StrainStart), 0, 1)
		else 0
	blend(carryTrack, math.max(1 - strain, MIN_WEIGHT))
	blend(strainTrack, strain)
end

local function load(animator: Animator, animation: Animation?): AnimationTrack?
	if not animation then
		return nil
	end
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	return track
end

local function onCharacter(character: Model)
	carryTrack = nil
	strainTrack = nil

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local animator = humanoid:WaitForChild("Animator") :: Animator
	if player.Character ~= character then
		return
	end

	carryTrack = load(animator, carryAnimation)
	strainTrack = load(animator, strainAnimation)
	update()
end

function CarryController.Init()
	carryAnimation = createAnimation(Config.CarryAnimationId, "Carry")
	strainAnimation = createAnimation(Config.StrainAnimationId, "Strain")
end

function CarryController.Start()
	player:GetAttributeChangedSignal(Config.WeightAttribute):Connect(update)
	player:GetAttributeChangedSignal(Config.CapacityAttribute):Connect(update)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

return CarryController
