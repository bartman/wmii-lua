--
-- Copyright (c) 2007, Bart Trojanowski <bart@jukie.net>
--
-- WMII event loop, in lua
--
-- http://www.jukie.net/~bart/blog/tag/wmiirc-lua
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

    -- Write something to the wmii filesystem, in this case a key event.
    wmii.write ("/event", "Key Mod1-j")

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

local wmiidir = os.getenv("HOME") .. "/.wmii-3.5"
local wmiirc = wmiidir .. "/wmiirc"

package.path = package.path
               .. ";" .. os.getenv("HOME") .. "/.wmii-3.5/plugins/?.lua"
package.cpath = package.cpath
                .. ";" .. os.getenv("HOME") .. "/.wmii-3.5/core/?.so"
                .. ";" .. os.getenv("HOME") .. "/.wmii-3.5/plugins/?.so"

local ixp = require "ixp"
local eventloop = require "eventloop"

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
local pcall = pcall
local pairs = pairs
local package = package
local require = require
local tostring = tostring
local tonumber = tonumber
local setmetatable = setmetatable

module("wmii")

-- get the process id
local mypid = posix.getprocessid("pid")

-- ========================================================================
-- MODULE VARIABLES
-- ========================================================================

-- wmiir points to the wmiir executable
-- TODO: need to make sure that wmiir is in path, and if not find it
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
--     for event in wmii.iread("/ctl")
--         ...
--     end
--
-- NOTE: don't use iread for files that could block, as this will interfere
-- with timer processing and event delivery.  Instead fork off a process to
-- execute wmiir and read back the responses via callback.
function iread (file)
        return wmixp:iread(file)
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
-- changes the current view to the name given
function set_view(sel)
        local cur = get_view()
        local all = get_tags()

        if #all < 2 or sel == cur then
                -- nothing to do if we have less then 2 tags
                return
        end

        if not (type(sel) == "string") then
                error ("string argument expected")
        end

        -- set new view
        write ("/ctl", "view " .. sel)
end

-- ------------------------------------------------------------------------
-- changes the current view to the index given
function set_view_index(sel)
        local cur = get_view()
        local all = get_tags()

        if #all < 2 then
                -- nothing to do if we have less then 2 tags
                return
        end

        local num = tonumber (sel)
        if not num then
                error ("number argument expected")
        end

        local name = all[sel]
        if not name or name == cur then
                return
        end

        -- set new view
        write ("/ctl", "view " .. name)
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
        man = function (act, args)
                local xterm = get_conf("xterm") or "xterm"
                local page = args
                if (not page) or (not page:match("%S")) then
                        page = wmiidir .. "/wmii.3lua"
                end
                local cmd = xterm .. " -e man " .. page .. " &"
                log ("    executing: " .. cmd)
                os.execute (cmd)
        end,

        quit = function ()
                write ("/ctl", "quit")
        end,

        exec = function (act, args)
                local what = args or wmiirc
                cleanup()
                write ("/ctl", "exec " .. what)
        end,

        wmiirc = function ()
                cleanup()
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

--[[
=pod

=item add_action_handler (action, fn)

Add an Alt-a action handler callback function, I<fn>, for the given action string I<action>.

=cut
--]]
function add_action_handler (action, fn)

	if type(action) ~= "string" or type(fn) ~= "function" then
		error ("expecting a string and a function")
	end

	if action_handlers[action] then
		error ("action handler already exists for '" .. action .. "'")
	end

	action_handlers[action] = fn
end

--[[
=pod

=item remove_action_handler (action)

Remove an action handler callback function for the given action string I<action>.

=cut
--]]
function remove_action_handler (action)

	action_handlers[action] = nil
