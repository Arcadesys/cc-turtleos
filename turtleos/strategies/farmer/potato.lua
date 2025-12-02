-- turtleos/strategies/farmer/potato.lua
local logger = require("turtleos.lib.logger")

local potato = {}

function potato.execute()
    logger.info("Farming potatoes...")
    -- Check block in front
    local hasBlock, data = turtle.inspect()
    if hasBlock and data.name == "minecraft:potatoes" and data.state.age == 7 then
        logger.info("Harvesting potato...")
        turtle.dig()
        turtle.suck() -- Pick up drops
        turtle.place() -- Replant (assuming potato in slot 1)
    elseif not hasBlock then
        logger.info("Planting potato...")
        turtle.place()
    else
        logger.info("Waiting for potato to grow...")
    end
end

return potato
