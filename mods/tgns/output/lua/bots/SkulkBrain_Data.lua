
Script.Load("lua/bots/CommonActions.lua")
Script.Load("lua/bots/BrainSenses.lua")

local kUpgrades = {
    kTechId.Carapace,
    kTechId.Regeneration,
    
    kTechId.Silence,
    kTechId.Camouflage,
    
    kTechId.Celerity,
    kTechId.Adrenaline,
}

//----------------------------------------
//  More urgent == should really attack it ASAP
//----------------------------------------
local function GetAttackUrgency(bot, mem)

    // See if we know whether if it is alive or not
    local ent = Shared.GetEntity(mem.entId)
    if not HasMixin(ent, "Live") or not ent:GetIsAlive() then
        return 0.0
    end
    
    local botPos = bot:GetPlayer():GetOrigin()
    local targetPos = ent:GetOrigin()
    local distance = botPos:GetDistance(targetPos)

    if mem.btype == kMinimapBlipType.PowerPoint then
        local powerPoint = ent
        if powerPoint ~= nil and powerPoint:GetIsSocketed() then
            return 0.65
        else
            return 0
        end    
    end
        
    local immediateThreats = TGNS.GetCurrentMapName() == "dev_test_disabled" and {} or {
        [kMinimapBlipType.Marine] = true,
        [kMinimapBlipType.JetpackMarine] = true,
        [kMinimapBlipType.Exo] = true,    
        [kMinimapBlipType.Sentry] = true
    }
    
    if distance < 12 and immediateThreats[mem.btype] then
        // Attack the nearest immediate threat (urgency will be 1.1 - 2)
        return 1 + 1 / math.max(distance, 2)
    end
    
    // No immediate threat - load balance!
    local numOthers = bot.brain.teamBrain:GetNumAssignedTo( mem,
            function(otherId)
                if otherId ~= bot:GetPlayer():GetId() then
                          return true
                end
                return false
            end)
                    
    local urgencies = TGNS.GetCurrentMapName() == "dev_test_disabled" and { [kMinimapBlipType.CommandStation] = 1 } or {
        // Active threats
        [kMinimapBlipType.Marine] =             numOthers >= 3 and 0.3 or 1.4,
        [kMinimapBlipType.JetpackMarine] =      numOthers >= 3 and 0.6 or 1.1,
        [kMinimapBlipType.Exo] =                numOthers >= 6 and 0.8 or 1.2,
        [kMinimapBlipType.Sentry] =             numOthers >= 3 and 0.5 or 0.95,
        
        // Structures
        [kMinimapBlipType.ARC] =                numOthers >= 4 and 0.4 or 0.9,
        [kMinimapBlipType.CommandStation] =     numOthers >= 8 and 0.3 or 0.85,
        [kMinimapBlipType.PhaseGate] =          numOthers >= 4 and 0.6 or 1.2,
        [kMinimapBlipType.Observatory] =        numOthers >= 3 and 0.2 or 0.75,
        [kMinimapBlipType.Extractor] =          numOthers >= 3 and 0.2 or 0.7,
        [kMinimapBlipType.InfantryPortal] =     numOthers >= 3 and 0.2 or 0.6,
        [kMinimapBlipType.PrototypeLab] =       numOthers >= 3 and 0.2 or 0.55,
        [kMinimapBlipType.Armory] =             numOthers >= 3 and 0.2 or 0.5,
        [kMinimapBlipType.RoboticsFactory] =    numOthers >= 3 and 0.2 or 0.5,
        [kMinimapBlipType.ArmsLab] =            numOthers >= 3 and 0.2 or 0.5,
        [kMinimapBlipType.MAC] =                numOthers >= 2 and 0.2 or 0.4,
    }

    if urgencies[ mem.btype ] ~= nil then
        return urgencies[ mem.btype ]
    end

    return 0.0
    
end


