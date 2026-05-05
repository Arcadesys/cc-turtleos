-- boot.lua
-- This file should be renamed to startup.lua on the turtle or called by it.

-- Add the root directory to the package path so we can require files relative to root
package.path = "/?.lua;/?/init.lua;" .. package.path


local args = { ... }
if #args > 0 and args[1] == "menu" then
	require("turtleos.menu")
else
	local core = require("turtleos.lib.core")
	print("Booting TurtleOS...")
	core.init()
end
