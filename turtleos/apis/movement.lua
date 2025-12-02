-- turtleos/apis/movement.lua
-- Movement State Machine API for ComputerCraft Turtles
-- Load with: os.loadAPI("turtleos/apis/movement.lua")
-- Access via: movement.forward(), movement.getPosition(), etc.

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
function getPosition()
    return {x = position.x, y = position.y, z = position.z}
end

-- Get current facing direction
function getFacing()
    return facing
end

-- Get current state
function getState()
    return currentState
end

-- Set position (useful for calibration)
function setPosition(x, y, z)
    position.x = x or position.x
    position.y = y or position.y
    position.z = z or position.z
end

-- Set facing direction
function setFacing(dir)
    facing = dir % 4
end

-- Check fuel level
function checkFuel()
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
function refuel(amount)
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
function turnRight()
    if turtle.turnRight() then
        facing = (facing + 1) % 4
        return true
    end
    return false
end

-- Turn left
function turnLeft()
    if turtle.turnLeft() then
        facing = (facing - 1) % 4
        return true
    end
    return false
end

-- Turn around
function turnAround()
    turnRight()
    turnRight()
    return true
end

-- Face a specific direction (0-3)
function face(dir)
    dir = dir % 4
    while facing ~= dir do
        turnRight()
    end
    return true
end

-- Forward movement with retry logic
function forward(force)
    if not checkFuel() then
        return false, "low_fuel"
    end
    
    currentState = STATE.MOVING
    local attempts = 0
    
    while attempts < moveAttempts do
        if turtle.forward() then
            -- Update position
            local dir = DIRECTIONS[facing]
            position.x = position.x + dir.x
            position.z = position.z + dir.z
            currentState = STATE.IDLE
            return true
        end
        
        attempts = attempts + 1
        
        if force and attempts < moveAttempts then
            -- Try to clear the way
            if turtle.detect() then
                currentState = STATE.BLOCKED
                turtle.dig()
                sleep(0.5)
            elseif turtle.attack() then
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

-- Backward movement
function back()
    if not checkFuel() then
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
function up(force)
    if not checkFuel() then
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
function down(force)
    if not checkFuel() then
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
function gotoPosition(targetX, targetY, targetZ, force)
    force = force or false
    
    -- Move in X axis
    while position.x ~= targetX do
        if position.x < targetX then
            face(1)  -- East
        else
            face(3)  -- West
        end
        
        local success, err = forward(force)
        if not success then
            return false, err
        end
    end
    
    -- Move in Z axis
    while position.z ~= targetZ do
        if position.z < targetZ then
            face(0)  -- North
        else
            face(2)  -- South
        end
        
        local success, err = forward(force)
        if not success then
            return false, err
        end
    end
    
    -- Move in Y axis
    while position.y ~= targetY do
        local success, err
        if position.y < targetY then
            success, err = up(force)
        else
            success, err = down(force)
        end
        
        if not success then
            return false, err
        end
    end
    
    return true
end

-- Return to origin (0, 0, 0)
function home(force)
    return gotoPosition(0, 0, 0, force)
end

-- Get distance to a position
function distanceTo(x, y, z)
    local dx = math.abs(position.x - x)
    local dy = math.abs(position.y - y)
    local dz = math.abs(position.z - z)
    return dx + dy + dz  -- Manhattan distance
end

-- Configure movement parameters
function configure(config)
    if config.moveAttempts then
        moveAttempts = config.moveAttempts
    end
    if config.fuelThreshold then
        fuelThreshold = config.fuelThreshold
    end
end

-- Reset position and facing
function reset()
    position = {x = 0, y = 0, z = 0}
    facing = 0
    currentState = STATE.IDLE
end

-- Save state to file
function saveState(filename)
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
function loadState(filename)
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
