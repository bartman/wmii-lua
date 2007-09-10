--
-- Copyrigh (c) 2007, Bart Trojanowski <bart@jukie.net>
--
-- Simple wmiir like interface.
--
-- The current intent is to wrap around the wmiir executable.
-- This is just a proof of concept, and eventually this will 
-- be rewritten in C to use libixp.
-- 
-- git://www.jukie.net/wmiirc-lua.git/

package.cpath = package.cpath .. ";" .. os.getenv("HOME") .. "/.wmii-3.5/ixp/?.so"
require "ixp"
local ixp = ixp

local base = _G
local io = require("io")
local os = require("os")
local posix = require("posix")
local string = require("string")
local table = require("table")
local math = require("math")
local type = type
local error = error
local print = print
local pairs = pairs
local tostring = tostring
local tonumber = tonumber

module("wmii")

-- ========================================================================
-- MODULE VARIABLES
-- ========================================================================

-- wmiir points to the wmiir executable
local wmiir = "wmiir"

-- wmii_adr is the address we use when connecting using ixp
local wmii_adr = os.getenv("WMII_ADDRESS")
        or ("unix!/tmp/ns." ..  os.getenv("USER") ..  "." 
            .. os.getenv("DISPLAY"):match("(:%d+)") .. "/wmii")

-- wmixp is the ixp context we use to talk to wmii
local wmixp = ixp.new(wmii_adr)

