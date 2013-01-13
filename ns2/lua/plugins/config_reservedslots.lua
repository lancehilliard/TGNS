//reservedslots config

kDAKRevisions["ReservedSlots"] = 2.0
local function SetupDefaultConfig(Save)
	if kDAKConfig.ReservedSlots == nil then
		kDAKConfig.ReservedSlots = { }
	end
	kDAKConfig.ReservedSlots.kMaximumSlots = 19
	kDAKConfig.ReservedSlots.kReservedSlots = 2
	kDAKConfig.ReservedSlots.kMinimumSlots = 1
	kDAKConfig.ReservedSlots.kDelayedSyncTime = 3
	kDAKConfig.ReservedSlots.kDelayedKickTime = 2
	kDAKConfig.ReservedSlots.kReservePassword = ""
	kDAKConfig.ReservedSlots.kReserveSlotKickedDisconnectReason = "Kicked due to a reserved slot."
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "ReservedSlots", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })