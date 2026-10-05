--!strict

-- Point-in-box tests against map volumes such as the bank zone and safe zone.

local Region = {}

-- Whether `position` is inside any of the box-shaped `parts`.
function Region.Contains(parts: { BasePart }, position: Vector3): boolean
	for _, part in parts do
		local offset = part.CFrame:PointToObjectSpace(position)
		local half = part.Size / 2
		if math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z then
			return true
		end
	end
	return false
end

-- Every BasePart carrying the CollectionService `tag`.
function Region.Tagged(tag: string): { BasePart }
	local parts: { BasePart } = {}
	for _, instance in game:GetService("CollectionService"):GetTagged(tag) do
		if instance:IsA("BasePart") then
			table.insert(parts, instance)
		end
	end
	return parts
end

return Region