-- history of previous views, view_hist[#view_hist] is the last one
local view_hist = {}                  -- sorted with 1 being the oldest
local view_hist_max = 10              -- max number to keep track of

-- ========================================================================
-- LOCAL HELPERS
-- ========================================================================

-- ------------------------------------------------------------------------
-- log, right now write to stderr
function log (str)
        io.stderr:write (str .. "\n")
end

-- ========================================================================
-- MAIN ACCESS FUNCTIONS
-- ========================================================================

-- ------------------------------------------------------------------------
-- returns an iterator
function ls (dir, fmt)
        local verbose = fmt and fmt:match("l")

        local s = wmixp:stat(dir)
        if not s then
                return function () return nil end
        end
        if s.modestr:match("^[^d]") then
                return function ()
                        return stat2str(verbose, s)
                end
        end

        local itr = wmixp:idir (dir)
        if not itr then
                --return function ()
                        return nil
                --end
        end


        return function ()
                local s = itr()
                if s then
                        return stat2str(verbose, s)
                end
                return nil
        end
end

function stat2str(verbose, stat)
        if verbose then
                return string.format("%s %s %s %5d %s %s", stat.modestr, stat.uid, stat.gid, stat.length, stat.timestr, stat.name)
        else
                if stat.modestr:match("^d") then
                        return stat.name .. "/"
                else
                        return stat.name
                end
        end
end

-- ------------------------------------------------------------------------
-- read all contents of a wmii virtual file
function read (file)
        return wmixp:read (file)
end

-- ------------------------------------------------------------------------
-- return an iterator which walks all the lines in the file
--
-- example:
--     for event in wmii.iread("/event")
--         ...
--     end
function iread (file)
        return wmixp:iread(file)
end

-- ------------------------------------------------------------------------
-- returns an events iterator
function ievents ()
        local it = iread("/event")

        return function ()
                local line = it()
                return string.match(line, "(%S+)%s(.+)")
        end
end

-- ------------------------------------------------------------------------
-- create a wmii file, optionally write data to it
function create (file, data)
        wmixp:create(file, data)
end

-- ------------------------------------------------------------------------
-- remove a wmii file
function remove (file)
        wmixp:remove(file)
end

-- ------------------------------------------------------------------------
-- write a value to a wmii virtual file system
function write (file, value)
        wmixp:write (file, value)
end

-- ------------------------------------------------------------------------
-- displays the menu given an table of entires, returns selected text
function menu (tbl)

        local infile = os.tmpname()
        local fh = io.open (infile, "w+")

        for n in pairs(tbl) do
                fh:write (n)
                fh:write ("\n")
        end
        fh:close()

        local outfile = os.tmpname()

        os.execute ("dmenu < " .. infile .. " > " .. outfile)

        fh = io.open (outfile, "r")
        os.remove (outfile)

        local sel = fh:read("*l")
        fh:close()

        return sel
end

-- ------------------------------------------------------------------------
-- displays the a tag selection menu, returns selected tag
function tagmenu ()
        local tmpfile = os.tmpname()

        os.execute ("wmiir ls /tag | sed 's|/||; /^sel$/d' | dmenu > " .. tmpfile)

        local fh = io.open (tmpfile, "rb")
        os.remove (tmpfile)

        local tag = fh:read("*l")
        io.close (fh)

        return tag
end

-- ------------------------------------------------------------------------
-- displays the a program menu, returns selected program
function progmenu ()
        local tmpfile = os.tmpname()

        os.execute ("dmenu_path | dmenu > " .. tmpfile)

        local fh = io.open (tmpfile, "rb")
        os.remove (tmpfile)

        local prog = fh:read("*l")
        io.close (fh)

        return prog
end

-- ------------------------------------------------------------------------
-- displays the a program menu, returns selected program
function gettags()
        local t = {}
        local s
        for s in wmixp:idir ("/tag") do
                if s.name and not (s.name == "sel") then
                        t[#t + 1] = s.name
                end
        end
        table.sort(t)
        return t
end

-- ------------------------------------------------------------------------
-- displays the a program menu, returns selected program
function getview()
        local v = wmixp:read("/ctl") or ""
        return v:match("view%s+(%S+)")
end

-- ------------------------------------------------------------------------
-- changes the current view
--   if the argument is a number it shifts the view left or right by that count
--   if the argument is a string it moves to that view name
function setview(sel)
        local cur = getview()
        local all = gettags()

        if #all < 2 then
                -- nothing to do if we have less then 2 tags
                return

        elseif type(sel) == "number" then
                -- range check
                if (sel < - #all) or (sel > #all) then
                        error ("view selector is out of range")
                end

                -- find the one that's selected index
                local curi = nil
                local i,v
                for i,v in pairs (all) do
                        if v == cur then curi = i end
                end

                -- adjust by index
                local newi = math.fmod(#all + curi + sel - 1, #all) + 1
                if (newi < - #all) or (newi > #all) then
                        error ("error computng new view")
                end

                sel = all[newi]

        elseif not (type(sel) == "string") then
                error ("number or string argument expected")
        end

        -- set new view
        write ("/ctl", "view " .. sel)
end

function toggleview()
        local last = view_hist[#view_hist]
        if last then
                setview(last)
        end
end

-- ========================================================================
-- ACTION HANDLERS
-- ========================================================================

local action_handlers = {
        quit = function ()
                write ("/ctl", "quit")
        end,

        exec = function (act, args)
                local what = args or wmiirc
                write ("/ctl", "exec " .. what)
        end,

        wmiirc = function ()
                posix.exec ("lua", wmiirc)
        end,

        rehash = function ()
                -- TODO: consider storing list of executables around, and 
                -- this will then reinitialize that list
                log ("    TODO: rehash")
        end,

        status = function ()
                -- TODO: this should eventually update something on the /rbar
                log ("    TODO: status")
        end
}

-- ========================================================================
-- KEY HANDLERS
-- ========================================================================

local key_handlers = {
        ["*"] = function (key)
                log ("*: " .. key)
        end,

        -- execution and actions
        ["Mod1-Return"] = function (key)
                local xterm = getconf("xterm")
                log ("    executing: " .. xterm)
                os.execute (xterm .. " &")
        end,
        ["Mod1-a"] = function (key)
                local text = menu (action_handlers)
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
                local prog = progmenu()
                if prog then
                        log ("    executing: " .. prog)
                        os.execute (prog .. " &")
                end
        end,
        ["Mod1-Shift-c"] = function (key)
                write ("/client/sel/ctl", "kill")
        end,

        -- HJKL active selection
        ["Mod1-h"] = function (key)
                write ("/tag/sel/ctl", "select left")
        end,
        ["Mod1-l"] = function (key)
		write ("/tag/sel/ctl", "select right")
        end,
        ["Mod1-j"] = function (key)
		write ("/tag/sel/ctl", "select down")
        end,
        ["Mod1-k"] = function (key)
		write ("/tag/sel/ctl", "select up")
        end,

        -- HJKL movement
        ["Mod1-Shift-h"] = function (key)
                write ("/tag/sel/ctl", "send sel left")
        end,
        ["Mod1-Shift-l"] = function (key)
		write ("/tag/sel/ctl", "send sel right")
        end,
        ["Mod1-Shift-j"] = function (key)
		write ("/tag/sel/ctl", "send sel down")
        end,
        ["Mod1-Shift-k"] = function (key)
		write ("/tag/sel/ctl", "send sel up")
        end,

        -- floating vs tiled
        ["Mod1-space"] = function (key)
                write ("/tag/sel/ctl", "select toggle")
        end,
        ["Mod1-Shift-space"] = function (key)
                write ("/tag/sel/ctl", "send sel toggle")
        end,

        -- work spaces
        ["Mod4-#"] = function (key, num)
                setview (tostring(num))
        end,
        ["Mod4-Shift-#"] = function (key, num)
                write ("/client/sel/tags", tostring(num))
        end,
        ["Mod1-comma"] = function (key)
                setview (-1)
        end,
        ["Mod1-period"] = function (key)
                setview (1)
        end,
        ["Mod1-r"] = function (key)
                toggleview()
        end,

        -- switching views and retagging
        ["Mod1-t"] = function (key)
                local tag = tagmenu()
                if tag then
                        setview (tag)
                end

        end,
        ["Mod1-Shift-t"] = function (key)
                local tag = tagmenu()
                if tag then
                        local cli = read ("/client/sel/ctl")
                        write ("/client/" .. cli .. "/tags", tag)
                end
        end,
        ["Mod1-Control-t"] = function (key)
                log ("    TODO: Mod1-Control-t: " .. key)
        end,

        -- column modes
        ["Mod1-d"] = function (key)
		write("/tag/sel/ctl", "colmode sel default")
        end,
        ["Mod1-s"] = function (key)
		write("/tag/sel/ctl", "colmode sel stack")
        end,
        ["Mod1-m"] = function (key)
		write("/tag/sel/ctl", "colmode sel max")
        end
}

-- ------------------------------------------------------------------------
-- update the /keys wmii file with the list of all handlers

function update_active_keys ()
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
        --log ("setting /keys to...\n" .. all_keys .. "\n");
        --write ("/keys", all_keys)
end


-- ========================================================================
-- EVENT HANDLERS
-- ========================================================================

local ev_handlers = {
        ["*"] = function (ev, arg)
                log ("ev: " .. ev .. " - " .. arg)
        end,

        -- exit if another wmiirc started up
        Start = function (ev, arg)
                if arg == "wmiirc" then
                        posix.exit (0)
                end
        end,

        -- tag management
        CreateTag = function (ev, arg)
                local fc = getctl("focuscolors") or ""
                create ("/lbar/" .. arg, fc .. " " .. arg)
        end,
        DestroyTag = function (ev, arg)
                remove ("/lbar/" .. arg)
        end,

        FocusTag = function (ev, arg)
                local fc = getctl("focuscolors") or ""
                log ("FocusTag: " .. arg:gsub("%W",".") .. '--')
                create ("/lbar/" .. arg, fc .. " " .. arg)
                write ("/lbar/" .. arg, fc .. " " .. arg)
        end,
        UnfocusTag = function (ev, arg)
                local nc = getctl("normcolors") or ""
                log ("UnfocusTag: " .. arg:gsub("%W",".") .. '--')
                create ("/lbar/" .. arg, nc .. " " .. arg)
                write ("/lbar/" .. arg, nc .. " " .. arg)

                -- don't duplicate the last entry
                if not (arg == view_hist[#view_hist]) then
                        view_hist[#view_hist+1] = arg

                        -- limit to view_hist_max
                        if #view_hist > view_hist_max then
                                table.remove(view_hist, 1)
                        end
                end
        end,

        -- key event handling
        Key = function (ev, arg)
                log ("Key: " .. arg)
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

        -- mouse handling on the lbar
        LeftBarClick = function (ev, arg)
                local button,tag = string.match(arg, "(%w+)%s+(%w+)")
                setview (tag)
        end,

        -- focus updates
        ClientFocus = function (ev, arg)
                log ("ClientFocus: " .. arg)
        end,
        ColumnFocus = function (ev, arg)
                log ("ColumnFocus: " .. arg)
        end,

        -- urgent tag?
        UrgentTag = function (ev, arg)
                log ("UrgentTag: " .. arg)
		-- wmiir xwrite "/lbar/$@" "*$@"
        end,
        NotUrgentTag = function (ev, arg)
                log ("NotUrgentTag: " .. arg)
		-- wmiir xwrite "/lbar/$@" "$@"
        end

}

-- ========================================================================
-- MAIN INTERFACE FUNCTIONS
-- ========================================================================

local config = {
        xterm = 'x-terminal-emulator'
}

-- ------------------------------------------------------------------------
-- write configuration to /ctl wmii file
--   setctl({ "var" = "val", ...})
--   setctl("var, "val")
function setctl (first,second)
        if type(first) == "table" and second == nil then
                local x, y
                for x, y in pairs(first) do
                        write ("/ctl", x .. " " .. y)
                end

        elseif type(first) == "string" and type(second) == "string" then
                write ("/ctl", first .. " " .. second)

        else
                error ("expecting a table or two string arguments")
        end
end

-- ------------------------------------------------------------------------
-- read a value from /ctl wmii file
function getctl (name)
        local s
        for s in iread("/ctl") do
                local var,val = s:match("(%w+)%s+(.+)")
                if var == name then
                        return val
                end
        end
        return nil
end

-- ------------------------------------------------------------------------
-- set an internal wmiirc.lua variable
--   setconf({ "var" = "val", ...})
--   setconf("var, "val")
function setconf (first,second)
        if type(first) == "table" and second == nil then
                local x, y
                for x, y in pairs(first) do
                        config[x] = y
                end

        elseif type(first) == "string" and type(second) == "string" then
                config[first] = second

        else
                error ("expecting a table or two string arguments")
        end
end

-- ------------------------------------------------------------------------
-- read an internal wmiirc.lua variable
function getconf (name)
        return config[name]
end

-- ------------------------------------------------------------------------
-- run the event loop and process events, this function does not exit
function run_event_loop ()

        log("wmii: updating active keys")

        update_active_keys ()

        log("wmii: starting event loop")
        local ev, arg
        for ev, arg in ievents() do

                local fn = ev_handlers[ev] or ev_handlers["*"]
                if fn then
                        fn (ev, arg)
                end
        end
        log("wmii: event loop exited")
end

