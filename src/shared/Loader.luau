--!strict

local Types = require(script.Parent.Types)

local Loader = {}

-- Requires every ModuleScript directly under `folder`, calls each Init in name
-- order, then spawns each Start. An error in require or Init stops the boot.
function Loader.Run(folder: Instance?)
	if not folder then
		return
	end

	local children = folder:GetChildren()
	table.sort(children, function(a, b)
		return a.Name < b.Name
	end)

	local modules: { Types.Module } = {}
	for _, child in children do
		if child:IsA("ModuleScript") then
			table.insert(modules, (require :: any)(child))
		end
	end

	for _, module in modules do
		if module.Init then
			module.Init()
		end
	end

	for _, module in modules do
		if module.Start then
			task.spawn(module.Start)
		end
	end
end

return Loader
