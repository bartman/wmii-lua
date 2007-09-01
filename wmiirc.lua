#!/usr/bin/env lua

require "wmii"

local config = {
        border      = 1,
        font        = '-windows-proggytiny-medium-r-normal--10-80-96-96-c-60-iso8859-1',
        focuscolors = '#FFFFaa #007700 #88ff88',
        normcolors  = '#888888 #222222 #333333',
        grabmod     = 'Mod1'
}
wmii.configure (config)

