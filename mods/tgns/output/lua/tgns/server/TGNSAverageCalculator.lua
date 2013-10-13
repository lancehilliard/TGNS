TGNSAverageCalculator = {}
TGNSAverageCalculator.Calculate = function(dividend, divisor)
	local result = dividend / divisor
	return result
end

TGNSAverageCalculator.CalculateFor = function(numbers)
	local result
	if TGNS.AtLeastOneElementExists(numbers) then
		local total = TGNS.GetSumFor(numbers)
		result = TGNSAverageCalculator.Calculate(total, TGNS.GetCount(numbers))
	end
	return result
end