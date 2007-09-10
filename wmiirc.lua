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

io.stderr:write ("----------------------------------------------\n")

-- this is us
local wmiirc = os.getenv("HOME") .. "/.wmii-3.5/wmiirc"

-- load wmii.lua
package.path = package.path .. ";" .. os.getenv("HOME") .. "/.wmii-3.5/?.lua"
require "wmii" 

-- stop any other instance of wmiirc
wmii.write ("/event", "Start wmiirc")

-- this is the base configuration
wmii.setctl ({
        view        = 1,
        border      = 1,
        font        = '-windows-proggytiny-medium-r-normal--10-80-96-96-c-60-iso8859-1',
        focuscolors = '#FFFFaa #007700 #88ff88',
        normcolors  = '#888888 #222222 #333333',
        grabmod     = 'Mod1'
})

wmii.setconf ({
        xterm = 'x-terminal-emulator'
})

-- colrules file contains a list of rules which affect the width of newly 
-- created columns.  Rules have a form of
--      /regexp/ -> width[+width[+width...]]
-- When a new column, n, is created on a view whose name matches regex, the
-- n'th given width percentage of the screen is given to it.  If there is 
-- no nth width, 1/ncolth of the screen is given to it.
--
wmii.write ("/colrules", "/.*/ -> 58+42\n"
                      .. "/gaim/ -> 80+20\n")

-- tagrules file contains a list of riles which affect which tags are 
-- applied to a new client.  Rules has a form of
--      /regexp/ -> tag[+tag[+tag...]]
-- When client's name:class:title matches regex, it is given the 
-- tagstring tag(s).  There are two special tags:
--      sel (or the deprecated form: !) represents the current tag, and
--      ~ which represents the floating layer
wmii.write ("/tagrules", "/XMMS.*/ -> ~\n"
                      .. "/Firefox.*/ -> www\n"
                      .. "/Gimp.*/ -> ~\n"
                      .. "/Gimp.*/ -> gimp\n"
                      .. "/Gaim.*/ -> gaim\n"
                      .. "/MPlayer.*/ -> ~\n"
                      .. "/.*/ -> sel\n"
                      .. "/.*/ -> 1\n")


-- ------------------------------------------------------------------------
-- configuration is finished, run the event loop
wmii.run_event_loop()

