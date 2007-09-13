--
-- Copyright (c) 2007, Bart Trojanowski <bart@jukie.net>
--
-- WMII event loop, in lua
--
-- git://www.jukie.net/wmiirc-lua.git/
--

-- ========================================================================
-- DOCUMENTATION
-- ========================================================================
--[[
=pod

=head1 NAME 

wmii.lua - WMII event-loop methods in lua

=head1 SYNOPSIS

    require "wmii"

    -- Write something to the wmii filesystem, in this case a start message.
    wmii.write ("/event", "Start wmiirc")

    -- Set your wmii /ctl parameters
    wmii.set_ctl({
    	font = '....'
    })

    -- Configure wmii.lua parameters
    wmii.set_conf ({
        xterm = 'x-terminal-emulator'
    })

    -- Now start the event loop
    wmii.run_event_loop()

=head1 DESCRIPTION

wmii.lua provides methods for replacing the stock sh-based wmiirc shipped with
wmii 3.6 and newer with a lua-based event loop.

It should be used by your wmiirc

=head1 METHODS

=over 4

=cut
--]]

-- ========================================================================
-- MODULE SETUP
-- ========================================================================

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
local setmetatable = setmetatable

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

-- allow for a client to be forced to a tag
local next_client_goes_to_tag = nil

-- ========================================================================
-- LOCAL HELPERS
-- ========================================================================

--[[
=pod

=item log ( str )

Log the message provided in C<str>

Currently just writes to io.stderr

=cut
--]]
function log (str)
        io.stderr:write (str .. "\n")
end

-- ========================================================================
-- MAIN ACCESS FUNCTIONS
-- ========================================================================

--[[
=pod

=item ls ( dir, fmt )

List the wmii filesystem directory provided in C<dir>, in the format specified
by C<fmt>.  

Returns an iterator of TODO

=cut
--]]
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

