TGNSJsonFileTranscoder = {}

local function using(filename, mode, delegate)
	local dataFile = io.open(filename, mode)
	if dataFile then
		delegate(dataFile)
		dataFile:close()
	end
end

function TGNSJsonFileTranscoder.DecodeFromFile(filename)
	local result
	using(filename, "r", function(dataFile) result = json.decode(dataFile:read("*all")) or { } end)
	return result
end

function TGNSJsonFileTranscoder.EncodeToFile(filename, data)
	using(filename, "w+", function(dataFile) dataFile:write(json.encode(data)) end)
end

