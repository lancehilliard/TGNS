local REQUEST_NOTIFY_MESSAGE_MSG_NAME = "TGNSMenuDisplayer_RequestNotifyMessage"

TGNS.RegisterNetworkMessage(REQUEST_NOTIFY_MESSAGE_MSG_NAME, { prefix = "string(100)", text = "string(900)" })

if Server then
	TGNS.HookNetworkMessage(REQUEST_NOTIFY_MESSAGE_MSG_NAME, function(client, message)
		local md = TGNSMessageDisplayer.Create(string.upper(message.prefix))
		local player = TGNS.GetPlayer(client)
		md:ToPlayerNotifyInfo(player, message.text)
	end)
end

if Client then
	local function Notify(prefix, message)
		TGNS.SendNetworkMessage(REQUEST_NOTIFY_MESSAGE_MSG_NAME, {prefix=prefix,text=message})
	end
	
	TGNSMenuDisplayer = {}

	local shineMenu

	function TGNSMenuDisplayer.Create(initAction)
		local result = {}

		result.AddPage = function(self, pageId, name, helpLines, backPageId, onPopulate)
			Shine.VoteMenu:AddPage(pageId, function(shineSelf)
				shineMenu = shineSelf
				shineMenu:AddTopButton(name .. " Usage", function()
					TGNS.DoFor(helpLines, function(l)
						Notify(name, l)
					end)
					Notify(name, "Visit http://tacticalgamer.com/natural-selection to learn more.")
				end)
				shineMenu:AddBottomButton("Back", function()
					shineMenu:SetPage(backPageId)
				end)
				if onPopulate then
					onPopulate(self)
				end
			end)
		end
		
		result.AddTopButton = function(self, text, onClick)
			shineMenu:AddTopButton(text, onClick)
		end

		result.AddBottomButton = function(self, text, onClick)
			shineMenu:AddBottomButton(text, onClick)
		end

		result.AddSideButton = function(self, text, onClick)
			shineMenu:AddSideButton(text, onClick)
		end
		
		result.EditPage = function(self, pageId, extraPopulate)
			Shine.VoteMenu:EditPage(pageId, function(shineSelf)
				shineMenu = shineSelf
				extraPopulate(self)
			end )
		end
		
		result.SetPage = function(self, pageId)
			shineMenu:SetPage(pageId)
		end

		result.Finish = function(self)
			shineMenu:SetIsVisible(false)
			shineMenu:SetPage("Main")
		end
		
		initAction(result)

		return result
	end
end