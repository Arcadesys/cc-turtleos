-- turtleos/strategies/farmer/tree.lua
local logger = require("turtleos.lib.logger")

-- Load movement API
os.loadAPI("turtleos/apis/movement.lua")

local tree = {}

function tree.execute()
    logger.info("Farming trees...")
    local hasBlock, data = turtle.inspect()
    
    if hasBlock and (data.name == "minecraft:log" or data.name == "minecraft:oak_log") then
        logger.info("Chopping tree...")
        turtle.dig()
        movement.forward(true)  -- Use movement API with force
        -- Logic to chop up and come down would go here
        movement.back()
    elseif not hasBlock then
        logger.info("Planting sapling...")
        turtle.place()
    end
    
    -- Log current position
    local pos = movement.getPosition()
    logger.info(string.format("Position: %d, %d, %d", pos.x, pos.y, pos.z))
end

return tree
