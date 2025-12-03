-- TurtleOS Installer
print('Installing TurtleOS...')

local files = {
    ["boot.lua"] = [[-- boot.lua
-- This file should be renamed to startup.lua on the turtle or called by it.

-- Add the root directory to the package path so we can require files relative to root
package.path = "/?.lua;/?/init.lua;" .. package.path

local core = require("turtleos.lib.core")

print("Booting TurtleOS...")
core.init()
]],
    ["turtleos/apis/movement.lua"] = [[-- turtleos/apis/movement.lua
-- Movement State Machine API for ComputerCraft Turtles
-- Access via: local movement = require("turtleos.apis.movement")

local movement = {}

-- State tracking
local position = {x = 0, y = 0, z = 0}
local facing = 0  -- 0=North(+Z), 1=East(+X), 2=South(-Z), 3=West(-X)
local moveAttempts = 3
local fuelThreshold = 100

-- Movement states
local STATE = {
    IDLE = "idle",
    MOVING = "moving",
    BLOCKED = "blocked",
    ATTACKING = "attacking",
    LOW_FUEL = "low_fuel"
}

local currentState = STATE.IDLE

-- Direction vectors for each facing
local DIRECTIONS = {
    [0] = {x = 0, z = 1},   -- North
    [1] = {x = 1, z = 0},   -- East
    [2] = {x = 0, z = -1},  -- South
    [3] = {x = -1, z = 0}   -- West
}

-- Get current position
function movement.getPosition()
    return {x = position.x, y = position.y, z = position.z}
end

-- Get current facing direction
function movement.getFacing()
    return facing
end

-- Get current state
function movement.getState()
    return currentState
end

-- Set position (useful for calibration)
function movement.setPosition(x, y, z)
    position.x = x or position.x
    position.y = y or position.y
    position.z = z or position.z
end

-- Set facing direction
function movement.setFacing(dir)
    facing = dir % 4
end

-- Check fuel level
function movement.checkFuel()
    local level = turtle.getFuelLevel()
    if level == "unlimited" then
        return true
    end
    
    while level < fuelThreshold do
        currentState = STATE.LOW_FUEL
        
        -- Try to refuel from all slots
        for i = 1, 16 do
            turtle.select(i)
            if turtle.refuel(0) then
                turtle.refuel()
            end
        end
        
        level = turtle.getFuelLevel()
        if level >= fuelThreshold then
            break
        end
        
        print("Fuel low (" .. level .. "/" .. fuelThreshold .. "). Waiting for assistance.")
        print("Press any key to retry...")
        os.pullEvent("key")
    end
    
    if currentState == STATE.LOW_FUEL then
        currentState = STATE.IDLE
    end
    return true
end

-- Try to refuel from inventory
function movement.refuel(amount)
    amount = amount or 64
    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)
            if turtle.refuel(1) then
                return true
            end
        end
    end
    return false
end

-- Turn right
function movement.turnRight()
    if turtle.turnRight() then
        facing = (facing + 1) % 4
        return true
    end
    return false
end

-- Turn left
function movement.turnLeft()
    if turtle.turnLeft() then
        facing = (facing - 1) % 4
        return true
    end
    return false
end

-- Turn around
function movement.turnAround()
    movement.turnRight()
    movement.turnRight()
    return true
end

-- Face a specific direction (0-3)
function movement.face(dir)
    dir = dir % 4
    while facing ~= dir do
        movement.turnRight()
    end
    return true
end

-- Forward movement with retry logic
function movement.forward(force)
    if not movement.checkFuel() then
        print("[MOVEMENT] Failed: low fuel")
        return false, "low_fuel"
    end
    
    currentState = STATE.MOVING
    local attempts = 0
    
    print(string.format("[MOVEMENT] Attempting forward (facing=%d, pos=%d,%d,%d)", facing, position.x, position.y, position.z))
    
    while attempts < moveAttempts do
        local result = turtle.forward()
        print(string.format("[MOVEMENT] turtle.forward() attempt %d: %s", attempts + 1, tostring(result)))
        
        if result then
            -- Update position
            local dir = DIRECTIONS[facing]
            position.x = position.x + dir.x
            position.z = position.z + dir.z
            print(string.format("[MOVEMENT] Success! New pos=%d,%d,%d", position.x, position.y, position.z))
            currentState = STATE.IDLE
            return true
        end
        
        attempts = attempts + 1
        
        if force and attempts < moveAttempts then
            -- Try to clear the way
            if turtle.detect() then
                print("[MOVEMENT] Block detected, digging...")
                currentState = STATE.BLOCKED
                turtle.dig()
                sleep(0.5)
            elseif turtle.attack() then
                print("[MOVEMENT] Entity detected, attacking...")
                currentState = STATE.ATTACKING
                sleep(0.5)
            else
                print("[MOVEMENT] Path blocked but nothing to clear")
            end
        else
            sleep(0.2)
        end
    end
    
    print("[MOVEMENT] Failed after all attempts")
    currentState = STATE.BLOCKED
    return false, "blocked"
end

-- Backward movement
function movement.back()
    if not movement.checkFuel() then
        return false, "low_fuel"
    end
    
    currentState = STATE.MOVING
    
    if turtle.back() then
        -- Update position (move opposite of facing)
        local dir = DIRECTIONS[facing]
        position.x = position.x - dir.x
        position.z = position.z - dir.z
        currentState = STATE.IDLE
        return true
    end
    
    currentState = STATE.BLOCKED
    return false, "blocked"
end

-- Up movement with retry logic
function movement.up(force)
    if not movement.checkFuel() then
        return false, "low_fuel"
    end
    
    currentState = STATE.MOVING
    local attempts = 0
    
    while attempts < moveAttempts do
        if turtle.up() then
            position.y = position.y + 1
            currentState = STATE.IDLE
            return true
        end
        
        attempts = attempts + 1
        
        if force and attempts < moveAttempts then
            if turtle.detectUp() then
                currentState = STATE.BLOCKED
                turtle.digUp()
                sleep(0.5)
            elseif turtle.attackUp() then
                currentState = STATE.ATTACKING
                sleep(0.5)
            end
        else
            sleep(0.2)
        end
    end
    
    currentState = STATE.BLOCKED
    return false, "blocked"
end

-- Down movement with retry logic
function movement.down(force)
    if not movement.checkFuel() then
        return false, "low_fuel"
    end
    
    currentState = STATE.MOVING
    local attempts = 0
    
    while attempts < moveAttempts do
        if turtle.down() then
            position.y = position.y - 1
            currentState = STATE.IDLE
            return true
        end
        
        attempts = attempts + 1
        
        if force and attempts < moveAttempts then
            if turtle.detectDown() then
                currentState = STATE.BLOCKED
                turtle.digDown()
                sleep(0.5)
            elseif turtle.attackDown() then
                currentState = STATE.ATTACKING
                sleep(0.5)
            end
        else
            sleep(0.2)
        end
    end
    
    currentState = STATE.BLOCKED
    return false, "blocked"
end

-- Go to a specific position (simple pathfinding)
function movement.gotoPosition(targetX, targetY, targetZ, force)
    force = force or false
    
    -- Move in X axis
    while position.x ~= targetX do
        if position.x < targetX then
            movement.face(1)  -- East
        else
            movement.face(3)  -- West
        end
        
        local success, err = movement.forward(force)
        if not success then
            return false, err
        end
    end
    
    -- Move in Z axis
    while position.z ~= targetZ do
        if position.z < targetZ then
            movement.face(0)  -- North
        else
            movement.face(2)  -- South
        end
        
        local success, err = movement.forward(force)
        if not success then
            return false, err
        end
    end
    
    -- Move in Y axis
    while position.y ~= targetY do
        local success, err
        if position.y < targetY then
            success, err = movement.up(force)
        else
            success, err = movement.down(force)
        end
        
        if not success then
            return false, err
        end
    end
    
    return true
end

-- Return to origin (0, 0, 0)
function movement.home(force)
    return movement.gotoPosition(0, 0, 0, force)
end

-- Get distance to a position
function movement.distanceTo(x, y, z)
    local dx = math.abs(position.x - x)
    local dy = math.abs(position.y - y)
    local dz = math.abs(position.z - z)
    return dx + dy + dz  -- Manhattan distance
end

-- Configure movement parameters
function movement.configure(config)
    if config.moveAttempts then
        moveAttempts = config.moveAttempts
    end
    if config.fuelThreshold then
        fuelThreshold = config.fuelThreshold
    end
end

-- Reset position and facing
function movement.reset()
    position = {x = 0, y = 0, z = 0}
    facing = 0
    currentState = STATE.IDLE
end

-- Save state to file
function movement.saveState(filename)
    filename = filename or "movement_state.txt"
    local file = fs.open(filename, "w")
    if file then
        file.writeLine(textutils.serialize({
            position = position,
            facing = facing
        }))
        file.close()
        return true
    end
    return false
end

-- Load state from file
function movement.loadState(filename)
    filename = filename or "movement_state.txt"
    if fs.exists(filename) then
        local file = fs.open(filename, "r")
        if file then
            local data = textutils.unserialize(file.readAll())
            file.close()
            if data then
                position = data.position or {x = 0, y = 0, z = 0}
                facing = data.facing or 0
                return true
            end
        end
    end
    return false
end

return movement
]],
    ["turtleos/apis/README.md"] = [[# TurtleOS APIs

This directory contains ComputerCraft API modules for TurtleOS.

## Movement API

A state machine-based movement system for tracking turtle position, orientation, and handling intelligent movement with retry logic.

### Loading the API

```lua
os.loadAPI("turtleos/apis/movement.lua")
```

### Usage Examples

```lua
-- Basic movement
movement.forward(true)  -- Move forward, force through obstacles
movement.up(false)      -- Move up without forcing
movement.turnRight()
movement.turnLeft()

-- Position tracking
local pos = movement.getPosition()
print("Position:", pos.x, pos.y, pos.z)
print("Facing:", movement.getFacing())  -- 0=North, 1=East, 2=South, 3=West

-- Pathfinding
movement.gotoPosition(10, 5, -3, true)  -- Go to coordinates (10, 5, -3)
movement.home(true)                      -- Return to origin (0, 0, 0)

-- State management
print("Current state:", movement.getState())
movement.saveState("my_position.txt")
movement.loadState("my_position.txt")

-- Configuration
movement.configure({
    moveAttempts = 5,      -- Retry failed movements 5 times
    fuelThreshold = 200    -- Warn when fuel < 200
})

-- Fuel management
if not movement.checkFuel() then
    movement.refuel(64)
end

-- Utility
local distance = movement.distanceTo(10, 5, -3)
print("Distance to target:", distance)
```

### API Functions

#### Movement
- `forward(force)` - Move forward, optionally breaking blocks
- `back()` - Move backward
- `up(force)` - Move up, optionally breaking blocks
- `down(force)` - Move down, optionally breaking blocks
- `turnRight()` - Turn 90° clockwise
- `turnLeft()` - Turn 90° counter-clockwise
- `turnAround()` - Turn 180°
- `face(direction)` - Face a specific direction (0-3)

#### Navigation
- `gotoPosition(x, y, z, force)` - Navigate to coordinates
- `home(force)` - Return to origin (0, 0, 0)
- `distanceTo(x, y, z)` - Calculate Manhattan distance

#### State Management
- `getPosition()` - Get current {x, y, z} coordinates
- `getFacing()` - Get current facing direction (0-3)
- `getState()` - Get current state (idle, moving, blocked, etc.)
- `setPosition(x, y, z)` - Manually set position
- `setFacing(direction)` - Manually set facing
- `reset()` - Reset to origin

#### Fuel
- `checkFuel()` - Check if fuel is above threshold
- `refuel(amount)` - Attempt to refuel from inventory

#### Configuration
- `configure(config)` - Set moveAttempts and fuelThreshold
- `saveState(filename)` - Save position/facing to file
- `loadState(filename)` - Load position/facing from file

### States

The movement API tracks these states:
- `idle` - Not currently moving
- `moving` - In motion
- `blocked` - Path is blocked
- `attacking` - Clearing hostile mobs
- `low_fuel` - Fuel below threshold
]],
    ["turtleos/lib/core.lua"] = [[-- turtleos/lib/core.lua
local schema = require("turtleos.lib.schema")
local logger = require("turtleos.lib.logger")

local core = {}

local function checkAndRefuel()
    if not turtle then
        logger.warn("Not running on a turtle, skipping fuel check.")
        return
    end

    local MIN_FUEL = 100

    while true do
        logger.info("Checking fuel levels...")
        local level = turtle.getFuelLevel()
        if level == "unlimited" then
            logger.info("Fuel level: Unlimited")
            return
        end

        logger.info("Current Fuel: " .. level)

        for i = 1, 16 do
            turtle.select(i)
            if turtle.refuel(0) then
                turtle.refuel()
                logger.info("Refueled from slot " .. i)
            end
        end
        
        level = turtle.getFuelLevel()
        logger.info("New Fuel Level: " .. level)

        if level >= MIN_FUEL then
            break
        end

        logger.warn("Fuel low (" .. level .. "/" .. MIN_FUEL .. "). Waiting for assistance.")
        print("Press any key to retry...")
        os.pullEvent("key")
    end
end

function core.init()
    logger.info("TurtleOS initializing...")
    
    checkAndRefuel()
    
    -- Load schema
    local schemaData, err = schema.load("turtle_schema.json")
    if not schemaData then
        if err and string.find(err, "Schema file not found") then
            logger.warn("Schema not found. Creating default configuration...")
            local defaultSchema = {
                name = "Default Farmer",
                version = "1.0.0",
                role = "farmer",
                strategy = "potato"
            }
            local file = fs.open("turtle_schema.json", "w")
            file.write(textutils.serializeJSON(defaultSchema))
            file.close()
            
            -- Retry load
            schemaData, err = schema.load("turtle_schema.json")
        end

        if not schemaData then
            logger.error("Failed to load schema: " .. (err or "unknown error"))
            return false
        end
    end

    logger.info("Loaded schema for: " .. (schemaData.name or "Unknown Turtle"))

    -- Interactive Configuration
    if schemaData.role == "farmer" then
        print("Press 'c' to configure strategy (3s)...")
        local timerId = os.startTimer(3)
        local shouldEdit = false
        while true do
            local event, p1 = os.pullEvent()
            if event == "timer" and p1 == timerId then
                break
            elseif event == "char" and p1 == "c" then
                shouldEdit = true
                break
            end
        end

        if shouldEdit then
            local strategies = {}
            local strategyDir = "turtleos/strategies/farmer"
            if fs.exists(strategyDir) and fs.isDir(strategyDir) then
                local files = fs.list(strategyDir)
                for _, file in ipairs(files) do
                    if file:sub(-4) == ".lua" then
                        table.insert(strategies, file:sub(1, -5))
                    end
                end
            end

            if #strategies > 0 then
                print("Select Farm Type:")
                for i, strat in ipairs(strategies) do
                    print(i .. ". " .. strat)
                end
                write("> ")
                local input = tonumber(read())
                if input and strategies[input] then
                    schemaData.strategy = strategies[input]
                    print("Strategy set to: " .. strategies[input])
                    
                    -- Save changes
                    local file = fs.open("turtle_schema.json", "w")
                    file.write(textutils.serializeJSON(schemaData))
                    file.close()
                else
                    print("Invalid selection.")
                end
            else
                print("No strategies found in " .. strategyDir)
            end
        end
    end

    -- Determine role
    local role = schemaData.role
    if not role then
        logger.error("No role defined in schema")
        return false
    end

    logger.info("Role: " .. role)

    -- Load role module
    local rolePath = "turtleos.roles." .. role
    local success, roleModule = pcall(require, rolePath)
    
    if not success then
        logger.error("Failed to load role module: " .. rolePath)
        logger.error(roleModule) -- Error message
        return false
    end

    -- Execute role
    if roleModule.run then
        roleModule.run(schemaData)
    else
        logger.error("Role module missing 'run' function")
        return false
    end

    return true
end

return core
]],
    ["turtleos/lib/logger.lua"] = [[-- turtleos/lib/logger.lua

local logger = {}

function logger.log(message)
    print("[LOG] " .. message)
    -- In a real implementation, we might write to a file
end

function logger.error(message)
    printError("[ERROR] " .. message)
end

function logger.warn(message)
    print("[WARN] " .. message)
end

function logger.info(message)
    print("[INFO] " .. message)
end

return logger
]],
    ["turtleos/lib/schema.lua"] = [[-- turtleos/lib/schema.lua

local schema = {}

function schema.load(path)
    if not fs.exists(path) then
        return nil, "Schema file not found: " .. path
    end

    local file = fs.open(path, "r")
    local content = file.readAll()
    file.close()

    local data = textutils.unserializeJSON(content)
    if not data then
        return nil, "Failed to parse schema JSON"
    end

    return data
end

return schema
]],
    ["turtleos/roles/builder.lua"] = [[-- turtleos/roles/builder.lua
local logger = require("turtleos.lib.logger")

local builder = {}

function builder.run(schema)
    logger.info("Starting Builder Role...")
    -- Builder logic here
    -- Might load a blueprint from schema
end

return builder
]],
    ["turtleos/roles/farmer.lua"] = [[-- turtleos/roles/farmer.lua
local logger = require("turtleos.lib.logger")

local farmer = {}

function farmer.run(schema)
    logger.info("Starting Farmer Role...")
    
    local strategyName = schema.strategy
    if not strategyName then
        logger.error("No strategy defined for Farmer")
        return
    end

    local strategyPath = "turtleos.strategies.farmer." .. strategyName
    local success, strategy = pcall(require, strategyPath)

    if not success then
        logger.error("Failed to load strategy: " .. strategyPath)
        logger.error(strategy)
        return
    end

    logger.info("Executing strategy: " .. strategyName)
    
    while true do
        if strategy.execute then
            strategy.execute()
        else
            logger.error("Strategy missing 'execute' function")
            break
        end
        sleep(1) -- Prevent infinite loop crash if strategy is instant
    end
end

return farmer
]],
    ["turtleos/roles/miner.lua"] = [[-- turtleos/roles/miner.lua
local logger = require("turtleos.lib.logger")

local miner = {}

function miner.run(schema)
    logger.info("Starting Miner Role...")
    -- Miner logic here
end

return miner
]],
    ["turtleos/strategies/farmer/potato.lua"] = [[-- turtleos/strategies/farmer/potato.lua
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
]],
    ["turtleos/strategies/farmer/tree.lua"] = [[-- turtleos/strategies/farmer/tree.lua
local logger = require("turtleos.lib.logger")

-- Load movement API
local movement = require("turtleos.apis.movement")

local tree = {}

-- Configuration
local treeLocations = {
    {x=1, z=1}, {x=1, z=3}, {x=1, z=5},
    {x=3, z=1}, {x=3, z=3}, {x=3, z=5},
    {x=5, z=1}, {x=5, z=3}, {x=5, z=5}
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
    -- Match any type of log
    return name:find("log") ~= nil or name:find("wood") ~= nil or name:find("stem") ~= nil
end

local function isSapling(name)
    if not name then return false end
    return name:find("sapling") ~= nil
end

local function isLeaves(name)
    if not name then return false end
    return name:find("leaves") ~= nil or name:find("wart_block") ~= nil
end

-- Comprehensive tree chopping that handles branches
local function chopTree()
    logger.info("Starting tree chop sequence...")
    local logsChopped = 0
    
    -- Dig the base log
    if turtle.detect() then
        local success, data = turtle.inspect()
        if success then
            logger.info("Base block: " .. data.name)
            if isLog(data.name) then
                turtle.dig()
                logsChopped = logsChopped + 1
            else
                logger.warn("Front block is not a log: " .. data.name)
                return 0
            end
        end
    else
        logger.warn("No block in front to chop")
        return 0
    end
    
    -- Move forward into the tree position
    if not movement.forward(true) then
        logger.error("Failed to move into tree position")
        return logsChopped
    end
    
    -- Chop upwards
    local height = 0
    while height < 32 do -- Max tree height limit
        local hasUp, upData = turtle.inspectUp()
        
        if hasUp and (isLog(upData.name) or isLeaves(upData.name)) then
            if isLog(upData.name) then
                logger.info("Found log above at height " .. height)
                turtle.digUp()
                logsChopped = logsChopped + 1
            else
                -- It's leaves, dig through them
                turtle.digUp()
            end
            
            if movement.up(true) then
                height = height + 1
            else
                logger.warn("Failed to move up at height " .. height)
                break
            end
        else
            -- No more logs/leaves above
            break
        end
        
        -- Check and dig logs in all horizontal directions at this level
        for dir = 0, 3 do
            movement.face(dir)
            local hasFront, frontData = turtle.inspect()
            if hasFront and isLog(frontData.name) then
                logger.info("Found adjacent log at height " .. height)
                turtle.dig()
                logsChopped = logsChopped + 1
            end
        end
    end
    
    logger.info("Chopped " .. logsChopped .. " logs, descending from height " .. height)
    
    -- Come back down
    for i = 1, height do
        if not movement.down(true) then
            logger.error("Failed to descend at level " .. i)
            break
        end
    end
    
    -- Move back to standing position (back out of the tree)
    movement.back()
    
    return logsChopped
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
    
    if hasBlock then
        logger.info("Block detected: " .. data.name)
    else
        logger.info("No block in front")
    end
    
    if hasBlock and isLog(data.name) then
        logger.info("Found tree! Starting comprehensive chop...")
        local logsChopped = chopTree()
        logger.info("Finished chopping! Total logs: " .. logsChopped)
        
        -- Try to plant immediately after chopping
        logger.info("Planting sapling...")
        if selectItem("sapling") then
            if turtle.place() then
                logger.info("Sapling planted successfully")
            else
                logger.warn("Failed to place sapling (something blocking?)")
            end
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
             logger.info("Sapling detected, waiting for growth...")
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
]],
}

for path, content in pairs(files) do
    print("Writing " .. path)
    local dir = fs.getDir(path)
    if not fs.exists(dir) and dir ~= "" and dir ~= "." then
        fs.makeDir(dir)
    end
    
    local file = fs.open(path, "w")
    file.write(content)
    file.close()
end

if not fs.exists("startup.lua") then
    print("Creating startup.lua...")
    local file = fs.open("startup.lua", "w")
    file.write('shell.run("boot.lua")')
    file.close()
end

print("Installation complete. Rebooting in 3 seconds...")
sleep(3)
os.reboot()
