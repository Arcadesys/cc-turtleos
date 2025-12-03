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
        -- Check what is at y=-1.
        if movement.down() then
            -- Now at y=0.
            local hasSoil, soilData = turtle.inspectDown()
            local needsTilling = false
            
            if hasSoil then
                logger.info("Inspecting soil: " .. soilData.name)
                if soilData.name == "minecraft:dirt" or soilData.name == "minecraft:grass_block" or soilData.name == "minecraft:grass" then
                    needsTilling = true
                elseif soilData.name == "minecraft:farmland" then
                    -- Good to plant
                else
                    logger.warn("Unknown soil type: " .. soilData.name)
                end
            else
                logger.warn("No soil detected below!")
            end
            
            if needsTilling then
                logger.info("Tilling soil...")
                if selectHoe() then
                    local success, err = turtle.placeDown()
                    if not success then
                        logger.error("Failed to till: " .. (err or "unknown"))
                    end
                else
                    logger.error("No hoe found to till soil!")
                end
            end
            
            movement.up()
            -- Now back at y=1.
            
            -- Plant if we have soil/farmland below
            if hasSoil and (needsTilling or soilData.name == "minecraft:farmland") then
                 if selectItem("minecraft:potato") then
                    turtle.placeDown()
                end
            end
        end
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
