package.path = package.path .. ";../lib/?.lua;../../mods/tgns/output/lua/shine/extensions/?.lua"
assert = require("luassert")
spy = require("luassert.spy")

require("lunity")
require("lemock")
require("specObjects")

function stub(object, member, value)
	rawset(object, member, value or function() end)
end

function setup()
	--initializeTestingObjects()
	--initializeTestingValues()
	--mc:replay()
end

function teardown()
	systemUnderTest = nil
end

function file_exists(name) -- http://stackoverflow.com/a/4991602/116895
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function doFile(name)
	dofile("../../mods/tgns/output/lua/tgns/server/" .. name .. ".lua")
end

function loadPlugin(name)
	local result
	stub(Shine, 'RegisterExtension', function(self, name, plugin)
		result = plugin
	end)
 	dofile("../../mods/tgns/output/lua/shine/extensions/" .. name .. ".lua")
 	return result
end

function context(story, scenario)
	return story .. ": when " .. scenario
end

require("spoofs.spec_TGNS")
--require("spec_enforceteamsizes")
--require("spec_AverageCalculator")