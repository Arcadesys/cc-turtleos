-- turtleos/lib/core.lua
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
    
    -- Interactive Menu Access
    print("Press 'm' or 'c' for MENU (3s)...")
    local timerId = os.startTimer(3)
    local launchMenu = false
    while true do
        local event, p1 = os.pullEvent()
        if event == "timer" and p1 == timerId then
            break
        elseif event == "char" and (p1 == "m" or p1 == "c") then
            launchMenu = true
            break
        end
    end
    
    if launchMenu then
        logger.info("Launching Main Menu...")
        shell.run("turtleos/menu.lua")
        -- If menu returns (it loops, but just in case), we verify if we should continue
        print("Menu exited. Resuming boot sequence in 3s...")
        sleep(3)
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