local function PerformAttackEntity( eyePos, bestTarget, bot, brain, move )

    assert( bestTarget )

    local marinePos = bestTarget:GetOrigin()

    local doFire = false
    bot:GetMotion():SetDesiredMoveTarget( marinePos )
    
    local distance = eyePos:GetDistance(marinePos)
     
     if math.random()<0.618 then
         if GetBotCanSeeTarget( bot:GetPlayer(), bestTarget )  then
             bot.jumpOffset = nil
         end
     end

    if distance < 2.375 then
        doFire = true
     elseif distance > 8 or distance < 3 then
        move.commands = AddMoveCommand( move.commands, Move.SecondaryAttack )
    end
                
    if doFire then
         move.commands = AddMoveCommand( move.commands, Move.Weapon1 )
         
          // jitter view target a little bit
        // local jitter = Vector( math.random(), math.random(), math.random() ) * 0.1
        bot:GetMotion():SetDesiredViewTarget( bestTarget:GetEngagementPoint() )
        move.commands = AddMoveCommand( move.commands, Move.PrimaryAttack )
          
        if bestTarget:isa("Player") then
            // Attacking a player
            if bestTarget:isa("Player") then
                     if ((math.random()<0.1875 and bot:GetPlayer():GetIsOnGround()) or bot:GetPlayer():GetCanWallJump()) then 
                         if not bot:GetPlayer():GetCanWallJump() then
                             move.commands = AddMoveCommand( move.commands, Move.SecondaryAttack )
                         end 
                         move.commands = AddMoveCommand( move.commands, Move.Jump )
                     end
            end
        else
            // Attacking a structure
            if GetDistanceToTouch(eyePos, bestTarget) < 1 then
                // Stop running at the structure when close enough
                bot:GetMotion():SetDesiredMoveTarget(nil)
            end
        end   
    else
          bot:GetMotion():SetDesiredViewTarget( nil )
             
        if (math.random() < 0.0382 and (bot:GetPlayer():GetIsOnGround() or bot:GetPlayer():GetCanWallJump())) or bot:GetPlayer():GetCanWallJump() then
            if math.random() < 0.618 then
                    //pro play wait for marine to come to you, strafing
                    move.commands = AddMoveCommand( move.commands, Move.Jump )
                    if math.random() < 0.618 then
                        if (distance < 16 and math.random() < 0.382) then
                             // When approaching, try to jump sideways
                             bot.timeOfJump = Shared.GetTime()
                             bot.jumpOffset = nil
                             //parasite
                             if distance > 7 then
                                 if GetBotCanSeeTarget( bot:GetPlayer(), bestTarget ) and math.random() < 0.382 and (bestTarget:GetHealth() <= 15 or not bestTarget:GetIsParasited()) then
                                    move.commands = AddMoveCommand( move.commands, Move.Weapon2 )
                                    move.commands = AddMoveCommand( move.commands, Move.PrimaryAttack )
                                 end
                             end
                        end
                    else
                       //pub play close the gap, strafing
                        if (distance < 20 and (math.random() < 0.382 or bot:GetPlayer():GetCanWallJump())) then
                             bot.timeOfJump = Shared.GetTime()
                             //parasite
                             if distance > 6 then
                                 // Strafe jump to dodge
                                 bot.jumpOffset = nil
                                 if GetBotCanSeeTarget( bot:GetPlayer(), bestTarget ) then
                                    move.commands = AddMoveCommand( move.commands, Move.Weapon2 )
                                    move.commands = AddMoveCommand( move.commands, Move.PrimaryAttack )
                                 end
                             end
                        end
                    end
                else
                    // leap sometimes to be unpredictable
                    move.commands = AddMoveCommand( move.commands, Move.Weapon1 )
                    move.commands = AddMoveCommand( move.commands, Move.SecondaryAttack )
                    if distance > 6 then
                         bot.jumpOffset = nil
                    end
                end
        end
        
          //wall jump and dodge
          local tdis = distance*0.02
          if math.random() < (tdis*(tdis+0.1)) or bot:GetPlayer():GetCanWallJump() then
              //leap to help wall jump speed
              if math.random() < 0.1875 then
                    move.commands = AddMoveCommand( move.commands, Move.Weapon1 )
                    move.commands = AddMoveCommand( move.commands, Move.SecondaryAttack )
              end
              move.commands = AddMoveCommand( move.commands, Move.Jump )
          else
              if not bot:GetPlayer():GetCanWallJump() then
                  bot.timeOfJump = Shared.GetTime()
                  bot.jumpOffset = nil
              end
          end

    end
    
    if bot.timeOfJump ~= nil and Shared.GetTime() - bot.timeOfJump < 0.25 then
        
        if bot.jumpOffset == nil then
                
              local botToTarget = GetNormalizedVectorXZ(marinePos - eyePos)
            local sideVector = botToTarget:CrossProduct(Vector(math.random(0.0,0.125), 1, math.random(0.0,0.125)))                
            if math.random() < distance*0.02 then
                    if math.random() < 0.5 then
                         bot.jumpOffset = botToTarget + sideVector
                    else
                         bot.jumpOffset = botToTarget - sideVector
                    end
                end
            bot:GetMotion():SetDesiredViewTarget( bestTarget:GetEngagementPoint() )
            
        end
        
        bot:GetMotion():SetDesiredMoveDirection( bot.jumpOffset )
    end    
    
