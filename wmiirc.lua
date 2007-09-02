#!/usr/bin/env lua
--
-- Copyrigh (c) 2007, Bart Trojanowski <bart@jukie.net>
--
-- Some stuff below will eventually go to a separate file, and configuration 
-- will remain here similar to the split between the wmii+ruby wmiirc and
-- wmiirc-config.  For now I just want to get the feel of how things will 
-- work in lua.
--
-- git://www.jukie.net/wmiirc-lua.git/

require "posix"

-- this is us
local wmiirc = os.getenv("HOME") .. "/.wmii-3.5/wmiirc"

-- debug
function my_log (str)
        io.stderr:write (str .. "\n")
end

-- load wmii.lua
my_log("wmii: loading wmii.lua")
package.path = './.wmii-3.5/?.lua;' .. package.path
require "wmii" 

my_log("wmii: wmii.lua loaded")

-- stop any other instance of wmiirc
wmii.write ("/event", "Start wmiirc")

-- this is the base configuration
local config = {
        xterm = 'x-terminal-emulator'
}
my_log("wmii: setting confg")
wmii.configure ({
        view        = 1,
        border      = 1,
        font        = '-windows-proggytiny-medium-r-normal--10-80-96-96-c-60-iso8859-1',
        focuscolors = '#FFFFaa #007700 #88ff88',
        normcolors  = '#888888 #222222 #333333',
        grabmod     = 'Mod1'
})

my_log("wmii: config set")

wmii.write ("/colrules", "/.*/ -> 58+42")
wmii.write ("/tagrules", "/XMMS.*/ -> ~\n"
                      .. "/MPlayer.*/ -> ~\n"
                      .. "/.*/ -> sel\n"
                      .. "/.*/ -> 1\n")


-- ------------------------------------------------------------------------
-- action handlers

local action_handlers = {
        quit = function ()
                wmii.write ("/ctl", "quit")
        end,

        exec = function (act, args)
                local what = args or wmiirc
                wmii.write ("/ctl", "exec " .. what)
        end,

        wmiirc = function ()
                posix.exec ("lua", wmiirc)
        end,

        rehash = function ()
                -- TODO: consider storing list of executables around, and 
                -- this will then reinitialize that list
                my_log ("    TODO: rehash")
        end,

        status = function ()
                -- TODO: this should eventually update something on the /rbar
                my_log ("    TODO: status")
        end
}

-- ------------------------------------------------------------------------
-- key handlers

local key_handlers = {
        ["*"] = function (key)
                my_log ("*: " .. key)
        end,

        -- execution and actions
        ["Mod1-Return"] = function (key)
                my_log ("    executing: " .. config.xterm)
                os.execute (config.xterm .. " &")
        end,
        ["Mod1-a"] = function (key)
                local text = wmii.menu (action_handlers)
                if text then
                        local act = text
                        local args = nil
                        local si = text:find("%s")
                        if si then
                                act,args = string.match(text .. " ", "(%w+)%s(.+)")
                        end
                        if act then
                                local fn = action_handlers[act]
                                if fn then
                                        fn (act,args)
                                end
                        end
                end
        end,
        ["Mod1-p"] = function (key)
                local prog = wmii.progmenu()
                if prog then
                        my_log ("    executing: " .. prog)
                        os.execute (prog .. " &")
                end
        end,
        ["Mod1-Shift-c"] = function (key)
                wmii.write ("/client/sel/ctl", "kill")
        end,

        -- HJKL active selection
        ["Mod1-h"] = function (key)
                wmii.write ("/tag/sel/ctl", "select left")
        end,
        ["Mod1-l"] = function (key)
		wmii.write ("/tag/sel/ctl", "select right")
        end,
        ["Mod1-j"] = function (key)
		wmii.write ("/tag/sel/ctl", "select down")
        end,
        ["Mod1-k"] = function (key)
		wmii.write ("/tag/sel/ctl", "select up")
        end,

        -- HJKL movement
        ["Mod1-Shift-h"] = function (key)
                wmii.write ("/tag/sel/ctl", "send sel left")
        end,
        ["Mod1-Shift-l"] = function (key)
		wmii.write ("/tag/sel/ctl", "send sel right")
        end,
        ["Mod1-Shift-j"] = function (key)
		wmii.write ("/tag/sel/ctl", "send sel down")
        end,
        ["Mod1-Shift-k"] = function (key)
		wmii.write ("/tag/sel/ctl", "send sel up")
        end,

        -- floating vs tiled
        ["Mod1-space"] = function (key)
                wmii.write ("/tag/sel/ctl", "select toggle")
        end,
        ["Mod1-Shift-space"] = function (key)
                wmii.write ("/tag/sel/ctl", "send sel toggle")
        end,

        -- work spaces
        ["Mod4-#"] = function (key, num)
                wmii.write ("/ctl", "view " .. tostring(num))
        end,
        ["Mod4-Shift-#"] = function (key, num)
                wmii.write ("/client/sel/tags", tostring(num))
        end,


        -- switching views and retagging
        ["Mod1-t"] = function (key)
                local tag = wmii.tagmenu()
                if tag then
                        wmii.write ("/ctl", "view " .. tag)
                end

        end,
        ["Mod1-Shift-t"] = function (key)
                local tag = wmii.tagmenu()
                if tag then
                        local cli = wmii.read ("/client/sel/ctl")
                        wmii.write ("/client/" .. cli .. "/tags", tag)
                end
        end,
        ["Mod1-Control-t"] = function (key)
                my_log ("    TODO: Mod1-Control-t: " .. key)
        end,

        -- column modes
        ["Mod1-d"] = function (key)
		wmii.write("/tag/sel/ctl", "colmode sel default")
        end,
        ["Mod1-s"] = function (key)
		wmii.write("/tag/sel/ctl", "colmode sel stack")
        end,
        ["Mod1-m"] = function (key)
		wmii.write("/tag/sel/ctl", "colmode sel max")
        end
}

