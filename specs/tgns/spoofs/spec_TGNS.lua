module(context("TGNS spoofs network messages", "one is registered, hooked, and called"), lunity)

	function arrange()
		dofile("spoofs/TGNS.lua")
		return TGNS
	end
	
	function act(sut)
		local mSpy = spy.new(function() end)
		sut.RegisterNetworkMessage("test message")
		sut.HookNetworkMessage("test message", mSpy)
		sut.CallNetworkMessage("test message", "abc", "def")
		return mSpy, "abc", "def"
	end
	
	function should_not_error(mSpy, ...)
		assert.truthy(mSpy)
		__assertionSucceeded()
		assert.falsy(mSpy.error)
		__assertionSucceeded()
	end
	
	function should_call_spy(params)
		local mSpy = params.result
		local sentWith = { params.result2, params.result3 }
		assert.spy(mSpy).was_called()
		__assertionSucceeded()
		assert.spy(mSpy).was_called_with(sentWith)
		__assertionSucceeded()
	end
	
runTests{useANSI = false}

module(context("TGNS spoofs event hooks", "one is registered, hooked, and called"), lunity)
	
	function arrange()
		dofile("spoofs/TGNS.lua")
		return TGNS
	end
	
	function act(sut)
		local normalPrioritySpy = spy.new(function() end)
		sut.RegisterEventHook("test event", normalPrioritySpy)
		sut.ExecuteEventHook("test event", "123", "456")
		return normalPrioritySpy, "123", "456"
	end
	
	function should_call_spy(params)
		local normalPrioritySpy = params.result
		local sentWith = { params.result2, params.result3 }
		
		assert.spy(normalPrioritySpy).was_called()
		__assertionSucceeded()
		assert.spy(normalPrioritySpy).was_called_with(sentWith)
		__assertionSucceeded()
	end

runTests{useANSI = false}

module("TGNS spoofs time functions", lunity)
	
	function arrange()
		dofile("spoofs/TGNS.lua")
		return TGNS
	end
	
	function should_create_functions()
		assert.truthy(TGNS.GetSecondsSinceMapLoaded)
		__assertionSucceeded()
		assert.truthy(TGNS.GetSecondsSinceServerProcessStarted)
		__assertionSucceeded()
		assert.truthy(TGNS.GetCurrentDateTimeAsGmtString)
		__assertionSucceeded()
		assert.truthy(TGNS.GetSecondsSinceEpoch)
		__assertionSucceeded()
	end

runTests{useANSI = false}

module(context("TGNS can use http", "a basic website is called"), lunity)

	function arrange()
		dofile("spoofs/TGNS.lua")
		return TGNS
	end
	
	function act(sut)
		local mSpy = spy.new(function() end)
		sut.GetHttpAsync("http://www.umad-barnyard.com/tmp.txt", mSpy)
		return mSpy
	end
	
	function should_call_spy(params)
		local mSpy = params.result
		assert.falsy(mSpy.error)
		__assertionSucceeded()
		assert.spy(mSpy).was_called()
		__assertionSucceeded()
		assert.spy(mSpy).was_called_with("This is a test for the downloading")
		__assertionSucceeded()
	end

runTests{useANSI = false}