-- turtleos/strategies/farmer/tree.lua
local logger = require("turtleos.lib.logger")

-- Load movement API
local movement = require("turtleos.apis.movement")

local tree = {}

-- Configuration
local treeLocations = {
    {x=0, z=0}, {x=0, z=2}, {x=0, z=4},
    {x=2, z=0}, {x=2, z=2}, {x=2, z=4},
    {x=4, z=0}, {x=4, z=2}, {x=4, z=4}
}
local currentTreeIndex = 1

local function selectItem(pattern)
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item and item.name:find(pattern) then
            turtle.select(i)
            return true
        end
    end
    return false
end

local function isLog(name)
    if not name then return false end
    return string.find(name, "log") or string.find(name, "wood")
end

local function isSapling(name)
    if not name then return false end
    return string.find(name, "sapling")
end

-- Move to a specific standing position safely
local function safeGoto(targetX, targetZ)
    local current = movement.getPosition()
    
    -- If we are changing columns (X), move to safe Z zone first to avoid hitting trees
    if math.abs(current.x - targetX) > 0.1 then
        -- Move to Z = -2 (assumed safe aisle connector)
        local success, err = movement.gotoPosition(current.x, 0, -2)
        if not success then
            logger.error("Failed to move to safe zone: " .. (err or "unknown"))
            return false
        end
        
        success, err = movement.gotoPosition(targetX, 0, -2)
        if not success then
            logger.error("Failed to move to target column: " .. (err or "unknown"))
            return false
        end
    end
    
    local success, err = movement.gotoPosition(targetX, 0, targetZ)
    if not success then
        logger.error("Failed to move to target tree: " .. (err or "unknown"))
        return false
    end
    
    return true
end

function tree.execute()
    -- Debug: Check if turtle API exists
    if not turtle then
        logger.error("Turtle API not available! Are you running this on a turtle?")
        return
    end
    
    -- Check fuel
    local fuelLevel = turtle.getFuelLevel()
    logger.info("Current fuel level: " .. tostring(fuelLevel))
    
    if fuelLevel ~= "unlimited" and fuelLevel < 100 then
        logger.info("Attempting to refuel...")
        movement.refuel()
        logger.info("New fuel level: " .. turtle.getFuelLevel())
    end

    -- Get current tree target
    local targetTree = treeLocations[currentTreeIndex]
    local standX = targetTree.x - 1
    local standZ = targetTree.z
    
    logger.info(string.format("Moving to tree %d at (%d, %d)", currentTreeIndex, targetTree.x, targetTree.z))
    
    -- Go to standing position
    if not safeGoto(standX, standZ) then
        logger.error("Aborting tree cycle due to movement error.")
        return
    end
    
    -- Face East (towards the tree at x+1)
    movement.face(1)

    local hasBlock, data = turtle.inspect()
    
    if hasBlock and isLog(data.name) then
        logger.info("Found tree! Chopping...")
        
        -- Chop the base
        turtle.dig()
        movement.forward(true)
        
        -- Chop up
        local height = 0
        while true do
            local hasUp, upData = turtle.inspectUp()
            if hasUp and isLog(upData.name) then
                turtle.digUp()
                movement.up(true)
                height = height + 1
            else
                break
            end
        end
        
        logger.info("Tree height: " .. height)
        
        -- Come down
        for i = 1, height do
            movement.down(true)
        end
        
        -- Move back to standing position
        movement.back()
        
        -- Try to plant immediately after chopping
        logger.info("Planting sapling...")
        if selectItem("sapling") then
            turtle.place()
        else
            logger.warn("No saplings found in inventory!")
        end

    elseif not hasBlock then
        -- Space is empty, try to plant
        logger.info("Space empty. Planting sapling...")
        if selectItem("sapling") then
            if not turtle.place() then
                logger.warn("Failed to place sapling.")
            end
        else
            logger.warn("No saplings found in inventory!")
        end
    else
        -- Block exists but is not a log.
        if isSapling(data.name) then
             -- It's a sapling, just move on.
             -- logger.info("Sapling growing...")
        else
             logger.warn("Unknown block in front: " .. data.name)
        end
    end
    
    -- Move to next tree index for next execution
    currentTreeIndex = currentTreeIndex + 1
    if currentTreeIndex > #treeLocations then
        currentTreeIndex = 1
        logger.info("Cycle complete. Restarting...")
        sleep(5) -- Wait a bit before restarting the cycle
    end
end

return tree
