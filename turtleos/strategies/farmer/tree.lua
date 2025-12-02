-- turtleos/strategies/farmer/tree.lua
local logger = require("turtleos.lib.logger")

local tree = {}

function tree.execute()
    logger.info("Farming trees...")
    local hasBlock, data = turtle.inspect()
    
    if hasBlock and (data.name == "minecraft:log" or data.name == "minecraft:oak_log") then
        logger.info("Chopping tree...")
        turtle.dig()
        turtle.forward()
        -- Logic to chop up and come down would go here
        turtle.back()
    elseif not hasBlock then
        logger.info("Planting sapling...")
        turtle.place()
    end
end

return tree
