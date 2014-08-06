local customLimit

local Plugin = Plugin

function Plugin:Initialise()
	self.Enabled = true
     --    local originalWrapText = WrapText
 --    WrapText = function( str, limit, indent, indent1 )
 --     if customLimit ~= nil and customLimit >= 40 then
 --         limit = customLimit
 --     end
 --     return originalWrapText( str, limit, indent, indent1 )
    -- end

    -- function WordWrap( Label, Text, XPos, MaxWidth )
    local originalWordWrap = WordWrap
    WordWrap = function( Label, Text, XPos, MaxWidth )
        if customLimit then
            customLimit = Clamp( customLimit, self.MINIMUM_CHAT_WIDTH_PERCENTAGE, self.MAXIMUM_CHAT_WIDTH_PERCENTAGE )
            MaxWidth = Client.GetScreenWidth() * (customLimit/100)
        end
        return originalWordWrap( Label, Text, XPos, MaxWidth )
    end

    TGNS.HookNetworkMessage(Shine.Plugins.wraplength.WRAPLENGTH_DATA, function(message)
        customLimit = message.l
    end)
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end