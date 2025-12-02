-- turtleos/strategies/farmer/potato.lua
local logger = require("turtleos.lib.logger")

-- Ensure movement API is loaded
if not movement then
    os.loadAPI("turtleos/apis/movement.lua")
end

local potato = {}

function potato.execute()
    logger.info("Farming potatoes...")

    -- 1. Check if we need to refuel
    if turtle.getFuelLevel() < 100 then
        logger.warn("Low fuel! Attempting to refuel...")
        movement.refuel()
    end

    -- 2. Ensure we are hovering above the crops
    -- Check if we are standing on farmland (too low)
    local hasBlockDown, dataDown = turtle.inspectDown()
    if hasBlockDown and (dataDown.name == "minecraft:farmland" or dataDown.name == "minecraft:dirt" or dataDown.name == "minecraft:grass_block") then
        logger.info("Standing on soil. Moving up to hover.")
        movement.up()
        return -- Skip farming this tick, adjust position first
    end

    -- Check if we are blocked by a crop in front (too low)
    local hasBlockFront, dataFront = turtle.inspect()
    if hasBlockFront and (dataFront.name == "minecraft:potatoes") then
        logger.info("Potato in front. Moving up to hover.")
        movement.up()
        return
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
        if not turtle.placeDown() then
             logger.warn("Failed to plant (Empty slot?)")
        end
    end

    -- 4. Move forward
    if not movement.forward() then
        logger.warn("Movement blocked! Turning...")
        -- Simple obstacle avoidance: Turn right and try to move
        movement.turnRight()
        if not movement.forward() then
             -- If still blocked, maybe turn again?
             -- For now, just turn to avoid getting stuck forever facing a wall
        end
    end
end

return potato
