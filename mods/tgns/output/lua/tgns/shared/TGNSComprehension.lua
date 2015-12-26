TGNS = TGNS or {}

function TGNS.Select(elements, projector) PROFILE("TGNS.Select")
	local result = {}
	TGNS.DoFor(elements, function(e)
		table.insert(result, projector(e))
	end)
	return result
end

function TGNS.GetLast(elements) PROFILE("TGNS.GetLast")
	local result = elements[#elements]
	return result
end

function TGNS.GetFirst(elements) PROFILE("TGNS.GetFirst")
	local result = elements[1]
	return result
end

function TGNS.FirstOrNil(elements, predicate) PROFILE("TGNS.FirstOrNil")
	local result = nil
	local matching = TGNS.Where(elements, predicate)
	if #matching > 0 then
		result = TGNS.GetFirst(matching)
	end
	return result
end

function TGNS.Count(elements, predicate) PROFILE("TGNS.Count")
	local result = #TGNS.Where(elements, predicate or function() return true end)
	return result
end

function TGNS.Skip(elements, count) PROFILE("TGNS.Skip")
	local result = {}
	TGNS.DoFor(elements, function(element, i)
		if i > count then
			table.insert(result, element)
		end
	end)
	return result
end

function TGNS.Take(elements, count) PROFILE("TGNS.Take")
	local result = {}
	TGNS.DoFor(elements, function(element, i)
		if i <= count then
			table.insert(result, element)
		end
	end)
	return result
end

function TGNS.Where(elements, predicate) PROFILE("TGNS.Where")
	local result = {}
	TGNS.DoFor(elements, function(e)
		if predicate == nil or predicate(e) then
			table.insert(result, e)
		end
	end)
	return result
end

function TGNS.Any(elements, predicate) PROFILE("TGNS.Any")
	local result = (predicate == nil and elements and #elements > 0) and true or #TGNS.Where(elements, predicate) > 0
	return result
end

function TGNS.All(elements, predicate) PROFILE("TGNS.All")
	local result = #TGNS.Where(elements, predicate) == #elements
	return result
end

function TGNS.ToTable(elements, keyProjector, valueProjector) PROFILE("TGNS.ToTable")
	local result = {}
	TGNS.DoFor(elements, function(e)
		result[keyProjector(e)] = valueProjector(e)
	end)
	return result
end