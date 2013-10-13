package.path = package.path .. ";../lib/?.lua;../../mods/tgns/output/lua/shine/extensions/?.lua"
require("lunity")
require("lemock")

math.randomseed( os.time() )
systemUnderTest = nil
mc = nil
Shine = nil
TGNSMessageDisplayer = nil
TGNS = nil
SumValue = math.random(1000)
NumbersValue = {4,3,2}
AverageValue = math.random(1000)
-- todo mlh set Value values randomly per test run - http://stackoverflow.com/questions/2620377/lua-reflection-get-list-of-functions-fields-on-an-object

function stub(object, member, value)
	rawset(object, member, value or function() end)
end

function setup()
	nameOfPluginBeingTested = nil
	mc = lemock.controller()
	Shine = mc:mock()
	TGNSMessageDisplayer = mc:mock()
	TGNS = mc:mock()
	mc:replay()
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

function plugin_exists(name)
   return file_exists("../../mods/tgns/output/lua/shine/extensions/" .. name .. ".lua")
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

require("spec_enforceteamsizes")
require("spec_AverageCalculator")