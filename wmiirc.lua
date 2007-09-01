#!/usr/bin/env lua

require "wmii"

-- this is the base configuration
local config = {
        xterm = 'x-terminal-emulator'
}
wmii.configure ({
        view        = 1,
        border      = 1,
        font        = '-windows-proggytiny-medium-r-normal--10-80-96-96-c-60-iso8859-1',
        focuscolors = '#FFFFaa #007700 #88ff88',
        normcolors  = '#888888 #222222 #333333',
        grabmod     = 'Mod1'
})

-- stuff below will eventually go to a separate file, and configuration will remain here
-- similar to the split between the wmii+ruby wmiirc and wmiirc-config
--
-- for now I just want to get the feel of how things will work in lua

-- key handlers

local key_handlers = {
        ["*"] = function (key)
                io.write ("*: " .. key .. "\n")
        end,

        -- execution and actions
        ["Mod1-Return"] = function (key)
                os.execute (config.xterm)
        end,
        ["Mod1-a"] = function (key)
                io.write ("    Mod1-a: " .. key .. "\n")
        end,
        ["Mod1-p"] = function (key)
                io.write ("    Mod1-p: " .. key .. "\n")
        end,

        -- HJKL active selection
        ["Mod1-h"] = function (key)
                io.write ("    Mod1-h: " .. key .. "\n")
        end,
        ["Mod1-l"] = function (key)
                io.write ("    Mod1-l: " .. key .. "\n")
        end,
        ["Mod1-j"] = function (key)
                io.write ("    Mod1-j: " .. key .. "\n")
        end,
        ["Mod1-k"] = function (key)
                io.write ("    Mod1-k: " .. key .. "\n")
        end,

        -- HJKL movement
        ["Mod1-Shift-h"] = function (key)
                io.write ("    Mod1-Shift-h: " .. key .. "\n")
        end,
        ["Mod1-Shift-l"] = function (key)
                io.write ("    Mod1-Shift-l: " .. key .. "\n")
        end,
        ["Mod1-Shift-j"] = function (key)
                io.write ("    Mod1-Shift-j: " .. key .. "\n")
        end,
        ["Mod1-Shift-k"] = function (key)
                io.write ("    Mod1-Shift-k: " .. key .. "\n")
        end,

        -- floating vs tiled
        ["Mod1-space"] = function (key)
                io.write ("    Mod1-space: " .. key .. "\n")
        end,
        ["Mod1-Shift-space"] = function (key)
                io.write ("    Mod1-Shift-space: " .. key .. "\n")
        end,

        -- work spaces
        ["Mod2-#"] = function (key)
                io.write ("    Mod2-#: " .. key .. "\n")
        end,
        ["Mod2-Shift-#"] = function (key)
                io.write ("    Mod2-Shift-#: " .. key .. "\n")
        end


        -- ...

        ["Mod1-Control-t"] = function (key)
                io.write ("    Mod1-Control-t: " .. key .. "\n")
        end,
        ["Mod1-d"] = function (key)
                io.write ("    Mod1-d: " .. key .. "\n")
        end,
        ["Mod1-s"] = function (key)
                io.write ("    Mod1-s: " .. key .. "\n")
        end,
        ["Mod1-m"] = function (key)
                io.write ("    Mod1-m: " .. key .. "\n")
        end,
        ["Mod1-t"] = function (key)
                io.write ("    Mod1-t: " .. key .. "\n")
        end,
        ["Mod1-Shift-c"] = function (key)
                io.write ("    Mod1-Shift-c: " .. key .. "\n")
        end,
        ["Mod1-Shift-t"] = function (key)
                io.write ("    Mod1-Shift-t: " .. key .. "\n")
        end,
}

-- event handlers

local ev_handlers = {
        ["*"] = function (ev, arg)
                io.write ("ev: " .. ev .. " - " .. arg .. "\n")
        end,

        ClientMouseDown = function (ev, arg)
                io.write ("ClientMouseDown: " .. arg .. "\n")
        end,

        CreateTag = function (ev, arg)
                io.write ("CreateTag: " .. arg .. "\n")
        end,

        DestroyTag = function (ev, arg)
                io.write ("DestroyTag: " .. arg .. "\n")
        end,

        FocusTag = function (ev, arg)
                io.write ("FocusTag: " .. arg .. "\n")
        end,

        Key = function (ev, arg)
                io.write ("Key: " .. arg .. "\n")
                local key = string.gsub(arg, "%d+", "#")
                local fn = key_handlers[arg] or key_handlers[key] or key_handlers["*"]
                if fn then
                        fn (arg)
                end
        end,

        LeftBarClick = function (ev, arg)
                io.write ("LeftBarClick: " .. arg .. "\n")
        end,

        NotUrgentTag = function (ev, arg)
                io.write ("NotUrgentTag: " .. arg .. "\n")
        end,

        Start = function (ev, arg)
                io.write ("Start: " .. arg .. "\n")
        end,

        UnfocusTag = function (ev, arg)
                io.write ("UnfocusTag: " .. arg .. "\n")
        end,

        UrgentTag = function (ev, arg)
                io.write ("UrgentTag: " .. arg .. "\n")
        end
}

--[[
Action quit
Action exec
Action rehash
Action status
]]--

-- reading events
local ev, arg
for ev, arg in wmii.ievents() do

        local fn = ev_handlers[ev] or ev_handlers["*"]
        if fn then
                fn (ev, arg)
        end
end

