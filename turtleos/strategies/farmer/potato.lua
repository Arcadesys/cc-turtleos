-- turtleos/strategies/farmer/potato.lua
local logger = require("turtleos.lib.logger")
local movement = require("turtleos.apis.movement")

local potato = {}
local initialized = false

-- Configuration
local FIELD_SIZE = 9

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

local function selectHoe()
    -- Try to find any hoe
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item and item.name:find("hoe") then
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

local function farmBlock()
    local hasBlock, data = turtle.inspectDown()
    
    -- 1. Handle existing crop
    if hasBlock and data.name == "minecraft:potatoes" then
        if data.state.age == 7 then
            if hasSpace() then
                logger.info("Harvesting...")
                selectItem("minecraft:potato")
                turtle.digDown()
                if selectItem("minecraft:potato") then
                    turtle.placeDown()
                end
            else
                logger.warn("Inventory full!")
            end
        end
        return
    end

    -- 2. Handle Air (Potential planting spot)
    if not hasBlock then
        -- We are at y=1. Air is at y=0.
        -- We cannot reach y=-1 (Soil) without moving down.
        -- BUT moving down causes trampling of farmland.
        
        -- Attempt to plant anyway (in case it is already farmland)
        if selectItem("minecraft:potato") then
            if turtle.placeDown() then
                logger.info("Planted potato from height.")
                return
            end
        end
        
        -- If we are here, we couldn't plant. Likely dirt or grass below.
        -- Try to till from height (unlikely to work, but safe)
        if selectHoe() then
            if turtle.placeDown() then
                logger.info("Tilled from height.")
                -- Try planting again
                if selectItem("minecraft:potato") then
                    turtle.placeDown()
                end
                return
            end
        end
        
        logger.warn("Cannot till/plant: Ground too low or blocked. Skipping to avoid trampling.")
        return
    end
    
    -- 3. Handle Dirt/Grass at y=0 (High ground)
    if hasBlock and (data.name == "minecraft:dirt" or data.name == "minecraft:grass_block" or data.name == "minecraft:grass") then
        logger.info("Tilling high block (" .. data.name .. ")...")
        if selectHoe() then
            turtle.placeDown()
        end
        if selectItem("minecraft:potato") then
            turtle.placeDown()
        end
    end
end

local function scanAndInteractWithChest()
    logger.info("Scanning for chest...")
    local startFacing = movement.getFacing()
    
    for i = 0, 3 do
        movement.face(i)
        local hasBlock, data = turtle.inspect()
        if hasBlock and (data.name:find("chest") or data.name:find("barrel")) then
            logger.info("Found chest at direction " .. i)
            
            -- Drop off potatoes (keep 5)
            for slot = 1, 16 do
                local item = turtle.getItemDetail(slot)
                if item and item.name == "minecraft:potato" then
                    if item.count > 5 then
                        turtle.select(slot)
                        turtle.drop(item.count - 5)
                    end
                end
            end
            
            -- Refuel
            logger.info("Refueling from chest...")
            while turtle.getFuelLevel() < 5000 do
                local emptySlot = -1
                for s=1, 16 do
                    if turtle.getItemCount(s) == 0 then
                        emptySlot = s
                        break
                    end
                end
                
                if emptySlot == -1 then
                    break
                end
                
                turtle.select(emptySlot)
                if turtle.suck() then
                    if turtle.refuel(0) then
                        turtle.refuel()
                    else
                        turtle.drop() -- Put back non-fuel
                        break -- Stop if we hit non-fuel
                    end
                else
                    break -- Chest empty
                end
            end
            
            return true
        end
    end
    
    logger.warn("No chest found nearby.")
    movement.face(startFacing)
    return false
end

function potato.execute()
    if not initialized then
        logger.info("Initializing Potato Farm Strategy (9x9 Grid)...")
        
        scanAndInteractWithChest()
        
        -- Ensure hovering
        if movement.getPosition().y < 1 then
            movement.up(true)
        end

        -- Go to start (1, 1)
        movement.gotoPosition(1, 1, 1)
        movement.face(1) -- Face East
        
        initialized = true
    end

    logger.info("Starting farm cycle...")

    -- Check fuel
    if turtle.getFuelLevel() < 100 then
        movement.refuel()
    end

    -- Traverse 9x9 grid
    -- We assume we are at (1,1) or close to it.
    -- We will iterate through all positions.
    
    for z = 1, FIELD_SIZE do
        -- Determine X direction for this row (Snake pattern)
        local startX, endX, stepX
        if z % 2 == 1 then
            startX, endX, stepX = 1, FIELD_SIZE, 1
            movement.face(1) -- Face East
        else
            startX, endX, stepX = FIELD_SIZE, 1, -1
            movement.face(3) -- Face West
        end

        for x = startX, endX, stepX do
            -- Go to position (should be adjacent)
            movement.gotoPosition(x, 1, z)
            
            -- Farm the block
            farmBlock()
            
            -- Inventory check
            if turtle.getItemCount(16) > 0 then
                -- If last slot is full, maybe we are full?
                -- Simple check: if full, go home and deposit?
                -- For now, just warn.
            end
        end
    end

    logger.info("Farm cycle complete. Returning to start.")
    movement.gotoPosition(1, 1, 1)
    movement.face(1)
    
    -- Sleep is handled by farmer.lua loop, but we can sleep here too if we want a longer delay between cycles.
    logger.info("Waiting for crops to grow...")
    for i=1, 60 do
        sleep(1)
    end
end

return potato
