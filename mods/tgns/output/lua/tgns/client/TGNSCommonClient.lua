TGNS = TGNS or {}

function TGNS.SendNetworkMessage(messageName, variables)
	variables = variables or {}
	Client.SendNetworkMessage(messageName, variables)
end

function TGNS.ShowUrl(url, windowTitle)
	Shine:OpenWebpage(url, windowTitle)
end