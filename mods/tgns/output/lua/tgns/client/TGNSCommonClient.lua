TGNS = TGNS or {}

function TGNS.SendNetworkMessage(messageName, variables)
	variables = variables or {}
	Client.SendNetworkMessage(messageName, variables)
end

function TGNS.ShowUrl(url, windowTitle)
	if Shine.Config.DisableWebWindows then
		local prefix = "[TGNS]"
		local message = string.format("Your web windows are disabled. To re-enable them, type 'sh_disableweb' in your console.")
		Shine.AddChatText(240, 230, 130, prefix, 255, 255, 255, message)
		Shared.Message(string.format("%s %s", prefix, message))
	else
		Shine:OpenWebpage(url, windowTitle)
	end
end