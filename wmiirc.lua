#!/usr/bin/env lua
--
-- Copyrigh (c) 2007, Bart Trojanowski <bart@jukie.net>
--
-- Some stuff below will eventually go to a separate file, and configuration 
-- will remain here similar to the split between the wmii+ruby wmiirc and
-- wmiirc-config.  For now I just want to get the feel of how things will 
-- work in lua.
--
-- http://www.jukie.net/~bart/blog/tag/wmiirc-lua
-- git://www.jukie.net/wmiirc-lua.git/
--

io.stderr:write ("----------------------------------------------\n")

-- load wmii.lua
package.path = package.path
               .. ";" .. os.getenv("HOME") .. "/.wmii-3.5/core/?.lua"
               .. ";" .. os.getenv("HOME") .. "/.wmii-3.5/plugins/?.lua"
require "wmii" 

-- This is the base configuration of wmii, it writes to the /ctl file.
wmii.set_ctl ({
        view        = 1,
        border      = 1,
        font        = '-windows-proggytiny-medium-r-normal--10-80-96-96-c-60-iso8859-1',
        focuscolors = '#FFFFaa #007700 #88ff88',
        normcolors  = '#888888 #222222 #333333',
        grabmod     = 'Mod1'
})

-- This overrides some variables that are used by event and key handlers.
--   TODO: need to have a list of the standard ones somewhere.
--         For now look in the wmii.lua for the key_handlers table, it
--         will reference the variables as getconf("varname").
-- If you add your own actions, or key handlers you are encouraged to 
-- use configuration values as appropriate with wmii.setconf("var", "val"), or
-- as a table like the example below.
wmii.set_conf ({
        xterm = 'x-terminal-emulator'
})

-- colrules file contains a list of rules which affect the width of newly 
-- created columns.  Rules have a form of
--      /regexp/ -> width[+width[+width...]]
-- When a new column, n, is created on a view whose name matches regex, the
-- n'th given width percentage of the screen is given to it.  If there is 
-- no nth width, 1/ncolth of the screen is given to it.
--
wmii.write ("/colrules", "/.*/ -> 50+50\n"
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

-- load some plugins
wmii.load_plugin ("messages")
wmii.load_plugin ("clock")
wmii.load_plugin ("dstat_load")

-- ------------------------------------------------------------------------
-- configuration is finished, run the event loop
wmii.run_event_loop()

