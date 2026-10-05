--!strict

-- The single place that defines every RemoteEvent and RemoteFunction.
-- The server creates the instances on first require; clients wait for them.
-- To add a remote, add one line to the table at the bottom.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

-- The server reuses anything that already exists, so a second require from
-- another module cache (the command bar, a plugin) cannot duplicate remotes.
local function findOrCreate(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent
	return created
end

local folder: Instance
if RunService:IsServer() then
	folder = findOrCreate(ReplicatedStorage, "Folder", FOLDER_NAME)
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local function get(className: string, name: string): Instance
	if RunService:IsServer() then
		return findOrCreate(folder, className, name)
	end
	return folder:WaitForChild(name)
end

local function event(name: string): RemoteEvent
	return get("RemoteEvent", name) :: RemoteEvent
end

local function func(name: string): RemoteFunction
	return get("RemoteFunction", name) :: RemoteFunction
end

return {
	-- Server -> targeted client. (isHunted: boolean) when a Guardian chase on them starts or ends.
	GuardianHunt = event("GuardianHunt"),
	-- Server -> hit client. (dropped: number) after a Guardian hit spills part of their stack.
	StackDropped = event("StackDropped"),
	-- Server -> banking client. (value: number, count: number) after their stack is banked:
	-- the banked Veritys credited and how many Veritys the stack held.
	StackBanked = event("StackBanked"),
	-- Client -> server. (upgradeId: string) -> (bought: boolean, reason: string?). Buys one
	-- level at the server's price. Reasons: "Invalid", "NotLoaded", "MaxLevel", "CannotAfford", "TooFast".
	BuyUpgrade = func("BuyUpgrade"),
}