local function stat2str(verbose, stat)
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
        local next_timers_on = 0

        return function ()
                local seconds = time_before_next_timer_event()
                if seconds == 0 then
                        seconds = process_timers()
                end
                local line = it(
                        -- iterator gets told how long it can wait for the
                        -- next line to come from the other side
                        seconds,
                        -- this function is executed in case of timeout
                        function ()
                                os.execute(wmiir .. " xwrite "
                                        .. "/event ProcessTimerEvents")
                                return time_before_next_timer_event()
                        end
                )
                local a,b = string.match(line, "(%S+)%s+(.+)") 
                if a then return a,b end
                return line
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
-- setup a table describing dmenu command
local function dmenu_cmd (prompt)
        local cmdt = { "dmenu", "-b" }
        local fn = get_ctl("font")
        if fn then
                cmdt[#cmdt+1] = "-fn"
                cmdt[#cmdt+1] = fn
        end
        local normcolors = get_ctl("normcolors")
        if normcolors then
                local nf, nb = normcolors:match("(#%x+)%s+(#%x+)%s#%x+")
                if nf then
                        cmdt[#cmdt+1] = "-nf"
                        cmdt[#cmdt+1] = "'" .. nf .. "'"
                end
                if nb then
                        cmdt[#cmdt+1] = "-nb"
                        cmdt[#cmdt+1] = "'" .. nb .. "'"
                end
        end
        local focuscolors = get_ctl("focuscolors")
        if focuscolors then
                local sf, sb = focuscolors:match("(#%x+)%s+(#%x+)%s#%x+")
                if sf then
                        cmdt[#cmdt+1] = "-sf"
                        cmdt[#cmdt+1] = "'" .. sf .. "'"
                end
                if sb then
                        cmdt[#cmdt+1] = "-sb"
                        cmdt[#cmdt+1] = "'" .. sb .. "'"
                end
        end
        if prompt then
                cmdt[#cmdt+1] = "-p"
                cmdt[#cmdt+1] = "'" .. prompt .. "'"
        end

        return cmdt
end

-- ------------------------------------------------------------------------
-- displays the menu given an table of entires, returns selected text
function menu (tbl, prompt)
        local dmenu = dmenu_cmd(prompt)

        local infile = os.tmpname()
        local fh = io.open (infile, "w+")

        local i,v
        for i,v in pairs(tbl) do
                if type(i) == 'number' and type(v) == 'string' then
                        fh:write (v)
                else
                        fh:write (i)
                end
                fh:write ("\n")
        end
        fh:close()

        local outfile = os.tmpname()

        dmenu[#dmenu+1] = "<"
        dmenu[#dmenu+1] = infile
        dmenu[#dmenu+1] = ">"
        dmenu[#dmenu+1] = outfile

        local cmd = table.concat(dmenu," ")
        os.execute (cmd)

        fh = io.open (outfile, "r")
        os.remove (outfile)

        local sel = fh:read("*l")
        fh:close()

        return sel
end

-- ------------------------------------------------------------------------
-- displays the a tag selection menu, returns selected tag
function tag_menu ()
        local tags = get_tags()

        return menu(tags, "tag:")
end

-- ------------------------------------------------------------------------
-- displays the a program menu, returns selected program
function prog_menu ()
        local dmenu = dmenu_cmd("cmd:")

        local outfile = os.tmpname()

        dmenu[#dmenu+1] = ">"
        dmenu[#dmenu+1] = outfile

        local cmd = "dmenu_path |" .. table.concat(dmenu," ")
        os.execute (cmd)

        local fh = io.open (outfile, "rb")
        os.remove (outfile)

        local prog = fh:read("*l")
        io.close (fh)

        return prog
end

-- ------------------------------------------------------------------------
-- displays the a program menu, returns selected program
function get_tags()
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
function get_view()
        local v = wmixp:read("/ctl") or ""
        return v:match("view%s+(%S+)")
end

-- ------------------------------------------------------------------------
-- changes the current view
--   if the argument is a number it moves to that view at that index
--   if the argument is a string it moves to that view name
function set_view(sel)
        local cur = get_view()
        local all = get_tags()

        local view_num = nil

        if #all < 2 then
                -- nothing to do if we have less then 2 tags
                return

        elseif type(sel) == "number" then


        elseif not (type(sel) == "string") then
                error ("number or string argument expected")
        end

        -- set new view
        write ("/ctl", "view " .. sel)
end

-- ------------------------------------------------------------------------
-- chnages to current view by offset given
function set_view_ofs(jump)
        local cur = get_view()
        local all = get_tags()

        if #all < 2 then
                -- nothing to do if we have less then 2 tags
                return
        end

        -- range check
        if (jump < - #all) or (jump > #all) then
                error ("view selector is out of range")
        end

        -- find the one that's selected index
        local curi = nil
        local i,v
        for i,v in pairs (all) do
                if v == cur then curi = i end
        end

        -- adjust by index
        local newi = math.fmod(#all + curi + jump - 1, #all) + 1
        if (newi < - #all) or (newi > #all) then
                error ("error computng new view")
        end

        write ("/ctl", "view " .. all[newi])
end

-- ------------------------------------------------------------------------
-- toggle between last view and current view
function toggle_view()
        local last = view_hist[#view_hist]
        if last then
                set_view(last)
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
                local xterm = get_conf("xterm") or "xterm"
                log ("    executing: " .. xterm)
                os.execute (xterm .. " &")
        end,
        ["Mod1-Shift-Return"] = function (key)
                local tag = tag_menu()
                if tag then
                        local xterm = get_conf("xterm") or "xterm"
                        log ("    executing: " .. xterm .. "  on: " .. tag)
                        next_client_goes_to_tag = tag
                        os.execute (xterm .. " &")
                end
        end,
        ["Mod1-a"] = function (key)
                local text = menu(action_handlers, "action:")
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
                local prog = prog_menu()
                if prog then
                        log ("    executing: " .. prog)
                        os.execute (prog .. " &")
                end
        end,
        ["Mod1-Shift-p"] = function (key)
                local tag = tag_menu()
                if tag then
                        local prog = prog_menu()
                        if prog then
                                log ("    executing: " .. prog .. "  on: " .. tag)
                                next_client_goes_to_tag = tag
                                os.execute (prog .. " &")
                        end
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
                set_view (num)
        end,
        ["Mod4-Shift-#"] = function (key, num)
                write ("/client/sel/tags", tostring(num))
        end,
        ["Mod1-comma"] = function (key)
                set_view_ofs (-1)
        end,
        ["Mod1-period"] = function (key)
                set_view_ofs (1)
        end,
        ["Mod1-r"] = function (key)
                -- got to the last view
                toggle_view()
        end,

        -- switching views and retagging
        ["Mod1-t"] = function (key)
                -- got to a view
                local tag = tag_menu()
                if tag then
                        set_view (tag)
                end
        end,
        ["Mod1-Shift-t"] = function (key)
                -- move selected client to a tag
                local tag = tag_menu()
                if tag then
                        write ("/client/sel/tags", tag)
                end
        end,
        ["Mod1-Shift-r"] = function (key)
                -- move selected client to a tag, and follow
                local tag = tag_menu()
                if tag then
                        write ("/client/sel/tags", tag)
                        set_view(tag)
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
        write ("/keys", all_keys)
end

-- ------------------------------------------------------------------------
-- update the /lbar wmii file with the current tags
function update_displayed_tags ()
        -- colours for /lbar
        local fc = get_ctl("focuscolors") or ""
        local nc = get_ctl("normcolors") or ""

        -- build up a table of existing tags in the /lbar
        local old = {}
        local s
        for s in wmixp:idir ("/lbar") do
                old[s.name] = 1
        end

        -- for all actual tags in use create any entries in /lbar we don't have
        -- clear the old table entries if we have them
        local cur = get_view()
        local all = get_tags()
        local i,v
        for i,v in pairs(all) do
                local color = nc
                if cur == v then
                        color = fc
                end
                if not old[v] then
                        create ("/lbar/" .. v, color .. " " .. v)
                end
                write ("/lbar/" .. v, color .. " " .. v)
                old[v] = nil
        end

        -- anything left in the old table should be removed now
        for i,v in pairs(old) do
                if v then
                        remove("/lbar/"..i)
                end
        end
end

-- ========================================================================
-- EVENT HANDLERS
-- ========================================================================

local ev_handlers = {
        ["*"] = function (ev, arg)
                log ("ev: " .. ev .. " - " .. arg)
        end,

        -- process timer events
        ProcessTimerEvents = function (ev, arg)
                process_timers()
        end,

        -- exit if another wmiirc started up
        Start = function (ev, arg)
                if arg == "wmiirc" then
                        os.exit (0)
                end
        end,

        -- tag management
        CreateTag = function (ev, arg)
                local nc = get_ctl("normcolors") or ""
                create ("/lbar/" .. arg, nc .. " " .. arg)
        end,
        DestroyTag = function (ev, arg)
                remove ("/lbar/" .. arg)
        end,

        FocusTag = function (ev, arg)
                local fc = get_ctl("focuscolors") or ""
                create ("/lbar/" .. arg, fc .. " " .. arg)
                write ("/lbar/" .. arg, fc .. " " .. arg)
        end,
        UnfocusTag = function (ev, arg)
                local nc = get_ctl("normcolors") or ""
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
                set_view (tag)
        end,

        -- focus updates
        ClientFocus = function (ev, arg)
                log ("ClientFocus: " .. arg)
        end,
        ColumnFocus = function (ev, arg)
                log ("ColumnFocus: " .. arg)
        end,

        -- client handling
        CreateClient = function (ev, arg)
                if next_client_goes_to_tag then
                        local tag = next_client_goes_to_tag
                        local cli = arg
                        next_client_goes_to_tag = nil
                        write ("/client/" .. cli .. "/tags", tag)
                        set_view(tag)
                end
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
--   wmii.set_ctl({ "var" = "val", ...})
--   wmii.set_ctl("var, "val")
function set_ctl (first,second)
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
function get_ctl (name)
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
--   wmii.set_conf({ "var" = "val", ...})
--   wmii.set_conf("var, "val")
function set_conf (first,second)
        if type(first) == "table" and second == nil then
                local x, y
                for x, y in pairs(first) do
                        config[x] = y
                end

        elseif type(first) == "string" 
                        and (type(second) == "string" 
                                or type(second) == "number") then
                config[first] = second

        else
                error ("expecting a table, or string and string/number as arguments")
        end
end

-- ------------------------------------------------------------------------
-- read an internal wmiirc.lua variable
function get_conf (name)
        return config[name]
end

-- ------------------------------------------------------------------------
-- run the event loop and process events, this function does not exit
function run_event_loop ()
        log("wmii: updating lbar")

        update_displayed_tags ()

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

-- ========================================================================
-- PLUGINS API
-- ========================================================================

-- ------------------------------------------------------------------------
-- widget template
widget = {}

-- ------------------------------------------------------------------------
-- create a widget object and add it to the wmii /rbar
--
-- examples:
--     widget = wmii.widget:new ("999_clock")
--     widget = wmii.widget:new ("999_clock", clock_event_handler)
function widget:new (name, fn)
        o = {}

        if type(name) == "string" then
                o.name = name
                if type(fn) == "function" then
                        o.fn = fn
                end
        else
                error ("expected name followed by an optional function as arguments")
        end

        setmetatable (o,self)
        self.__index = self
        self.__gc = function (o) o:hide() end

        o:show()
        return o
end

-- ------------------------------------------------------------------------
-- stop and destroy the timer
function widget:delete ()
        self:hide()
        -- TBD
end

-- ------------------------------------------------------------------------
-- displays or updates the widget text
function widget:show (txt)
        local txt = txt or ""
        local color = get_ctl("normcolors") or ""
        if not self.txt then
                create ("/rbar/" .. self.name, color .. " " .. txt)
        else
                write ("/rbar/" .. self.name, color .. " " .. txt)
        end
        self.txt = txt
end

-- ------------------------------------------------------------------------
-- hides a widget and removes it from the bar
function widget:hide ()
        if self.txt then
                remove ("/lbar/" .. self.name)
                self.txt = nil
        end
end

-- ------------------------------------------------------------------------
-- timer template
timer = {}
local timers = {}

-- ------------------------------------------------------------------------
-- create a timer object and add it to the event loop
--
-- examples:
--     timer:new (my_timer_fn)
--     timer:new (my_timer_fn, 15)
function timer:new (fn, seconds)
        o = {}

        if type(fn) == "function" then
                o.fn = fn
        else
                error ("expected function followed by an optional number as arguments")
        end

        setmetatable (o,self)
        self.__index = self
        self.__gc = function (o) o:stop() end

        -- add the timer
        timers[#timers+1] = o

        if seconds then
                o:resched(seconds)
        end
        return o
end

-- ------------------------------------------------------------------------
-- stop and destroy the timer
function timer:delete ()
        self:stop()
        local i,t
        for i,t in pairs(timers) do
                if t == timer then
                        table.remove (timers,i)
                        return
                end
        end
end

-- ------------------------------------------------------------------------
-- run the timer given new interval
function timer:resched (seconds)
        local seconds = seconds or self.interval
        if not (type(seconds) == "number") then
                error ("expected number as argument")
        end

        local now = tonumber(os.date("%s"))

        self.interval = seconds
        self.next_time = now + seconds

        -- resort the timer list
        table.sort (timers, timer.is_less_then)
end

function timer:is_less_then(another)
        if not self.next_time then
                return false    -- another is smaller, nil means infinity

        elseif not another.next_time then
                return true     -- self is smaller, nil means infinity

        elseif self.next_time < another.next_time then
                return true     -- self is smaller than another
        end

        return false            -- another is smaller then self
end

-- ------------------------------------------------------------------------
-- stop the timer
function timer:stop ()
        self.next_time = nil

        -- resort the timer list
        table.sort (timers, timer.is_less_then)
end

-- ------------------------------------------------------------------------
-- figure out how long before the next event
function time_before_next_timer_event()
        local timer = timers[1]
        if timer and timer.next_time then
                local now = tonumber(os.date("%s"))
                local seconds = timer.next_time - now
                if seconds > 0 then
                        return seconds
                end
        end
        return 0        -- sleep for ever
end

-- ------------------------------------------------------------------------
-- handle outstanding events
function process_timers ()
        local now = tonumber(os.date("%s"))
        local torun = {}
        local i,timer

        for i,timer in pairs (timers) do
                if (not timer) or (not timer.next_time) then
                        table.remove(timers,i)
                        return 1
                end

                if timer.next_time > now then
                        return timer.next_time - now
                end

                torun[#torun+1] = timer
        end

        for i,timer in pairs (torun) do
                timer:stop()
                local new_interval = timer:fn()
                if not (new_interval == -1) then
                        timer:resched(rc)
                end
        end

        local sleep_for = time_before_next_timer_event()
        return sleep_for
end


-- ========================================================================
-- DOCUMENTATION
-- ========================================================================

--[[
=pod

=back

=head1 ENVIRONMENT

=over 4

=item WMII_ADDRESS

Used to determine location of wmii's listen socket.

=back

=head1 SEE ALSO

L<wmii(1)>, L<lua(1)>

=head1 AUTHOR

Bart Trojanowski B<< <bart@jukie.net> >>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2007, Bart Trojanowski <bart@jukie.net>

This is free software.  You may redistribute copies of it under the terms of
the GNU General Public License L<http://www.gnu.org/licenses/gpl.html>.  There
is NO WARRANTY, to the extent permitted by law.

=cut
--]]
