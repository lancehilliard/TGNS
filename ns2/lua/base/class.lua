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

function Class_ReplaceMethod(className, methodName, method)

	local original = _G[className][methodName]
	assert(original ~= nil)

	ReplaceMethodInDerivedClasses(className, methodName, method, original)
	return original

end
