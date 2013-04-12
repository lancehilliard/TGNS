local function ReplaceMethodInDerivedClasses(className, methodName, method, original)

	if _G[className][methodName] ~= original then
		return
	end
	
	_G[className][methodName] = method

	local classes = Script.GetDerivedClasses(className)

	if classes ~= nil then
		for i, c in ipairs(classes) do
			ReplaceMethodInDerivedClasses(c, methodName, method, original)
		end
	end
	
end

function DAK:Class_ReplaceMethod(className, methodName, method)

	local original = _G[className][methodName]
	
	if original == nil then
		Shared.Message(string.format("Attempted to replace a method that does not exist - %s:%s.", className, methodName))
		return original
	end

	ReplaceMethodInDerivedClasses(className, methodName, method, original)
	return original

end