end

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
                        log ("Action: " .. text)
                        local act = text
                        local args = nil
                        local si = text:find("%s")
                        if si then
                                act,args = string.match(text .. " ", "(%w+)%s(.+)")
                        end
                        if act then
                                local fn = action_handlers[act]
                                if fn then
                                        local r, err = pcall (fn, act, args)
                                        if not r then
                                                log ("WARNING: " .. tostring(err))
                                        end
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
                set_view_index (num)
        end,
        ["Mod4-Shift-#"] = function (key, num)
                write ("/client/sel/tags", tostring(num))
        end,
        ["Mod4-@"] = function (key, letter)
                local all = get_tags()
                local i,v
                for i,v in pairs(all) do
                        if letter == v:sub(1,1) then
                                set_view_index (i)
                                break
                        end
                end
        end,
        ["Mod4-Shift-@"] = function (key, letter)
                local all = get_tags()
                local i,v
                for i,v in pairs(all) do
                        if letter == v:sub(1,1) then
                                write ("/client/sel/tags", v)
                                break
                        end
                end
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

--[[
=pod

=item add_key_handler (key, fn)

Add a keypress handler callback function, I<fn>, for the given key sequence I<key>.

=cut
--]]
function add_key_handler (key, fn)

	if type(key) ~= "string" or type(fn) ~= "function" then
		error ("expecting a string and a function")
	end

	if key_handlers[key] then
		-- TODO: we may wish to allow multiple handlers for one keypress
		error ("key handler already exists for '" .. key .. "'")
	end

	key_handlers[key] = fn
end

--[[
=pod

=item remove_key_handler (key)

Remove an key handler callback function for the given key I<key>.

=cut
--]]
function remove_key_handler (key)

	key_handlers[key] = nil
end

