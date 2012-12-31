//DAK Loader/Base Config

//Shared Defs

/*
local kMaxVoteStringLength = 35

local kVoteBaseUpdateMessage = 
{
	key              	= "integer",
	header         		= string.format("string (%d)", kMaxVoteStringLength),
	option1         	= string.format("string (%d)", kMaxVoteStringLength),
	option1desc         = string.format("string (%d)", kMaxVoteStringLength),
	option2        		= string.format("string (%d)", kMaxVoteStringLength),
	option2desc         = string.format("string (%d)", kMaxVoteStringLength),
	option3        		= string.format("string (%d)", kMaxVoteStringLength),
	option3desc         = string.format("string (%d)", kMaxVoteStringLength),
	option4        		= string.format("string (%d)", kMaxVoteStringLength),
	option4desc         = string.format("string (%d)", kMaxVoteStringLength),
	option5         	= string.format("string (%d)", kMaxVoteStringLength),
	option5desc         = string.format("string (%d)", kMaxVoteStringLength),
	footer         		= string.format("string (%d)", kMaxVoteStringLength),
	votetime   	  		= "time"
}

Shared.RegisterNetworkMessage( "GUIVoteBase", kVoteBaseUpdateMessage )

local function OnMessageBaseVote(client, voteMessage)
	
	if voteMessage and client then
		local votemanager = kGlobalVote[voteMessage.key]
		if votemanager and votemanager.UpdateTime ~= nil then
			votemanager.OnVoteFunction(player, voteMessage.optionselected)				
		end
	end
	
end

local kVoteBaseMessage =
{
	key = "integer",
	optionselected = "integer"
}

Shared.RegisterNetworkMessage("GUIVoteBaseRecieved", kVoteBaseMessage)
*/