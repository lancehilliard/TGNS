TGNSAverageCalculator = {}
TGNSAverageCalculator.Calculate = function(total, divisor)
	local result = total / divisor
	return result
end

TGNSAverageCalculator.CalculateFor = function(numbers)
	local result
	if numbers ~= nil and #numbers > 0 then
		local total = 0
		TGNS.DoFor(numbers, function(n) total = total + n end)
		result = TGNSAverageCalculator.Calculate(total, #numbers)
	end
	return result
end