end

local function PerformAttack( eyePos, mem, bot, brain, move )

    assert( mem )

    local target = Shared.GetEntity(mem.entId)

    if target ~= nil then

        PerformAttackEntity( eyePos, target, bot, brain, move )

    else
    
        // mem is too far to be relevant, so move towards it
        bot:GetMotion():SetDesiredViewTarget(nil)
        bot:GetMotion():SetDesiredMoveTarget(mem.lastSeenPos)

    end
    
    brain.teamBrain:AssignBotToMemory(bot, mem)

end

//----------------------------------------
//  Each want function should return the fuzzy weight,
// along with a closure to perform the action
// The order they are listed matters - actions near the beginning of the list get priority.
//----------------------------------------
kSkulkBrainActions =
{
    
    //----------------------------------------
    //  
    //----------------------------------------
    function(bot, brain)
        return { name = "debug idle", weight = 0.001,
                perform = function(move)
                    bot:GetMotion():SetDesiredMoveTarget(nil)
                    // there is nothing obvious to do.. figure something out
                    // like go to the marines, or defend 
                end }
    end,

    //----------------------------------------
    //  
    //----------------------------------------
    CreateExploreAction( 0.01, function(pos, targetPos, bot, brain, move)
                bot:GetMotion():SetDesiredMoveTarget(targetPos)
                bot:GetMotion():SetDesiredViewTarget(nil)
                end ),
    
    //----------------------------------------
    //  
    //----------------------------------------
    function(bot, brain)
        local name = "evolve"

        local weight = 0.0
        local player = bot:GetPlayer()
        local s = brain:GetSenses()
        
        local distanceToNearestThreat = s:Get("nearestThreat").distance
        local desiredUpgrades = {}
        
        if player:GetIsAllowedToBuy() and
           (distanceToNearestThreat == nil or distanceToNearestThreat > 15) and 
           (player.GetIsInCombat == nil or not player:GetIsInCombat()) then
            
            // Safe enough to try to evolve            
            
            local existingUpgrades = player:GetUpgrades()
            
            for i = 1, #kUpgrades do
                local techId = kUpgrades[i]
                local techNode = player:GetTechTree():GetTechNode(techId)

                local isAvailable = false
                if techNode ~= nil then
                    isAvailable = techNode:GetAvailable(player, techId, false)
                end                    
                
                if not player:GetHasUpgrade(techId) and isAvailable and 
                   GetIsUpgradeAllowed(player, techId, existingUpgrades) and
                   GetIsUpgradeAllowed(player, techId, desiredUpgrades) then
                    table.insert(desiredUpgrades, techId)
                end
            end
            
            if  #desiredUpgrades > 0 then
                weight = 100.0
            end                                
        end

        return { name = name, weight = weight,
            perform = function(move)
                player:ProcessBuyAction( desiredUpgrades )
            end }
    
    end,

    //----------------------------------------
    //  
    //----------------------------------------
    function(bot, brain)
        local name = "attack"
        local skulk = bot:GetPlayer()
        local eyePos = skulk:GetEyePos()
        
        local memories = GetTeamMemories(skulk:GetTeamNumber())
        local bestUrgency, bestMem = GetMaxTableEntry( memories, 
                function( mem )
                    return GetAttackUrgency( bot, mem )
                end)
        
        local weapon = skulk:GetActiveWeapon()
        local canAttack = weapon ~= nil //and weapon:isa("BiteLeap")

        local weight = 0.0

        if canAttack and bestMem ~= nil then

            local dist = 0.0
            if Shared.GetEntity(bestMem.entId) ~= nil then
                dist = GetDistanceToTouch( eyePos, Shared.GetEntity(bestMem.entId) )
            else
                dist = eyePos:GetDistance( bestMem.lastSeenPos )
            end

            weight = EvalLPF( dist, {
                    { 0.0, EvalLPF( bestUrgency, {
                        { 0.0, 0.0 },
                        { 10.0, 25.0 }
                        })},
                    { 10.0, EvalLPF( bestUrgency, {
                            { 0.0, 0.0 },
                            { 10.0, 5.0 }
                            })},
                    { 100.0, 0.0 } })
          end

        return { name = name, weight = weight,
            perform = function(move)
                PerformAttack( eyePos, bestMem, bot, brain, move )
                     
                     if skulk:GetCanWallJump() then
                        move.commands = AddMoveCommand( move.commands, Move.Jump )
                     else
                        if math.random() < 0.125 then
                            move.commands = AddMoveCommand( move.commands, Move.Jump )
                        end
                    end
            end }
    end,    

    //----------------------------------------
    //  
    //----------------------------------------
    function(bot, brain)
        local name = "pheromone"
        
        local skulk = bot:GetPlayer()
        local eyePos = skulk:GetEyePos()

        local pheromones = EntityListToTable(Shared.GetEntitiesWithClassname("Pheromone"))            
        local bestPheromoneLocation = nil
        local bestValue = 0
        
        for p = 1, #pheromones do
        
            local currentPheromone = pheromones[p]
            if currentPheromone then
                local techId = currentPheromone:GetType()
                            
                if techId == kTechId.ExpandingMarker or techId == kTechId.ThreatMarker then
                
                    local location = currentPheromone:GetOrigin()
                    local locationOnMesh = Pathing.GetClosestPoint(location)
                    local distanceFromMesh = location:GetDistance(locationOnMesh)
                    
                    if distanceFromMesh > 0.001 and distanceFromMesh < 2 then
                    
                        local distance = eyePos:GetDistance(location)
                        
                        if currentPheromone.visitedBy == nil then
                            currentPheromone.visitedBy = {}
                        end
                                        
                        if not currentPheromone.visitedBy[bot] then
                        
                            if distance < 5 then 
                                currentPheromone.visitedBy[bot] = true
                            else   
            
                                // Value goes from 5 to 10
                                local value = 5.0 + 5.0 / math.max(distance, 1.0) - #(currentPheromone.visitedBy)
                        
                                if value > bestValue then
                                    bestPheromoneLocation = locationOnMesh
                                    bestValue = value
                                end
                                
                            end    
                            
                        end    
                            
                    end
                    
                end
                        
            end
            
        end
        
        local weight = EvalLPF( bestValue, {
            { 0.0, 0.0 },
            { 10.0, 1.0 }
            })

        return { name = name, weight = weight,
            perform = function(move)
                bot:GetMotion():SetDesiredMoveTarget(bestPheromoneLocation)
                bot:GetMotion():SetDesiredViewTarget(nil)
            end }
    end,

    //----------------------------------------
    //  
    //----------------------------------------
    function(bot, brain)
        local name = "order"

        local skulk = bot:GetPlayer()
        local order = bot:GetPlayerOrder()

        local weight = 0.0
        if order ~= nil then
            weight = 25.0
        end

        return { name = name, weight = weight,
            perform = function(move)
                if order then

                    local target = Shared.GetEntity(order:GetParam())

                    if target ~= nil and order:GetType() == kTechId.Attack then

                        PerformAttackEntity( skulk:GetEyePos(), target, bot, brain, move )
                        
                    else

                        if brain.debug then
                            DebugPrint("unknown order type: %s", ToString(order:GetType()) )
                        end

                        bot:GetMotion():SetDesiredMoveTarget( order:GetLocation() )
                        bot:GetMotion():SetDesiredViewTarget( nil )

                    end
                end
            end }
    end,    

}

