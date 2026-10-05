--!strict

-- Plays the carry animation on the local character while its stack is above
-- zero. Animations played on your own character replicate to everyone else,
-- so each client only drives itself.

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Stack"))

local player = Players.LocalPlayer

local CarryController = {}

local animation: Animation?
local track: AnimationTrack?

-- The published asset, or in Studio a temporary id for the unpublished
-- KeyframeSequence so the animation can be previewed before it is uploaded.
local function resolveAnimationId(): string?
	if Config.CarryAnimationId ~= "" then
		return Config.CarryAnimationId
	end
	if not RunService:IsStudio() then
		return nil
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Animations")
	local sequence = folder and folder:FindFirstChild("Carry")
	if sequence and sequence:IsA("KeyframeSequence") then
		return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
	end
	return nil
end

local function update()
	local current = track
	if not current then
		return
	end

	local stack = player:GetAttribute(Config.StackAttribute)
	local carrying = typeof(stack) == "number" and stack > 0
	if carrying and not current.IsPlaying then
		current:Play(Config.CarryFadeSeconds)
	elseif not carrying and current.IsPlaying then
		current:Stop(Config.CarryFadeSeconds)
	end
end

local function onCharacter(character: Model)
	track = nil
	local source = animation
	if not source then
		return
	end

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local animator = humanoid:WaitForChild("Animator") :: Animator
	if player.Character ~= character then
		return
	end

	local loaded = animator:LoadAnimation(source)
	loaded.Priority = Enum.AnimationPriority.Action
	loaded.Looped = true
	track = loaded
	update()
end

function CarryController.Init()
	local id = resolveAnimationId()
	if not id then
		warn("CarryController: no carry animation; set Config.Stack.CarryAnimationId")
		return
	end
	local created = Instance.new("Animation")
	created.AnimationId = id
	animation = created
end

function CarryController.Start()
	player:GetAttributeChangedSignal(Config.StackAttribute):Connect(update)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

return CarryController
