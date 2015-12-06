TGNS = TGNS or {}

function TGNS.Select(elements, projector)
	local result = {}
	TGNS.DoFor(elements, function(e)
		table.insert(result, projector(e))
	end)
	return result
end

function TGNS.GetLast(elements)
	local result = elements[#elements]
	return result
end

function TGNS.GetFirst(elements)
	local result = elements[1]
	return result
end

function TGNS.FirstOrNil(elements, predicate)
	local result = nil
	local matching = TGNS.Where(elements, predicate)
	if #matching > 0 then
		result = TGNS.GetFirst(matching)
	end
	return result
end

function TGNS.Count(elements, predicate)
	local result = #TGNS.Where(elements, predicate or function() return true end)
	return result
end

function TGNS.Skip(elements, count)
	local result = {}
	TGNS.DoFor(elements, function(element, i)
		if i > count then
			table.insert(result, element)
		end
	end)
	return result
end

function TGNS.Take(elements, count)
	local result = {}
	TGNS.DoFor(elements, function(element, i)
		if i <= count then
			table.insert(result, element)
		end
	end)
	return result
end

function TGNS.Where(elements, predicate)
	local result = {}
	TGNS.DoFor(elements, function(e)
		if predicate == nil or predicate(e) then
			table.insert(result, e)
		end
	end)
	return result
end

function TGNS.Any(elements, predicate)
	local result = (predicate == nil and elements and #elements > 0) and true or #TGNS.Where(elements, predicate) > 0
	return result
end

function TGNS.All(elements, predicate)
	local result = #TGNS.Where(elements, predicate) == #elements
	return result
end

function TGNS.ToTable(elements, keyProjector, valueProjector)
	local result = {}
	TGNS.DoFor(elements, function(e)
		result[keyProjector(e)] = valueProjector(e)
	end)
	return result
end