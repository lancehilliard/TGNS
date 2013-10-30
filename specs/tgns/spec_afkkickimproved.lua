module(context("afk-kick+ does not error", "initialized"), lunity)
	function arrange()
		stub(TGNSMessageDisplayer, 'Create')
		return loadPlugin("improvedafkhandler")
	end
	
	function act(sut) 
		return sut:Initialise()
	end

	function should_enable_plugin(params)
		assert.is_true(params.sut.Enabled)
		__assertionSucceeded()
	end

	function should_return_true(params)
		assert.is_nil(params.error)
		__assertionSucceeded()
		assert.is_true(params.result)
		__assertionSucceeded()
	end
runTests{useANSI = false}

module(context("afk-kick+ resets afk timer and does not error", "client connects & disconnects"), lunity)
	function arrange()
		stub(TGNSMessageDisplayer, 'Create')
		return loadPlugin("improvedafkhandler")
	end
	
	function act(sut)
		sut:Initialise()
		
		local playerAfk = sut:GetPlayerAFK()
		local fakeClient = { GetIsVirtual = function(self) return false end }
		local fakePlayer = {}
		local OldGetPlayer = GetPlayer
		GetPlayer = function(cl)
			if cl == fakeClient then return fakePlayer end
			if OldGetPlayer then return OldGetPlayer(cl) else return nil end
		end
		return playerAfk, fakeClient, fakePlayer
	end
	
	function should_handle_client_connection(params)
		local sut = params.sut
		local playerAfk, fakeClient, fakePlayer = params.result, params.result2, params.result3
		spy.on(playerAfk, "ResetAFKTimer")
		sut:ClientConnect( fakeClient )
		assert.spy(playerAfk.ResetAFKTimer).was_called()
		__assertionSucceeded()
		assert.spy(playerAfk.ResetAFKTimer).was_called_with(playerAfk, fakeClient)
		__assertionSucceeded()
		assert.has_no.errors(function() sut:ClientDisconnect( fakeClient ) end)
		__assertionSucceeded()
		playerAfk.ResetAFKTimer:revert()
	end

runTests{useANSI=false}

local OldGetPlayer = GetPlayer
local OldGetOwner = GetOwner
local OldGetGamerules = GetGamerules
module(context("afk-kick+ does not error and resets afk timers appropriately", "various hooks are called"), lunity)
	function arrange()
		stub(TGNSMessageDisplayer, 'Create')
		return loadPlugin("improvedafkhandler")
	end
	
	function act(sut)
		sut:Initialise()
		local playerAfk = sut:GetPlayerAFK()
		local fakeClient = { GetIsVirtual = function(self) return false end }
		local fakePlayer = {}
		_G.GetPlayer = function(cl)
			if cl == fakeClient then return fakePlayer end
			if OldGetPlayer then return OldGetPlayer(cl) else return nil end
		end
		
		_G.GetOwner = function(pl)
			if pl == fakePlayer then 
				return fakeClient 
			elseif OldGetOwner then 
				return OldGetOwner(pl) 
			else 
				return nil 
			end
		end
		local TmpGamerules = { GetGameStarted = function() return true end }
		_G.GetGamerules = function()
			return TmpGamerules
		end
		sut:ClientConnect( fakeClient )
		return playerAfk, fakeClient, fakePlayer
	end
	
	
	local function GetFakeBuilding( OwnerPlayer )
		local building = {
			GetTeam = function()
				local theTeam = {
					GetCommander = function() 
						return OwnerPlayer
					end
				}
				return theTeam
			end,
			
			GetOwner = function()
				return OwnerPlayer
			end
		}
		return building
	end
	
	local function check( fName, params, ... )
		local sut = params.sut
		local playerAfk, fakeClient, fakePlayer = params.result, params.result2, params.result3
		local resetAfkSpy = spy.on(playerAfk, "ResetAFKTimer")
		
		local func = sut[fName]
		if func == nil then 
			require 'pl.pretty'.dump(sut)
			error("Function " .. fName .. " not found") 
		end
		arg.n = nil
		local notCalled = false
		for i = 1, #arg do 
			if arg[i] == 'sut' then arg[i] = sut
			elseif arg[i] == 'playerAfk' then arg[i] = playerAfk
			elseif arg[i] == 'fakeClient' then arg[i] = fakeClient
			elseif arg[i] == 'fakePlayer' then arg[i] = fakePlayer
			elseif arg[i] == 'fakeBuilding' then arg[i] = GetFakeBuilding( fakePlayer )
			elseif arg[i] == 'checkNotCalled' then 
				notCalled = true 
				local nArg = #arg
				for j = i + 1, nArg do
					arg[j - 1] = arg[j]
				end
			end
		end
		
		-- assert.has_no.errors(function() func( sut, arg ) end )
		local success, err = pcall( function() func( sut, unpack( arg ) ) end ) -- Better errors this way.
		if success then
			__assertionSucceeded()
		else
			error( 'Hook Check of ' .. fName .. ' failed: ' .. err )
		end
		
		if not notCalled then
			assert.spy(resetAfkSpy).was_called()
			__assertionSucceeded()
			assert.spy(resetAfkSpy).was_called_with( playerAfk, fakeClient )
			__assertionSucceeded()
		else
			assert.spy(resetAfkSpy).was_not_called()
			__assertionSucceeded()
		end
	end
	
	function should_handle_confirmconnect( params )
		check( 'ClientConfirmConnect', params, 'fakeClient' )
	end
	
	function should_handle_processmove( params ) 
		local Input = { 
			pitch = 0,
			yaw = 0,
			move = {
				x = 1,
				y = 0,
				z = 0
			}
		}
		check( 'OnProcessMove', params, 'fakePlayer', Input )
		Input.move.x = 0
		Input.pitch = 3
		check( 'OnProcessMove', params, 'fakePlayer', Input )
		check( 'OnProcessMove', params, 'fakePlayer', Input, 'checkNotCalled' )
	end
	
	function should_handle_namechange( params )
		check( 'PlayerNameChange', params, 'fakePlayer' )
	end
	
	function should_handle_say( params )
		check( 'PlayerSay', params, 'fakeClient' )
	end
	
	function should_handle_comm_functions( params )
		check( 'CommLoginPlayer', params, 'fakeBuilding', 'fakePlayer' )
		check( 'OnConstructInit', params, 'fakeBuilding' )
		check( 'OnCommanderTechTreeAction', params, 'fakePlayer' )
		check( 'OnRecycle', params, 'fakeBuilding' )
		check( 'OnCommanderNotify', params, 'fakePlayer' )
		check( 'CommLogout', params, 'fakePlayer' )
	end
	
	function teardown( params )
		GetOwner = OldGetOwner
		GetPlayer = OldGetPlayer
		GetGamerules = OldGetGamerules
	end
runTests{useANSI=false}