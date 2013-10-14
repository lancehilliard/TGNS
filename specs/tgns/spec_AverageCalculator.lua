module(context("server calculates average", "divisor is non-zero"), lunity)

	function arrange()
		doFile("TGNSAverageCalculator")
		return TGNSAverageCalculator
	end

	function act(sut)
		return sut.Calculate(4, 2)
	end

	function should_return_expected_result(x)
		assert.same(2, x.result)
		__assertionSucceeded()
	end

runTests{useANSI = false}

module(context("server calculates average", "divisor is zero"), lunity)

	function arrange()
		doFile("TGNSAverageCalculator")
		return TGNSAverageCalculator
	end

	function act(sut)
		return sut.Calculate(4, 0)
	end

	function should_return_inf(x)
		assert.same(tostring(4/0), tostring(x.result))
		__assertionSucceeded()
	end

runTests{useANSI = false}

module(context("server adds and averages", "nil numbers are given"), lunity)

	function arrange()
		doFile("TGNSAverageCalculator")
		return TGNSAverageCalculator
	end

	function act(sut)
		return sut.CalculateFor(nil)
	end

	function should_return_nothing(x)
		assert.same(nil, x.result)
		__assertionSucceeded()
	end

runTests{useANSI = false}

module(context("server adds and averages", "empty numbers is given"), lunity)

	function arrange()
		doFile("TGNSAverageCalculator")
		return TGNSAverageCalculator
	end

	function act(sut)
		return sut.CalculateFor({})
	end

	function should_return_nothing(x)
		assert.same(nil, x.result)
		__assertionSucceeded()
	end

runTests{useANSI = false}

module(context("server adds and averages", "numbers are given"), lunity)

	function arrange()
		stub(TGNS, 'AtLeastOneElementExists', function(numbers) if numbers == NumbersValue then return true end end)
		stub(TGNS, 'GetSumFor', function(numbers) if numbers == NumbersValue then return SumValue end end)
		stub(TGNS, 'GetCount', function(numbers) if numbers == NumbersValue then return CountValue end end)
		doFile("TGNSAverageCalculator")
		stub(TGNSAverageCalculator, 'Calculate', function(dividend, divisor) if dividend == SumValue and divisor == CountValue then return AverageValue end end)
		return TGNSAverageCalculator
	end

	function act(sut)
		return sut.CalculateFor(NumbersValue)
	end

	function should_return_expected_average(x)
		assert.same(x.result, AverageValue)
		__assertionSucceeded()
	end

runTests{useANSI = false}
