-- turtleos/lib/core.lua
local schema = require("turtleos.lib.schema")
local logger = require("turtleos.lib.logger")

local core = {}

function core.init()
    logger.info("TurtleOS initializing...")
    
    -- Load schema
    local schemaData, err = schema.load("turtle_schema.json")
    if not schemaData then
        logger.error("Failed to load schema: " .. (err or "unknown error"))
        return false
    end

    logger.info("Loaded schema for: " .. (schemaData.name or "Unknown Turtle"))

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
