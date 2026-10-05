--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loader = require(Shared.Loader)

-- Create every remote before any client can ask for one.
require(Shared.Remotes)

Loader.Run(script:FindFirstChild("Services"))
