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

print ('-----------------------')

-- this is us
local wmiirc = os.getenv("HOME") .. "/.wmii-3.5/wmiirc"

-- load wmii.lua
package.path = package.path .. ";" .. os.getenv("HOME") .. "/.wmii-3.5/?.lua"
require "wmii" 

wmii.log("wmii: wmii.lua loaded")

-- stop any other instance of wmiirc
wmii.write ("/event", "Start wmiirc")

-- this is the base configuration
local config = {
        xterm = 'x-terminal-emulator'
}
wmii.log("wmii: setting confg")
wmii.setctl ({
        view        = 1,
        border      = 1,
        font        = '-windows-proggytiny-medium-r-normal--10-80-96-96-c-60-iso8859-1',
        focuscolors = '#FFFFaa #007700 #88ff88',
        normcolors  = '#888888 #222222 #333333',
        grabmod     = 'Mod1'
})

wmii.log("wmii: config set")

wmii.write ("/colrules", "/.*/ -> 58+42")
wmii.write ("/tagrules", "/XMMS.*/ -> ~\n"
                      .. "/MPlayer.*/ -> ~\n"
                      .. "/.*/ -> sel\n"
                      .. "/.*/ -> 1\n")


-- ------------------------------------------------------------------------
-- configuration is finished, run the event loop
wmii.run_event_loop()

