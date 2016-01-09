if Server or Client then
	local Plugin = {}

	if Client then
	end

	if Server then
	end

	local function OnClientInitialise()
	end

	local function OnServerInitialise()

		local playerData = {}
		local function getSteamId(player)
		  return GetSteamIdForClientIndex(player.clientIndex)
		end

		function createPlayerData()
		  local data = {}
		  
		  return data
		end

		function getPlayerData(player)
		  if (player.data) then
		    return player.data
		  end

		  local steamId = getSteamId(player)
		  
		  if (not steamId) then
		    return nil
		  end
		  
		  local result = playerData[steamId]
		  
		  if (result == nil) then
		    result = createPlayerData()
		    playerData[steamId] = result
		  end
		  
		  player.data = result

		  return result
		end

		---- Move
		local function giveMoveAllowance(self)
		  self.allowMove = 60
		end

		local function onProcessMove(self, input, funct)
		  -- Handle move exceptions
		  local data = getPlayerData(self)
		  
		  -- Consider allowing movement when all mandatory states are met
		  if self:GetIsAlive() and not self:GetIsCommander() and self:GetIsOnGround() and data then
		    -- Allow movement shortly after game state change
		    local gameStarted = GetGamerules():GetGameStarted()
		    if (data.gameStarted ~= gameStarted) then
		      data.gameStarted = gameStarted
		      
		      if (gameStarted) then
		        giveMoveAllowance(self)
		      end
		    end
		  
		    -- Allow movement when player moving or activating certain binds
		    if not (input.move:GetLength() ~= 0 or self:GetVelocity():GetLengthXZ() ~= 0 or (input.commands ~= 0 and input.commands ~= Move.Crouch and input.commands ~= Move.Reloading and input.commands ~= Move.PrimaryAttack and input.commands ~= Move.SecondaryAttack) or self.jumping) then
		      -- Check second level reasoning
		      local wep = self:GetActiveWeapon()
		      local isReloading = wep and wep.GetIsReloading and wep:GetIsReloading() or false
		      local isCrouching = bit.band(input.commands, Move.Crouch) ~= 0 or bit.band(input.commands, Move.MovementModifier) ~= 0
		      local isAttacking = bit.band(input.commands, Move.PrimaryAttack) ~= 0 or bit.band(input.commands, Move.SecondaryAttack) ~= 0
		      
		      if data.wasCrouching ~= isCrouching or data.wasAttacking ~= isAttacking then
		        data.wasCrouching = isCrouching
		        data.wasAttacking = isAttacking
		        giveMoveAllowance(self)
		      end
		      
		      if not ((self.allowMove and self.allowMove > 0) or isReloading) then        
		        if not isAttacking then -- When a marine, only shortcircuit when not attacking
		          if isAttacking then
		            -- Call all of the light weight tasks
		            local viewModel = self:GetViewModelEntity()
		            if viewModel then
		              viewModel:ProcessMoveOnModel()
		            end
		          end
		          
		          return
		        end
		      end
		    end
		    
		    if self.allowMove and self.allowMove ~= 0 then
		      self.allowMove = self.allowMove - 1
		    end
		  end

		  funct(self, input)
		end

		local oldPlayerOnProcessMove
		oldPlayerOnProcessMove = TGNS.ReplaceClassMethod("Player", "OnProcessMove", function(self, input)
		  onProcessMove(self, input, oldPlayerOnProcessMove)
		end)

		-- Spawning / jumping out of the hive needs a few ticks to settle
		local oldPlayerOnCreate
		oldPlayerOnCreate = TGNS.ReplaceClassMethod("Player", "OnCreate", 
		function(self)
		  oldPlayerOnCreate(self)
		  giveMoveAllowance(self)
		end)

	end

	function Plugin:Initialise()
		self.Enabled = true

		Shine.Timer.Simple(5, function()
			if Client then OnClientInitialise() end
			if Server then OnServerInitialise() end
		end)
		return true
	end

	function Plugin:Cleanup()
	    --Cleanup your extra stuff like timers, data etc.
	    self.BaseClass.Cleanup( self )
	end

	Shine:RegisterExtension("movement", Plugin )
end