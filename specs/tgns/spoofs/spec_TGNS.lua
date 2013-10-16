module(context("TGNS spoofs network messages", "one is registered hooked and called"), lunity)

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