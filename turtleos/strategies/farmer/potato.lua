-- turtleos/strategies/farmer/potato.lua
local logger = require("turtleos.lib.logger")

-- Ensure movement API is loaded
if not movement then
    os.loadAPI("turtleos/apis/movement.lua")
end

local potato = {}
local initialized = false

local function selectItem(name)
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item and item.name == name then
            turtle.select(i)
            return true
        end
    end
    return false
end

local function hasSpace()
    for i = 1, 16 do
        if turtle.getItemCount(i) == 0 then return true end
        local item = turtle.getItemDetail(i)
        if item and item.name == "minecraft:potato" and turtle.getItemSpace(i) > 0 then
            return true
        end
    end
    return false
end

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
            if hasSpace() then
                logger.info("Harvesting potato below...")
                
                -- Select potato to ensure drops stack
                selectItem("minecraft:potato")
                
                turtle.digDown()
                turtle.suckDown() -- Collect extra drops
                
                -- Select potato for planting
                if selectItem("minecraft:potato") then
                    turtle.placeDown() -- Replant
                else
                    logger.warn("No potatoes to replant!")
                end
            else
                logger.warn("Inventory full! Skipping harvest.")
            end
        else
            -- logger.info("Waiting for potato to grow...")
        end
    elseif not hasCrop then
        -- Air below (or we just dug it). Plant.
        logger.info("Planting potato below...")
        
        if selectItem("minecraft:potato") then
            if not turtle.placeDown() then
                 logger.warn("Failed to plant (Blocked?)")
            end
        else
            logger.warn("No potatoes to plant!")
        end
    end

    -- 4. Move forward
    if not movement.forward() then
        logger.warn("Movement blocked! Attempting to find path...")
        
        -- Try turning right until we can move
        for i = 1, 4 do
            movement.turnRight()
            if movement.forward() then
                logger.info("Path found.")
                return
            end
        end
        
        logger.warn("Trapped! Could not move in any direction.")
    end
end

return potato
