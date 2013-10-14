--[=========================================================================[
   Lunity v0.10.1 by Gavin Kistner
   See http://github.com/Phrogz/Lunity for usage documentation.
   Licensed under Creative Commons Attribution 3.0 United States License.
   See http://creativecommons.org/licenses/by/3.0/us/ for details.
--]=========================================================================]

local setmetatable=setmetatable
local _G=_G
module( 'lunity' )

VERSION = "0.10.1"

local lunity = _M
setmetatable( lunity, {
	__index = _G,
	__call = function( self, testSuite )
		setmetatable( testSuite, {
			__index = function( testSuite, value )
				if value == 'runTests' then
					return function( options ) lunity.__runAllTests( testSuite, options ) end
				elseif lunity[value] then
					return lunity[value]
				else
					return nil
				end
			end
		} )
	end
} )

function __assertionSucceeded()
	lunity.__assertsPassed = lunity.__assertsPassed + 1
	io.write('.')
	return true
end

function fail( msg )
	if not msg then msg = "(test failure)" end
	error( msg, 2 )
end

function is_nil( value ) return type(value)=='nil' end
function is_boolean( value ) return type(value)=='boolean' end
function is_number( value ) return type(value)=='number' end
function is_string( value ) return type(value)=='string' end
function is_table( value ) return type(value)=='table' end
function is_function( value ) return type(value)=='function' end
function is_thread( value ) return type(value)=='thread' end
function is_userdata( value ) return type(value)=='userdata' end

function __runAllTests( testSuite, options )
	if not options then options = {} end
	lunity.__assertsPassed = 0

	local useHTML, useANSI
	if options.useHTML ~= nil then
		useHTML = options.useHTML
	else
		useHTML = lunity.useHTML
	end

	if not useHTML then
		if options.useANSI ~= nil then
			useANSI = options.useANSI
		elseif lunity.useANSI ~= nil then
			useANSI = lunity.useANSI
		else
			useANSI = true
		end
	end

	if useHTML then
		print( "&lt;h2 style='background:#000; color:#fff; margin:1em 0 0 0; padding:0.1em 0.4em; font-size:120%'&gt;"..testSuite._NAME.."&lt;/h2&gt;&lt;pre style='margin:0; padding:0.2em 1em; background:#ffe; border:1px solid #eed; overflow:auto'&gt;" )
	else
		print( string.rep('=',78) )
		print( testSuite._NAME )
		print( string.rep('=',78) )
	end
	io.stdout:flush()

	local theTestNames = {}
	for testName,test in pairs(testSuite) do
		if type(test)=='function' and type(testName)=='string' and ((testName:find("^test") or testName:find("test$")) or testName:find("^should")) then
			theTestNames[#theTestNames+1] = testName
		end
	end
	table.sort(theTestNames)

	local theSuccessCount = 0
	for _,testName in ipairs(theTestNames) do
		local testScratchpad = {}
		io.write( testName..": " )
		if testSuite.setup then testSuite.setup(testScratchpad) end

		if testSuite.arrange then testSuite.systemUnderTest = testSuite.arrange(testScratchpad) end

		local success, result, result2, result3, err

		if testSuite.act then
			success, err = pcall(function() result, result2, result3 = testSuite.act(testSuite.systemUnderTest) end)
		end

		local successFlag, errorMessage = pcall( function() testSuite[testName]({sut=testSuite.systemUnderTest, result=result, result2=result2, result3=result3,error=err}) end, testScratchpad )
		if successFlag then
			print( "pass" )
			theSuccessCount = theSuccessCount + 1
		else
			if useANSI then
				print( "\27[31m\27[1mFAIL!\27[0m" )
				print( "\27[31m"..errorMessage.."\27[0m" )
			elseif useHTML then
				print("&lt;b style='color:red'&gt;FAIL!&lt;/b&gt;")
				print( "&lt;span style='color:red'&gt;"..errorMessage.."&lt;/span&gt;" )
			else
				print("FAIL!")
				print( errorMessage )
			end
		end
		io.stdout:flush()
		if testSuite.teardown then testSuite.teardown( testScratchpad ) end
	end
	if useHTML then
		print( "&lt;/pre&gt;" )
	else
		print( string.rep( '-', 78 ) )
	end

	print( string.format( "%d/%d tests passed (%0.1f%%)",
		theSuccessCount,
		#theTestNames,
		100 * theSuccessCount / #theTestNames
	) )

	if useHTML then
		print( "&lt;br&gt;" )
	end

	print( string.format( "%d total successful assertion%s",
		lunity.__assertsPassed,
		lunity.__assertsPassed == 1 and "" or "s"
	) )

	if not useHTML then
		print( "" )
	end
	io.stdout:flush()

end