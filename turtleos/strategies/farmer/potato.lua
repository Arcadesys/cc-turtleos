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
    
    if not hasBlock then
        -- Air? Maybe we can plant if there's farmland below? 
        -- But inspectDown checks the block we interact with.
        -- If it's air, we might have dug it up.
        -- Try to plant anyway if we have potatoes?
        -- Usually air means we can't plant unless we place dirt first.
        return
    end

    if data.name == "minecraft:potatoes" then
        if data.state.age == 7 then
            if hasSpace() then
                logger.info("Harvesting...")
                selectItem("minecraft:potato") -- Select potato for drops
                turtle.digDown()
                -- turtle.suckDown() -- Auto-pickup usually works, but suck ensures we get it
                
                -- Replant
                if selectItem("minecraft:potato") then
                    turtle.placeDown()
                end
            else
                logger.warn("Inventory full!")
            end
        end
    elseif data.name == "minecraft:dirt" or data.name == "minecraft:grass_block" then
        logger.info("Tilling...")
        if selectHoe() then
            turtle.placeDown() -- Till with hoe
            -- Now plant
            if selectItem("minecraft:potato") then
                turtle.placeDown()
            end
        else
            logger.error("No hoe found!")
        end
    elseif data.name == "minecraft:farmland" then
        -- Just plant
        if selectItem("minecraft:potato") then
            local success = turtle.placeDown()
            if not success then
                -- Maybe blocked by entity or something?
            end
        end
    end
end

function potato.execute()
    if not initialized then
        logger.info("Initializing Potato Farm Strategy (9x9 Grid)...")
        
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
