-- boot.lua
-- This file should be renamed to startup.lua on the turtle or called by it.

-- Add the root directory to the package path so we can require files relative to root
package.path = "/?.lua;/?/init.lua;" .. package.path

-- Load APIs
if fs.exists("turtleos/apis/movement.lua") then
    os.loadAPI("turtleos/apis/movement.lua")
end

local core = require("turtleos.lib.core")

print("Booting TurtleOS...")
core.init()
