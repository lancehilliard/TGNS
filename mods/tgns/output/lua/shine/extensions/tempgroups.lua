local originalIsInGroup
local tempGroups = {}

function Shine:AddTempGroup(client, groupName)
	tempGroups[groupName] = tempGroups[groupName] or {}
	tempGroups[groupName][client] = TGNS.GetSecondsSinceEpoch()
end

function Shine:RemoveTempGroup(client, groupName)
	tempGroups[groupName] = tempGroups[groupName] or {}
	tempGroups[groupName][client] = nil
end

local Plugin = {}

function Plugin:Initialise()
    self.Enabled = true
	originalIsInGroup = TGNS.ReplaceClassMethod("Shine", "IsInGroup", function(self, client, groupName)
		local isInTempGroup = tempGroups[groupName] and tempGroups[groupName][client]
		local result = originalIsInGroup(self, client, groupName) or isInTempGroup
		return result
	end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("tempgroups", Plugin )