TGNSMonthlyNumberGetter = {}

TGNSMonthlyNumberGetter.Get = function()
	local gmtString = Shared.GetGMTString(false)
	local gmtStringWithoutDashes = TGNS.Replace(gmtString, "-", "")
	local result = TGNS.Substring(gmtStringWithoutDashes, 1, 6)
	return result
end