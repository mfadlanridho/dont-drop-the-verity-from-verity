--!strict

-- Return pads on the upper floors. Not in the GDD yet.
return table.freeze({
	-- Seconds a character must stay on a pad before it is sent to the lobby.
	-- 0 makes the pad instant.
	ChannelSeconds = 1.5,
	-- Studs above the pad surface that still count as on it, so a jump does
	-- not cancel the channel.
	MaxHeightAbovePad = 12,
	-- Player attribute holding the server time (Workspace:GetServerTimeNow) at
	-- which the teleport fires; absent while the player is not on a pad.
	ChannelAttribute = "ReturnAt",
})
