local logger = require("turtleos.lib.logger")
local movement = require("turtleos.apis.movement")

local potato = {}
local initialized = false

-- Runtime state
local config = {
    width = 9,
    length = 9,
    trash_items = {}
}

-- Helper Functions
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

local function cleanupInventory()
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item and config.trash_items[item.name] then
            turtle.select(i)
            turtle.drop()
        end
    end
end

-- Atomic Operations
local operations = {
    harvest = function()
        if not hasSpace() then
            cleanupInventory()
            if not hasSpace() then
                logger.warn("Inventory full, cannot harvest")
                return false
            end
        end
        turtle.digDown()
        turtle.suckDown()
        return true
    end,
    
    plant = function()
        if selectItem("minecraft:potato") then
            return turtle.placeDown()
        end
        logger.warn("No potatoes to plant")
        return false
    end,
    
    replant = function()
        -- Same as plant for now
        return operations.plant()
    end,
    
    till = function()
        if selectHoe() then
            return turtle.placeDown()
        end
        logger.warn("No hoe found")
        return false
    end
}

-- Action Executor
local function executeAction(actionDef)
    if actionDef.type == "inspect_and_interact" then
        local hasBlock, data = turtle.inspectDown()
        
        -- Determine State
        local state = "missing"
        if hasBlock then
            if data.name == actionDef.expect then
                local propsMatch = true
                if actionDef.properties then
                    for k, v in pairs(actionDef.properties) do
                        if not data.state or data.state[k] ~= v then
                            propsMatch = false
                            break
                        end
                    end
                end
                
                if propsMatch then
                    state = "match"
                else
                    state = "wrong_props" -- Correct block, wrong state (e.g. immature crop)
                end
            else
                state = "wrong" -- Completely different block (e.g. weeds/dirt where crop should be)
            end
        end
        
        -- Execute Handlers
        local opsToRun = {}
        if state == "match" then opsToRun = actionDef.on_match or {}
        elseif state == "missing" then opsToRun = actionDef.on_missing or {}
        elseif state == "wrong" then opsToRun = actionDef.on_wrong or {}
        elseif state == "wrong_props" then opsToRun = actionDef.on_wrong_props or {}
        end
        
        for _, opName in ipairs(opsToRun) do
            if operations[opName] then
                operations[opName]()
            else
                logger.error("Unknown operation: " .. opName)
            end
        end
    end
end

local function processTile(schema, typeName)
    local tileDef = schema.tile_definitions and schema.tile_definitions[typeName]
    if not tileDef then
        logger.error("Undefined tile type: " .. typeName)
        return
    end
    
    if tileDef.actions then
        for _, action in ipairs(tileDef.actions) do
            executeAction(action)
        end
    end
end

-- Main Execution Function
function potato.execute(schema)
    if not schema or not schema.farm_config then
        logger.error("Invalid schema provided to potato strategy")
        sleep(5)
        return
    end

    -- Setup Config
    config.width = schema.farm_config.dimensions.width or 9
    config.length = schema.farm_config.dimensions.length or 9
    
    config.trash_items = {}
    if schema.farm_config.trash_items then
        for _, item in ipairs(schema.farm_config.trash_items) do
            config.trash_items[item] = true
        end
    end
    
    movement.loadState()
    
    -- Interpret Plan
    if schema.plan == "fill_farm_space" then
        logger.info("Executing plan: fill_farm_space (" .. config.width .. "x" .. config.length .. ")")
        
        -- Move up to hover height (y=2) to avoid trampling crops
        movement.gotoPosition(1, 2, 1, false)

        -- Snake Pattern
        for z = 1, config.length do
            local startX, endX, stepX
            if z % 2 == 1 then
                startX, endX, stepX = 1, config.width, 1
                movement.face(1) -- East
            else
                startX, endX, stepX = config.width, 1, -1
                movement.face(3) -- West
            end
            
            for x = startX, endX, stepX do
                -- Move to position at height 2
                movement.gotoPosition(x, 2, z, false)
                processTile(schema, "farm_space")
                
                -- Periodic cleanup
                if turtle.getItemCount(16) > 0 then
                    cleanupInventory()
                end
            end
        end
    else
        logger.error("Unknown plan: " .. tostring(schema.plan))
    end
    
    logger.info("Farm cycle complete. Returning start.")
    movement.gotoPosition(1, 1, 1, false)
    
    -- Simple delay instead of complex logic provided in old file
    logger.info("Waiting for growth...")
    sleep(60)
end

return potato
