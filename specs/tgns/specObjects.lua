systemUnderTest = nil
mc = nil
Shine = nil
TGNSMessageDisplayer = nil
function initializeTestingObjects()
	mc = lemock.controller()
	Shine = {} -- Tables are much more spy-friendly than mocks.
	TGNSMessageDisplayer = {}
end

SumValue = nil
NumbersValue = nil
AverageValue = nil

function initializeTestingValues()
	math.randomseed( os.time() )
	SumValue = math.random(1000)
	NumbersValue = {math.random(1000),math.random(1000),math.random(1000)}
	AverageValue = math.random(1000)
end