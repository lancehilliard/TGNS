	
if kBadges.Huze ~= nil then

	local kPAX2012ProductId = 4931
	local kBadgeData = { }
	-- Global badges (can not be assigned by server)
	kBadgeData[kBadges.Huze] = { Texture = "ui/badge_huze.dds" }
	kBadgeData[kBadges.Ns2Learn] = { Texture = "ui/badge_ns2learn.dds" }
	kBadgeData[kBadges.S5Gold] = { Texture = "ui/badge_s5gold.dds" }
	kBadgeData[kBadges.S5Silver] = { Texture = "ui/badge_s5silver.dds" }
	kBadgeData[kBadges.S5Blue] = { Texture = "ui/badge_s5blue.dds" }
	kBadgeData[kBadges.Playtester] = { Texture = "ui/badge_playtester.dds" }
	kBadgeData[kBadges.Constellation] = { Texture = "ui/badge_constellation.dds" }
	kBadgeData[kBadges.UWE] = { Texture = "ui/badge_uwegold.dds" }
	kBadgeData[kBadges.Developer] = { Texture = "ui/badge_dev.dds" }

	-- Server badges
	kBadgeData[kBadges.Unicorn] = { Id = "unicorn", Texture = "ui/badge_unicorn.dds" }
	kBadgeData[kBadges.NyanCat] = { Id = "nyancat", Texture = "ui/badge_nyancat.dds" }
	kBadgeData[kBadges.Troll] = { Id = "troll", Texture = "ui/badge_troll.dds" }
	kBadgeData[kBadges.Star] = { Id = "star", Texture = "ui/badge_star.dds" }
	kBadgeData[kBadges.Heart] = { Id = "heart", Texture = "ui/badge_heart.dds" }
	kBadgeData[kBadges.Clover] = { Id = "clover", Texture = "ui/badge_clover.dds" }
	kBadgeData[kBadges.Ghost] = { Id = "ghost", Texture = "ui/badge_ghost.dds" }
	kBadgeData[kBadges.Pumpkin] = { Id = "pumpkin", Texture = "ui/badge_pumpkin.dds" }
	kBadgeData[kBadges.Skull] = { Id = "skull", Texture = "ui/badge_skull.dds" }
	kBadgeData[kBadges.Crown] = { Id = "crown", Texture = "ui/badge_crown.dds" }
	kBadgeData[kBadges.Admin] = { Id = "admin_group", Texture = "ui/badge_admin.dds" }
	kBadgeData[kBadges.Mod] = { Id = "mod_group", Texture = "ui/badge_mod.dds" }
	kBadgeData[kBadges.Team] = { Id = "team_group", Texture = "ui/badge_mod.dds" }
	kBadgeData[kBadges.Others] = { Id = "others_group", Texture = "ui/badge_mod.dds" }

	-- DLC badges
	kBadgeData[kBadges.PAX2012] = { Id = kPAX2012ProductId, Texture = "ui/badge_pax2012.dds" }

	local function DelayedBadgeOverride()

		local function isBadgeAuthorized(client, badgeId)
			local dlcAuthorized = false
			local groupBadgeAuthorized = false
			Print(ToString(badgeId))
			if type(badgeId) == "number" then
				dlcAuthorized = Server.GetIsDlcAuthorized(client, badgeId)
			else
				groupBadgeAuthorized = DAKGetClientIsInGroup(client, badgeId)
			end
			return dlcAuthorized or groupBadgeAuthorized
		end

		local badgeCache = {}
		local function cacheGet(client)
			local steamId = client:GetUserId()
			local badge = badgeCache[steamId]
			if badge then
				return badge
			end
			-- cache miss
			Shared.SendHTTPRequest("http://ns2comp.herokuapp.com/t/badge/"..tostring(steamId), "GET", function(response)
				local info = json.decode(response)
				-- user override, no badge specified by the server, or pax badges will cause global badge to show
				if info.override or badgeCache[steamId] == nil or badgeCache[steamId] == kBadges.None or badgeCache[steamId] == kBadges.PAX2012 then
					badgeCache[steamId] = kBadges[info.badge]
				end
			end)
			badge = kBadges.None
			for badgeEnum, badgeData in pairs(kBadgeData) do

				if badgeData.Id and isBadgeAuthorized(client, badgeData.Id) then
					badge = badgeEnum
					break
				end
				
			end
			badgeCache[steamId] = badge
			return badge
			
		end
		
		local originalNS2BadgeMixinInit
		
		originalNS2BadgeMixinInit = Class_ReplaceMethod("BadgeMixin", "InitializeBadges", 
			function(self)
				local client = Server.GetOwner(self)
				if client then
					self:SetBadge(cacheGet(client))
				end
			end
		)

		DAKDeregisterEventHook("kDAKOnServerUpdate", DelayedBadgeOverride)
	end
	
	DAKRegisterEventHook("kDAKOnServerUpdate", DelayedBadgeOverride, 5)
	
end