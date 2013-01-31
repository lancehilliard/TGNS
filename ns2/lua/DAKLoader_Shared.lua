//DAK Loader/Base Config

//Shared Defs

local kMaxMenuStringLength = 35

local kMenuBaseUpdateMessage = 
{
	header         		= string.format("string (%d)", kMaxMenuStringLength),
	option1         	= string.format("string (%d)", kMaxMenuStringLength),
	option1desc         = string.format("string (%d)", kMaxMenuStringLength),
	option2        		= string.format("string (%d)", kMaxMenuStringLength),
	option2desc         = string.format("string (%d)", kMaxMenuStringLength),
	option3        		= string.format("string (%d)", kMaxMenuStringLength),
	option3desc         = string.format("string (%d)", kMaxMenuStringLength),
	option4        		= string.format("string (%d)", kMaxMenuStringLength),
	option4desc         = string.format("string (%d)", kMaxMenuStringLength),
	option5         	= string.format("string (%d)", kMaxMenuStringLength),
	option5desc         = string.format("string (%d)", kMaxMenuStringLength),
	footer         		= string.format("string (%d)", kMaxMenuStringLength),
	inputallowed		= "boolean",
	menutime   	  		= "time"
}

Shared.RegisterNetworkMessage("GUIMenuBase", kMenuBaseUpdateMessage)

local kMenuBaseMessage =
{
	optionselected = "integer"
}

Shared.RegisterNetworkMessage("GUIMenuBaseSelected", kMenuBaseMessage)