-- ------------------------------------------------------------------------
-- update the /keys wmii file with the list of all handlers

do
        local t = {}
        local x, y
        for x,y in pairs(key_handlers) do
                if x:find("%w") then
                        local i = x:find("#")
                        if i then
                                local j
                                for j=0,9 do
                                        t[#t + 1] 
                                                = x:sub(1,i-1) .. j
                                end
                        else
                                t[#t + 1] 
                                        = tostring(x)
                        end
                end
        end
        local all_keys = table.concat(t, "\n")
        my_log ("setting /keys to...\n" .. all_keys .. "\n");
        wmii.write ("/keys", all_keys)
end


-- ------------------------------------------------------------------------
-- event handlers

local ev_handlers = {
        ["*"] = function (ev, arg)
                my_log ("ev: " .. ev .. " - " .. arg)
        end,

        ClientMouseDown = function (ev, arg)
                my_log ("ClientMouseDown: " .. arg)
        end,

        CreateTag = function (ev, arg)
                my_log ("CreateTag: " .. arg)
        end,

        DestroyTag = function (ev, arg)
                my_log ("DestroyTag: " .. arg)
        end,

        FocusTag = function (ev, arg)
                my_log ("FocusTag: " .. arg)
        end,

        Key = function (ev, arg)
                my_log ("Key: " .. arg)
                local num = nil
                -- can we find an exact match?
                local fn = key_handlers[arg]
                if not fn then
                        local key = arg:gsub("-%d+", "-#")
                        -- can we find a match with a # wild card for the number
                        fn = key_handlers[key]
                        if fn then
                                -- convert the trailing number to a number
                                num = tonumber(arg:match("-(%d+)"))
                        else
                                -- everything else failed, try default match
                                fn = key_handlers["*"]
                        end
                end
                if fn then
                        fn (arg, num)
                end
        end,

        LeftBarClick = function (ev, arg)
                my_log ("LeftBarClick: " .. arg)
        end,

        NotUrgentTag = function (ev, arg)
                my_log ("NotUrgentTag: " .. arg)
        end,

        Start = function (ev, arg)
                if arg == "wmiirc" then
                        posix.exit (0)
                end
        end,

        UnfocusTag = function (ev, arg)
                my_log ("UnfocusTag: " .. arg)
        end,

        UrgentTag = function (ev, arg)
                my_log ("UrgentTag: " .. arg)
        end
}

-- ------------------------------------------------------------------------
-- reading events
my_log("wmii: starting event loop")
local ev, arg
for ev, arg in wmii.ievents() do

        local fn = ev_handlers[ev] or ev_handlers["*"]
        if fn then
                fn (ev, arg)
        end
end
my_log("wmii: event loop exited")
