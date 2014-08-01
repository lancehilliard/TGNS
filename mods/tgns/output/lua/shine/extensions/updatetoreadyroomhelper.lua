local updatingToReadyRoom = {}

local Plugin = {}

function Plugin:IsServerUpdatingToReadyRoom()
	return updatingToReadyRoom
end

function Plugin:Initialise()
    self.Enabled = true
	local originalUpdateToReadyRoom
	originalUpdateToReadyRoom = TGNS.ReplaceClassMethod("NS2Gamerules", "UpdateToReadyRoom", function(gamerules)
		updatingToReadyRoom = true
		originalUpdateToReadyRoom(gamerules)
		updatingToReadyRoom = false
	end)

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("updatetoreadyroomhelper", Plugin )