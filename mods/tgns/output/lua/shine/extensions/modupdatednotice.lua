local MOD_IDS = {"171315805", "117887554"}

local lastKnownUpdate = {}
local changedModName
local md
local announceChangedModInterval = 10

local function announceChangedMod()
	if #TGNS.GetPlayerList() == 0 then
		MapCycle_CycleMap()
	else
		md:ToAllNotifyError(string.format("%s mod has updated in Steam Workshop.", changedModName))
		md:ToAllNotifyError("Players cannot connect to the server until mapchange.")
		TGNS.ScheduleAction(announceChangedModInterval, announceChangedMod)
		announceChangedModInterval = announceChangedModInterval + 10
	end
end

local function getUpdateFromResponse(response)
	local result = nil
	local indexOfUpdatedLabel = TGNS.IndexOf(response, "Update: ")
	if indexOfUpdatedLabel ~= -1 then
		local update = TGNS.Substring(response, indexOfUpdatedLabel)
		local indexOfUpdateEnder = TGNS.IndexOf(update, "</div>")
		if indexOfUpdateEnder ~= -1 then
			update = TGNS.Substring(update, 1, indexOfUpdateEnder - 1)
			update = StringTrim(update)
			result = update
		end
	end
	return result
end

local function getModNameFromResponse(response)
	local result = nil
	local openingTag = "<div class=\"workshopItemTitle\">"
	local closingTag = "</div>"
	local indexOfOpeningTag = TGNS.IndexOf(response, openingTag)
	if indexOfOpeningTag ~= -1 then
		local modName = TGNS.Substring(response, indexOfOpeningTag + string.len(openingTag))
		local indexOfClosingTag = TGNS.IndexOf(modName, closingTag)
		if indexOfClosingTag ~= -1 then
			modName = TGNS.Substring(modName, 1, indexOfClosingTag - 1)
			modName = StringTrim(modName)
			result = modName
		end
	end
	return result
end

local function checkForModChange()
	if not changedModName then
		TGNS.DoFor(MOD_IDS, function(id)
			local url = "http://steamcommunity.com/sharedfiles/filedetails/changelog/" .. id
			TGNS.GetHttpAsync(url, function(response)
				if not changedModName then
					local update = getUpdateFromResponse(response)
					if lastKnownUpdate[id] == nil then
						lastKnownUpdate[id] = update
					elseif lastKnownUpdate[id] ~= update then
						lastKnownUpdate[id] = update
						changedModName = getModNameFromResponse(response)
						announceChangedMod()
					end
				end
			end)
		end)
		TGNS.ScheduleAction(60, checkForModChange)
	end
end

local Plugin = {}

function Plugin:Initialise()
    self.Enabled = true
	md = TGNSMessageDisplayer.Create("MODS")
	checkForModChange()
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc..
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("modupdatednotice", Plugin )