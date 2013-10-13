systemUnderTest = nil
mc = nil
Shine = nil
TGNSMessageDisplayer = nil
TGNS = nil

function initializeTestingObjects()
	mc = lemock.controller()
	Shine = mc:mock()
	TGNSMessageDisplayer = mc:mock()
	TGNS = mc:mock()
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