-- TurtleOS Installer
print('Installing TurtleOS...')

local files = {
    ['boot.lua'] = "-- boot.lua\r\n-- This file should be renamed to startup.lua on the turtle or called by it.\r\n\r\n-- Add the root directory to the package path so we can require files relative to root\r\npackage.path = \"/?.lua;/?/init.lua;\" .. package.path\r\n\r\nlocal core = require(\"turtleos.lib.core\")\r\n\r\nprint(\"Booting TurtleOS...\")\r\ncore.init()\r\n",
    ['turtleos/lib/core.lua'] = "-- turtleos/lib/core.lua\r\nlocal schema = require(\"turtleos.lib.schema\")\r\nlocal logger = require(\"turtleos.lib.logger\")\r\n\r\nlocal core = {}\r\n\r\nfunction core.init()\r\n    logger.info(\"TurtleOS initializing...\")\r\n    \r\n    -- Load schema\r\n    local schemaData, err = schema.load(\"turtle_schema.json\")\r\n    if not schemaData then\r\n        logger.error(\"Failed to load schema: \" .. (err or \"unknown error\"))\r\n        return false\r\n    end\r\n\r\n    logger.info(\"Loaded schema for: \" .. (schemaData.name or \"Unknown Turtle\"))\r\n\r\n    -- Determine role\r\n    local role = schemaData.role\r\n    if not role then\r\n        logger.error(\"No role defined in schema\")\r\n        return false\r\n    end\r\n\r\n    logger.info(\"Role: \" .. role)\r\n\r\n    -- Load role module\r\n    local rolePath = \"turtleos.roles.\" .. role\r\n    local success, roleModule = pcall(require, rolePath)\r\n    \r\n    if not success then\r\n        logger.error(\"Failed to load role module: \" .. rolePath)\r\n        logger.error(roleModule) -- Error message\r\n        return false\r\n    end\r\n\r\n    -- Execute role\r\n    if roleModule.run then\r\n        roleModule.run(schemaData)\r\n    else\r\n        logger.error(\"Role module missing 'run' function\")\r\n        return false\r\n    end\r\n\r\n    return true\r\nend\r\n\r\nreturn core\r\n",
    ['turtleos/lib/logger.lua'] = "-- turtleos/lib/logger.lua\r\n\r\nlocal logger = {}\r\n\r\nfunction logger.log(message)\r\n    print(\"[LOG] \" .. message)\r\n    -- In a real implementation, we might write to a file\r\nend\r\n\r\nfunction logger.error(message)\r\n    printError(\"[ERROR] \" .. message)\r\nend\r\n\r\nfunction logger.info(message)\r\n    print(\"[INFO] \" .. message)\r\nend\r\n\r\nreturn logger\r\n",
    ['turtleos/lib/schema.lua'] = "-- turtleos/lib/schema.lua\r\n\r\nlocal schema = {}\r\n\r\nfunction schema.load(path)\r\n    if not fs.exists(path) then\r\n        return nil, \"Schema file not found: \" .. path\r\n    end\r\n\r\n    local file = fs.open(path, \"r\")\r\n    local content = file.readAll()\r\n    file.close()\r\n\r\n    local data = textutils.unserializeJSON(content)\r\n    if not data then\r\n        return nil, \"Failed to parse schema JSON\"\r\n    end\r\n\r\n    return data\r\nend\r\n\r\nreturn schema\r\n",
    ['turtleos/roles/builder.lua'] = "-- turtleos/roles/builder.lua\r\nlocal logger = require(\"turtleos.lib.logger\")\r\n\r\nlocal builder = {}\r\n\r\nfunction builder.run(schema)\r\n    logger.info(\"Starting Builder Role...\")\r\n    -- Builder logic here\r\n    -- Might load a blueprint from schema\r\nend\r\n\r\nreturn builder\r\n",
    ['turtleos/roles/farmer.lua'] = "-- turtleos/roles/farmer.lua\r\nlocal logger = require(\"turtleos.lib.logger\")\r\n\r\nlocal farmer = {}\r\n\r\nfunction farmer.run(schema)\r\n    logger.info(\"Starting Farmer Role...\")\r\n    \r\n    local strategyName = schema.strategy\r\n    if not strategyName then\r\n        logger.error(\"No strategy defined for Farmer\")\r\n        return\r\n    end\r\n\r\n    local strategyPath = \"turtleos.strategies.farmer.\" .. strategyName\r\n    local success, strategy = pcall(require, strategyPath)\r\n\r\n    if not success then\r\n        logger.error(\"Failed to load strategy: \" .. strategyPath)\r\n        logger.error(strategy)\r\n        return\r\n    end\r\n\r\n    logger.info(\"Executing strategy: \" .. strategyName)\r\n    \r\n    while true do\r\n        if strategy.execute then\r\n            strategy.execute()\r\n        else\r\n            logger.error(\"Strategy missing 'execute' function\")\r\n            break\r\n        end\r\n        sleep(1) -- Prevent infinite loop crash if strategy is instant\r\n    end\r\nend\r\n\r\nreturn farmer\r\n",
    ['turtleos/roles/miner.lua'] = "-- turtleos/roles/miner.lua\r\nlocal logger = require(\"turtleos.lib.logger\")\r\n\r\nlocal miner = {}\r\n\r\nfunction miner.run(schema)\r\n    logger.info(\"Starting Miner Role...\")\r\n    -- Miner logic here\r\nend\r\n\r\nreturn miner\r\n",
    ['turtleos/strategies/farmer/potato.lua'] = "-- turtleos/strategies/farmer/potato.lua\r\nlocal logger = require(\"turtleos.lib.logger\")\r\n\r\nlocal potato = {}\r\n\r\nfunction potato.execute()\r\n    logger.info(\"Farming potatoes...\")\r\n    -- Check block in front\r\n    local hasBlock, data = turtle.inspect()\r\n    if hasBlock and data.name == \"minecraft:potatoes\" and data.state.age == 7 then\r\n        logger.info(\"Harvesting potato...\")\r\n        turtle.dig()\r\n        turtle.suck() -- Pick up drops\r\n        turtle.place() -- Replant (assuming potato in slot 1)\r\n    elseif not hasBlock then\r\n        logger.info(\"Planting potato...\")\r\n        turtle.place()\r\n    else\r\n        logger.info(\"Waiting for potato to grow...\")\r\n    end\r\nend\r\n\r\nreturn potato\r\n",
    ['turtleos/strategies/farmer/tree.lua'] = "-- turtleos/strategies/farmer/tree.lua\r\nlocal logger = require(\"turtleos.lib.logger\")\r\n\r\nlocal tree = {}\r\n\r\nfunction tree.execute()\r\n    logger.info(\"Farming trees...\")\r\n    local hasBlock, data = turtle.inspect()\r\n    \r\n    if hasBlock and (data.name == \"minecraft:log\" or data.name == \"minecraft:oak_log\") then\r\n        logger.info(\"Chopping tree...\")\r\n        turtle.dig()\r\n        turtle.forward()\r\n        -- Logic to chop up and come down would go here\r\n        turtle.back()\r\n    elseif not hasBlock then\r\n        logger.info(\"Planting sapling...\")\r\n        turtle.place()\r\n    end\r\nend\r\n\r\nreturn tree\r\n",
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