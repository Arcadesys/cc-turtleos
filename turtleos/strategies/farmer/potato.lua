-- turtleos/strategies/farmer/potato.lua
local logger = require("turtleos.lib.logger")

-- Ensure movement API is loaded
if not movement then
    os.loadAPI("turtleos/apis/movement.lua")
end

local potato = {}
local initialized = false

function potato.execute()
    -- 1. Initialization: Move to start offset (1, 1)
    if not initialized then
        logger.info("Initializing Farmer Strategy v2.1...")
        
        -- Ensure we are hovering (Y=1) to avoid breaking crops or getting blocked
        if movement.getPosition().y < 1 then
             logger.info("Moving to hover height...")
             if not movement.up() then
                 logger.error("Failed to move up!")
                 return
             end
        end

        -- Move to offset (1, 1) relative to origin
        -- Target: X=1, Z=1, Y=1
        logger.info("Moving to start offset (1, 1)...")
        local success, err = movement.gotoPosition(1, 1, 1)
        if not success then
            logger.error("Failed to reach start position: " .. (err or "unknown"))
        else
            logger.info("Reached start position.")
        end
        
        initialized = true
        return
    end

    logger.info("Farming potatoes...")

    -- 2. Check fuel
    if turtle.getFuelLevel() < 100 then
        logger.warn("Low fuel! Attempting to refuel...")
        movement.refuel()
    end

    -- 3. Farm the block below
    local hasCrop, cropData = turtle.inspectDown()
    
    if hasCrop and cropData.name == "minecraft:potatoes" then
        if cropData.state.age == 7 then
            logger.info("Harvesting potato below...")
            turtle.digDown()
            turtle.suckDown() -- Collect extra drops
            turtle.placeDown() -- Replant
        else
            -- logger.info("Waiting for potato to grow...")
        end
    elseif not hasCrop then
        -- Air below (or we just dug it). Plant.
        logger.info("Planting potato below...")
        
        -- Find and select potato
        local foundPotato = false
        for i = 1, 16 do
            local item = turtle.getItemDetail(i)
            if item and item.name == "minecraft:potato" then
                turtle.select(i)
                foundPotato = true
                break
            end
        end

        if foundPotato then
            if not turtle.placeDown() then
                 logger.warn("Failed to plant (Blocked?)")
            end
        else
            logger.warn("No potatoes to plant!")
        end
    end

    -- 4. Move forward
    if not movement.forward() then
        logger.warn("Movement blocked! Turning...")
        -- Simple obstacle avoidance: Turn right and try to move
        movement.turnRight()
        if not movement.forward() then
             logger.warn("Still blocked after turning.")
        end
    end
end

return potato
