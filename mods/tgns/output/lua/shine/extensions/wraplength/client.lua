local customLimit

local Plugin = Plugin

TGNS.HookNetworkMessage(Shine.Plugins.wraplength.WRAPLENGTH_DATA, function(message)
    customLimit = message.l
end)

function Plugin:Initialise()
	self.Enabled = true

    local getMaxWidth = function(MaxWidth)
        if customLimit then
            customLimit = Clamp( customLimit, self.MINIMUM_CHAT_WIDTH_PERCENTAGE, self.MAXIMUM_CHAT_WIDTH_PERCENTAGE )
            MaxWidth = Client.GetScreenWidth() * (customLimit/100)
        end
        return MaxWidth
    end

    local originalGUIChatAddMessage = GUIChat.AddMessage
    GUIChat.AddMessage = function(guiChatSelf, playerColor, playerName, messageColor, messageText, isCommander, isRookie)
        local originalWordWrapFunction = WordWrap
        WordWrap = function( Label, Text, XPos, MaxWidth, MaxLines )
            MaxWidth = getMaxWidth(MaxWidth)
            return originalWordWrapFunction( Label, Text, XPos, MaxWidth, MaxLines )
        end
        originalGUIChatAddMessage(guiChatSelf, playerColor, playerName, messageColor, messageText, isCommander, isRookie)
        WordWrap = originalWordWrapFunction
    end

    -- local originalTextWrapFunction = TextWrap
    -- TextWrap = function( Label, Text, XPos, MaxWidth )
    --     MaxWidth = getMaxWidth(MaxWidth)
    --     return originalTextWrapFunction( Label, Text, XPos, MaxWidth )
    -- end

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end