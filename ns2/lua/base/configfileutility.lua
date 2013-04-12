// ======= Copyright (c) 2003-2012, Unknown Worlds Entertainment, Inc. All rights reserved. =====
//
// core/ConfigFileUtility.lua
//
// Created by Brian Cronin (brianc@unknownworlds.com)
//
// ========= For more information, visit us at http://www.unknownworlds.com =====================

Script.Load("lua/dkjson.lua")

function DAK:WriteDefaultConfigFile(fileName, defaultConfig, lvl)

    local configFile = io.open(fileName, "r")
    if not configFile then
    
        configFile = io.open(fileName, "w+")
        if configFile == nil then
            return
        end
        configFile:write(json.encode(defaultConfig, { indent = true, level = lvl or 1 }))
        
    end
    
    io.close(configFile)
    
end

function DAK:LoadConfigFile(fileName)

    //Shared.Message("Loading " .. fileName)
    
    local openedFile = io.open(fileName, "r")
    if openedFile then
    
        local parsedFile, _, errStr = json.decode(openedFile:read("*all"))
        if errStr then
            Shared.Message("Error while opening " .. fileName .. ": " .. errStr)
        end
        io.close(openedFile)
        return parsedFile
        
    end
    
    return nil
    
end

function DAK:SaveConfigFile(fileName, data, lvl)

    //Shared.Message("Saving " .. fileName)
    
    local openedFile = io.open(fileName, "w+")
    
    if openedFile then
    
        openedFile:write(json.encode(data, { indent = true, level = lvl or 1 }))
        io.close(openedFile)
        
    end
    
end