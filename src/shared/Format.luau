--!strict

local Format = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi" }

-- 950 -> "950", 1250 -> "1.25K", 12500 -> "12.5K", 3400000 -> "3.4M".
-- Three significant digits, rounded down so a price never reads as affordable early.
function Format.Number(value: number): string
	if value < 1000 then
		return tostring(math.floor(value))
	end
	local index = math.min(math.floor(math.log10(value) / 3), #SUFFIXES)
	local scaled = value / 1000 ^ index
	local decimals = if scaled >= 100 then 0 elseif scaled >= 10 then 1 else 2
	local factor = 10 ^ decimals
	-- The epsilon absorbs float error such as 1250 / 1000 * 100 = 124.99999.
	local text = string.format(`%.{decimals}f`, math.floor(scaled * factor + 1e-6) / factor)
	if decimals > 0 then
		text = string.gsub(string.gsub(text, "0+$", ""), "%.$", "")
	end
	return text .. SUFFIXES[index]
end

return Format
