local strategies_dir = "turtleos/strategies"

local function find_strategies(dir, list)
    list = list or {}
    local files = fs.list(dir)
    for _, file in ipairs(files) do
        local path = fs.combine(dir, file)
        if fs.isDir(path) then
            find_strategies(path, list)
        elseif file:sub(-4) == ".lua" then
            table.insert(list, path)
        end
    end
    return list
end

local function draw_menu(options, selected)
    term.clear()
    term.setCursorPos(1, 1)
    print("TurtleOS Menu")
    print("-------------")
    
    local w, h = term.getSize()
    local start_y = 3
    local max_items = h - start_y
    
    -- Simple scrolling logic could be added here if needed, 
    -- but for now we'll just show the first N items
    for i = 1, math.min(#options, max_items) do
        term.setCursorPos(1, start_y + i - 1)
        if i == selected then
            write("> " .. options[i])
        else
            write("  " .. options[i])
        end
    end
end

local function run_menu()
    local strategies = find_strategies(strategies_dir)
    if #strategies == 0 then
        print("No strategies found in " .. strategies_dir)
        return
    end
    
    local selected = 1
    
    while true do
        draw_menu(strategies, selected)
        
        local event, key = os.pullEvent("key")
        if key == keys.up then
            selected = selected - 1
            if selected < 1 then selected = #strategies end
        elseif key == keys.down then
            selected = selected + 1
            if selected > #strategies then selected = 1 end
        elseif key == keys.enter then
            term.clear()
            term.setCursorPos(1, 1)
            print("Running " .. strategies[selected] .. "...")
            shell.run(strategies[selected])
            print("Press any key to return to menu...")
            os.pullEvent("key")
        end
    end
end

run_menu()
