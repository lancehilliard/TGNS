local originalIsInGroup
local tempGroups = {}

local Plugin = {}

function Plugin:AddTempGroup(client, groupName)
	tempGroups[groupName] = tempGroups[groupName] or {}
	tempGroups[groupName][client] = TGNS.GetSecondsSinceEpoch()
end

function Plugin:RemoveTempGroup(client, groupName)
	tempGroups[groupName] = tempGroups[groupName] or {}
	tempGroups[groupName][client] = nil
end

function Plugin:Initialise()
    self.Enabled = true
	originalIsInGroup = TGNS.ReplaceClassMethod("Shine", "IsInGroup", function(self, client, groupName)
		local isInTempGroup = tempGroups[groupName] ~= nil and tempGroups[groupName][client] ~= nil
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