//----------------------------------------
//  
//----------------------------------------
function CreateSkulkBrainSenses()

    local s = BrainSenses()
    s:Initialize()

    s:Add("allThreats", function(db)
            local player = db.bot:GetPlayer()
            local team = player:GetTeamNumber()
            local memories = GetTeamMemories( team )
            return FilterTableEntries( memories,
                function( mem )                    
                    local ent = Shared.GetEntity( mem.entId )
                    
                    if ent:isa("Player") or ent:isa("Sentry") then
                        local isAlive = HasMixin(ent, "Live") and ent:GetIsAlive()
                        local isEnemy = HasMixin(ent, "Team") and ent:GetTeamNumber() ~= team                    
                        return isAlive and isEnemy
                    else
                        return false
                    end
                end)                
        end)

    s:Add("nearestThreat", function(db)
            local allThreats = db:Get("allThreats")
            local player = db.bot:GetPlayer()
            local playerPos = player:GetOrigin()
            
            local distance, nearestThreat = GetMinTableEntry( allThreats,
                function( mem )
                    local origin = mem.origin
                    if origin == nil then
                        origin = Shared.GetEntity(mem.entId):GetOrigin()
                    end
                    return playerPos:GetDistance(origin)
                end)

            return {distance = distance, memory = nearestThreat}
        end)

    return s
end
