module(context("server initializes enforceteamsizes plugin", "no errors occur"), lunity)

	function arrange()
		stub(TGNSMessageDisplayer, 'Create')
		return loadPlugin("enforceteamsizes")
	end

	function act(sut)
		return sut:Initialise()
	end

	function should_enable_plugin(x)
		assertTrue(x.sut.Enabled)
	end

	function should_return_true(x)
		assertTrue(x.result)
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
		assertNotNil(x.error:find("test$"))
	end

runTests{useANSI = false}