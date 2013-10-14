module(context("server initializes enforceteamsizes plugin", "no errors occur"), lunity)

	function arrange()
		stub(TGNSMessageDisplayer, 'Create')
		return loadPlugin("enforceteamsizes")
	end

	function act(sut)
		return sut:Initialise()
	end

	function should_enable_plugin(x)
		assert.is_true(x.sut.Enabled)
		__assertionSucceeded()
	end

	function should_return_true(x)
		assert.is_true(x.result)
		__assertionSucceeded()
	end

runTests{useANSI = false}

module(context("server initializes enforceteamsizes plugin", "message displayer fails to initialize"), lunity)

	function arrange()
		stub(TGNSMessageDisplayer, 'Create', function() error("test") end)
		return loadPlugin("enforceteamsizes")
	end

	function act(sut)
		return sut:Initialise()
	end

	function should_throw_error(x)
		assert.truthy(x.error:find("test$"))
		__assertionSucceeded()
	end

runTests{useANSI = false}