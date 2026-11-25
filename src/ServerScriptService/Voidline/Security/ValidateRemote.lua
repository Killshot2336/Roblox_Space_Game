local ValidateRemote = {}

function ValidateRemote.AlivePlayer(player: Player?): boolean
	return player ~= nil and player.Parent ~= nil and player.Character ~= nil
end

function ValidateRemote.OwnsPlot(player: Player, plotIndex: number, plotOwners: { [number]: Player }): boolean
	return plotOwners[plotIndex] == player
end

function ValidateRemote.NearPart(player: Player, part: BasePart, maxDistance: number): boolean
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return false
	end
	return (hrp.Position - part.Position).Magnitude <= maxDistance
end

return ValidateRemote