-- ------------------------------------------------------------------------
-- update the /keys wmii file with the list of all handlers
local alphabet="abcdefghijklmnopqrstuvwxyz"
function update_active_keys ()
        local t = {}
        local x, y
        for x,y in pairs(key_handlers) do
                if x:find("%w") then
                        local i = x:find("#$")
                        if i then
                                local j
                                for j=0,9 do
                                        t[#t + 1] = x:sub(1,i-1) .. j
                                end
                        else
                                i = x:find("@$")
                                if i then
                                        local j
                                        for j=1,alphabet:len() do
                                                local a = alphabet:sub(j,j)
                                                t[#t + 1] = x:sub(1,i-1) .. a
                                        end
                                else
                                        t[#t + 1] = tostring(x)
                                end
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

local widget_ev_handlers = {
}

--[[
=pod

=item _handle_widget_event (ev, arg)

Top-level event handler for redispatching events to widgets.  This event
handler is added for any widget event that currently has a widget registered
for it.

Valid widget events are currently

	RightBarMouseDown <buttonnumber> <widgetname>
	RightBarClick <buttonnumber> <widgetname>

the "Click" event is sent on mouseup.

The callbacks are given only the button number as their argument, to avoid the
need to reparse.

=cut
--]]

local function _handle_widget_event (ev, arg)

	log("_handle_widget_event: " .. tostring(ev) .. " - " .. tostring(arg))

	-- parse arg to strip out our widget name
	local number,wname = string.match(arg, "(%d+)%s+(.+)")

	-- check our dispatch table for that widget
	if not wname then
		log("Didn't find wname")
		return
	end

	local wtable = widget_ev_handlers[wname]
	if not wtable then
		log("No widget cares about" .. wname)
		return
	end

	local fn = wtable[ev] or wtable["*"]
	if fn then
		success, err = pcall( fn, ev, tonumber(number) )
		if not success then
			log("Callback had an error in _handle_widget_event: " .. tostring(err) )
			return nil
		end
	else 
		log("no function found for " .. ev)
	end
end

local ev_handlers = {
        ["*"] = function (ev, arg)
                log ("ev: " .. tostring(ev) .. " - " .. tostring(arg))
        end,

	RightBarClick = _handle_widget_event,

        -- process timer events
        ProcessTimerEvents = function (ev, arg)
                process_timers()
        end,

        -- exit if another wmiirc started up
        Start = function (ev, arg)
                if arg then
                        if arg == "wmiirc" then
                                -- backwards compatibility with bash version
                                cleanup()
                                os.exit (0)
                        else
                                -- ignore if it came from us
                                local pid = string.match(arg, "wmiirc (%d+)")
                                if pid then
                                        local pid = tonumber (pid)
                                        if not (pid == mypid) then
                                                cleanup()
                                                os.exit (0)
                                        end
                                end
                        end
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
                local magic = nil
                -- can we find an exact match?
                local fn = key_handlers[arg]
                if not fn then
                        local key = arg:gsub("-%d$", "-#")
                        -- can we find a match with a # wild card for the number
                        fn = key_handlers[key]
                        if fn then
                                -- convert the trailing number to a number
                                magic = tonumber(arg:match("-(%d)$"))
                        end
                end
                if not fn then
                        local key = arg:gsub("-%a$", "-@")
                        -- can we find a match with a @ wild card for a letter
                        fn = key_handlers[key]
                        if fn then
                                -- split off the trailing letter
                                magic = arg:match("-(%a)$")
                        end
                end
                if not fn then
                        -- everything else failed, try default match
                        fn = key_handlers["*"]
                end
                if fn then
                        local r, err = pcall (fn, arg, magic)
                        if not r then
                                log ("WARNING: " .. tostring(err))
                        end
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

--[[
=pod

=item add_widget_event_handler (wname, ev, fn)

Add an event handler callback for the I<ev> event on the widget named I<wname>

=cut
--]]
--
function add_widget_event_handler (wname, ev, fn)
	if type(wname) ~= "string" or type(ev) ~= "string" or type(fn) ~= "function" then
		error ("expecting string for widget name, string for event name and a function callback")
	end

	-- Make sure the widget event handler is present
	if not ev_handlers[ev] then
		ev_handlers[ev] = _handle_widget_event
	end

	if not widget_ev_handlers[wname] then
		widget_ev_handlers[wname] = { }
	end

	if widget_ev_handlers[wname][ev] then
		-- TODO: we may wish to allow multiple handlers for one event
		error ("event handler already exists on widget '" .. wname .. "' for '" .. ev .. "'")
	end

	widget_ev_handlers[wname][ev] = fn
end

--[[
=pod

=item remove_widget_event_handler (wname, ev)

Remove an event handler callback function for the I<ev> on the widget named I<wname>.

=cut
--]]
function remove_event_handler (wname, ev)

	if not widget_ev_handlers[wname] then
		return
	end

	widget_ev_handlers[wname][ev] = nil
end

--[[
=pod

=item add_event_handler (ev, fn)

Add an event handler callback function, I<fn>, for the given event I<ev>.

=cut
--]]
-- TODO: Need to allow registering widgets for RightBar* events.  Should probably be done with its own event table, though
function add_event_handler (ev, fn)
	if type(ev) ~= "string" or type(fn) ~= "function" then
		error ("expecting a string and a function")
	end

	if ev_handlers[ev] then
		-- TODO: we may wish to allow multiple handlers for one event
		error ("event handler already exists for '" .. ev .. "'")
	end


	ev_handlers[ev] = fn
end

--[[
=pod

=item remove_event_handler (ev)

Remove an event handler callback function for the given event I<ev>.

=cut
--]]
function remove_event_handler (ev)

	ev_handlers[ev] = nil
end


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

-- ========================================================================
-- THE EVENT LOOP
-- ========================================================================

-- the event loop instance
local el = eventloop.new()

-- add the core event handler for events
el:add_exec (wmiir .. " read /event",
        function (line)
                local line = line or "nil"

                -- try to split off the argument(s)
                local ev,arg = string.match(line, "(%S+)%s+(.+)")
                if not ev then
                        ev = line
                end

                -- now locate the handler function and call it
                local fn = ev_handlers[ev] or ev_handlers["*"]
                if fn then
                        local r, err = pcall (fn, ev, arg)
                        if not r then
                                log ("WARNING: " .. tostring(err))
                        end
                end
        end)

-- ------------------------------------------------------------------------
-- run the event loop and process events, this function does not exit
function run_event_loop ()
        -- stop any other instance of wmiirc
        wmixp:write ("/event", "Start wmiirc " .. tostring(mypid))

        log("wmii: updating lbar")

        update_displayed_tags ()

        log("wmii: updating rbar")

        update_displayed_widgets ()

        log("wmii: updating active keys")

        update_active_keys ()

        log("wmii: starting event loop")
        while true do
                local sleep_for = process_timers()
                el:run_loop(sleep_for)
        end
end

-- ========================================================================
-- PLUGINS API
-- ========================================================================

api_version = 0.1       -- the API version we export

plugins = {}            -- all plugins that were loaded

-- ------------------------------------------------------------------------
-- plugin loader which also verifies the version of the api the plugin needs
--
-- here is what it does
--   - does a manual locate on the file using package.path
--   - reads in the file w/o using the lua interpreter
--   - locates api_version=X.Y string
--   - makes sure that api_version requested can be satisfied
--
-- TODO: currently the api_version must be in an X.Y format, but we may want 
-- to expend this so plugins can say they want '0.1 | 1.3 | 2.0' etc
--
function load_plugin(name)
        local backup_path = package.path or "./?.lua"

        log ("loading " .. name)

        -- this is the version we want to find
        local api_major, api_minor = tostring(api_version):match("(%d+)%.0*(%d+)")
        if (not api_major) or (not api_minor) then
                log ("WARNING: could not parse api_version in core/wmii.lua")
                return nil
        end

        -- first find the plugin file
        local s, path_match, full_name, file
        for s in string.gmatch(package.path, "[^;]+") do
                local fn = s:gsub("%?", name)
                file = io.open(fn, "r")
                if file then
                        path_match = s
                        full_name = fn
                        break
                end
        end

        -- read it in
        local txt
        if file then
                txt = file:read("*all")
                file:close()
        end

        if not txt then
                log ("WARNING: could not load plugin '" .. name .. "'")
                return nil
        end

        -- find the api_version line
        local line, plugin_version
        for line in string.gmatch(txt, "%s*api_version%s*=%s*%d+%.%d+%s*") do
                plugin_version = line:match("api_version%s*=%s*(%d+%.%d+)%s*")
                if plugin_version then
                        break
                end
        end

	if not plugin_version then
		log ("WARNING: could not find api_version string in plugin '" .. name .. "'")
		return nil
	end

        -- decompose the version string
        local plugin_major, plugin_minor = plugin_version:match("(%d+)%.0*(%d+)")
        if (not plugin_major) or (not plugin_minor) then
                log ("WARNING: could not parse api_version for '" .. name .. "' plugin")
                return nil
        end

        -- make a version test
        if plugin_major ~= api_major then
                log ("WARNING: " .. name ..  " plugin major version missmatch, is " .. plugin_version 
                     .. " (api " .. tonumber(api_version) .. ")")
                return nil
        end

        if plugin_minor > api_minor then
                log ("WARNING: '" .. name ..  "' plugin minor version missmatch, is " .. plugin_version 
                     .. " (api " .. tonumber(api_version) .. ")")
                return nil
        end

        -- actually load the module, but use only the path where we though it should be
        package.path = path_match
        local p,err = pcall (require, name)
        package.path = backup_path
        if not p then
                log ("WARNING: failed to load '" .. name .. "' plugin")
                log (" - path: " .. tostring(path_match))
                log (" - file: " .. tostring(full_name))
                log (" - plugin's api_version: " .. tostring(plugin_version))
                log (" - reason: " .. tostring(err))
                return nil
        end

        -- success
        log ("OK, plugin " .. name .. " loaded,  requested api v" .. plugin_version)
        plugins[name] = p
end

-- ------------------------------------------------------------------------
-- widget template
widget = {}
widgets = {}

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

        widgets[name] = o

        o:show()
        return o
end

-- ------------------------------------------------------------------------
-- stop and destroy the timer
function widget:delete ()
        widgets[self.name] = nil
        self:hide()
end

-- ------------------------------------------------------------------------
-- displays or updates the widget text
--
-- examples:
--   w:show("foo")
--   w:show("foo", "#888888 #222222 #333333")
--   w:show("foo", cell_fg .. " " .. cell_bg .. " " .. border)
--
function widget:show (txt, colors)
        local colors = colors or get_ctl("normcolors") or ""
        local txt = txt or self.txt or ""
        local towrite = txt
        if colors then
                towrite = colors .. " " .. towrite
        end
        if not self.txt then
                create ("/rbar/" .. self.name, towrite)
        else
                write ("/rbar/" .. self.name, towrite)
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

--[[
=pod

=item widget:add_event_handler (ev, fn)

Add an event handler callback for this widget, using I<fn> for event I<ev>

=cut
--]]

function widget:add_event_handler (ev, fn)
	add_widget_event_handler( self.name, ev, fn) 
end


-- ------------------------------------------------------------------------
-- remove all /rbar entries that we don't have widget objects for
function update_displayed_widgets ()
        -- colours for /rbar
        local nc = get_ctl("normcolors") or ""

        -- build up a table of existing tags in the /lbar
        local old = {}
        local s
        for s in wmixp:idir ("/rbar") do
                old[s.name] = 1
        end

        -- for all actual widgets in use we want to remove them from the old list
        local i,v
        for i,v in pairs(widgets) do
                old[v.name] = nil
        end

        -- anything left in the old table should be removed now
        for i,v in pairs(old) do
                if v then
                        remove("/rbar/"..i)
                end
        end
end

-- ------------------------------------------------------------------------
-- create a new program and for each line it generates call the callback function
-- returns fd which can be passed to kill_exec()
function add_exec (command, callback)
        return el:add_exec (command, callback)
end

-- ------------------------------------------------------------------------
-- terminates a program spawned off by add_exec()
function kill_exec (fd)
        return el:kill_exec (fd)
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
                if t == self then
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
                error ("timer:resched expected number as argument")
        end

        local now = tonumber(os.date("%s"))

        self.interval = seconds
        self.next_time = now + seconds

        -- resort the timer list
        table.sort (timers, timer.is_less_then)
end

-- helper for sorting timers
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
        local tmr = timers[1]
        if tmr and tmr.next_time then
                local now = tonumber(os.date("%s"))
                local seconds = tmr.next_time - now
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
        local i,tmr

        for i,tmr in pairs (timers) do
                if not tmr then
                        -- prune out removed timers
                        table.remove(timers,i)
                        break

                elseif not tmr.next_time then
                        -- break out once we find a timer that is stopped
                        break

                elseif tmr.next_time > now then
                        -- break out once we get to the future
                        break
                end

                -- this one is good to go
                torun[#torun+1] = tmr
        end

        for i,tmr in pairs (torun) do
                tmr:stop()
                local status,new_interval = pcall (tmr.fn, tmr)
                if status then
                        new_interval = new_interval or self.interval
                        if new_interval and (new_interval ~= -1) then
                                tmr:resched(new_interval)
                        end
                else
                        log ("ERROR: " .. tostring(new_interval))
                end
        end

        local sleep_for = time_before_next_timer_event()
        return sleep_for
end

-- ------------------------------------------------------------------------
-- cleanup everything in preparation for exit() or exec()
function cleanup ()

        local i,v,tmr,p

        log ("wmii: stopping timer events")

        for i,tmr in pairs (timers) do
                pcall (tmr.delete, tmr)
        end
        timers = {}

        log ("wmii: terminating eventloop")

        pcall(el.kill_all,el)

        log ("wmii: disposing of widgets")

        -- dispose of all widgets
        for i,v in pairs(widgets) do
                pcall(v.delete,v)
        end
        timers = {}

        -- FIXME: it doesn't seem to do what I want
        --[[ 
        log ("wmii: releasing plugins")

        for i,p in pairs(plugins) do
                if p.cleanup then
                        pcall (p.cleanup, p)
                end
        end
        plugins = {}
        --]]

        log ("wmii: dormant")
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
