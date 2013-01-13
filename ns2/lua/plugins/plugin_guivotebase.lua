//NS2 Vote Base GUI Implementation

local kRunningVotes = { }

//GUIMenuBase
//OnVoteFunction(client, OptionSelected)
//OnVoteUpdateFunction(ClientGameID, kVoteBaseUpdateMessage)

//Need to investigate what happens when network message is sent to client that client has no information regarding - can they even connect to the server, and does it cause errors?
//If it will work without clients having that specific message, then this can be an optional install on clients/not cause too many problems with consistency checks and modded server flags.
//Would need a reasonable amount of additional dev time to update voting related plugins to optionally use the GUI.  Need to make sure consistency is maintained with text commands still working.

if kDAKConfig and kDAKConfig.GUIMenuBase then
	
	function CreateGUIVoteBase(id, VoteFunction, VoteUpdateFunction)
		if id == nil or id == 0 or tonumber(id) == nil then return false end
		for i = #kRunningVotes, 1, -1 do
			if kRunningVotes[i] ~= nil and kRunningVotes[i].clientGameId == id then
				return false
			end
		end
		local GameVote = {UpdateTime = 0, OnVoteFunction = VoteFunction, OnVoteUpdateFunction = VoteUpdateFunction, VoteBaseUpdateMessage = nil, clientGameId = id}
		if #kRunningVotes == 0 then
			DAKRegisterEventHook(kDAKOnServerUpdate, UpdateVotes, 7)
			//Want increased pri on this to make sure it runs before other events that may use information from it...
		end
		table.insert(kRunningVotes, GameVote)
		return true
	end
	
	local function UpdateVotes(deltatime)
	
		for i = #kRunningVotes, 1, -1 do
			if kRunningVotes[i] and kRunningVotes[i].UpdateTime ~= nil then
				if kRunningVotes[i].UpdateTime >= kDAKConfig.GUIMenuBase.kVoteUpdateRate then
					local newVoteBaseUpdateMessage = kRunningVotes[i].OnVoteUpdateFunction(kRunningVotes.clientGameId, kRunningVotes[i].VoteBaseUpdateMessage)
					//Always send updated message, even if nil - Will force update client side to hide menu/whatever.
					Server.SendNetworkMessage(GetPlayerMatchingGameId(kRunningVotes.clientGameId), "GUIMenuBase", newVoteBaseUpdateMessage, false)						
					kRunningVotes[i].VoteBaseUpdateMessage = newVoteBaseUpdateMessage
					if newVoteBaseUpdateMessage ~= nil and  newVoteBaseUpdateMessage.votetime ~= nil and newVoteBaseUpdateMessage.votetime ~= 0 then
						kRunningVotes[i].UpdateTime = 0
					else
						kRunningVotes[i] = nil
					end
				else
					kRunningVotes[i].UpdateTime = kRunningVotes[i].UpdateTime + deltatime
				end
			end
		end
		if #kRunningVotes == 0 then
			DAKDeregisterEventHook(kDAKOnServerUpdate, UpdateVotes)
		end
	
	end
	
	local function OnMessageBaseVote(client, voteMessage)
	
		if voteMessage ~= nil then
			local CGID = GetGameIdMatchingClient(client)
			for i = #kRunningVotes, 1, -1 do
				if kRunningVotes[i].clientGameId == CGID then
					kRunningVotes[i].OnVoteFunction(client, voteMessage.optionselected)
					break
				end
			end
			Shared.Message(string.format("Recieved vote %s", voteMessage.optionselected))
		end
		
	end

	Server.HookNetworkMessage("GUIMenuBaseSelected", OnMessageBaseVote)

end

Shared.Message("GUIMenuBase Loading Complete")