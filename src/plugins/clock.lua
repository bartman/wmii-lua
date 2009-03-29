--
-- Copyright (c) 2007, Bart Trojanowski <bart@jukie.net>
--
-- Simple clock applet for wmii bar.
--
local wmii = require("wmii")
local os = require("os")

module("clock")         -- module name
api_version=0.1         -- api version, see doc/plugin-api

-- ------------------------------------------------------------
-- CLOCK CONFIGURATION VARIABLES
--
-- these can be overridden by wmiirc

wmii.set_conf ("clock.update", 1)
wmii.set_conf ("clock.format", "%Y/%m/%d %H:%M:%S")

-- ------------------------------------------------------------
-- MODULE VARIABLES

local widget = nil       -- the display on the bar
local timer = nil       -- the 1/second tick timer

-- ------------------------------------------------------------
-- THE TIMER WIDGET
--
-- Note that widgets are sorted in ascending order from left to
-- right on wmii's bar.  By convention this is a 3 digit number
-- and is prefixed to the widget name. There is currently no 
-- way to reorder a widget, but it is planed for a future release.
--
local widget = wmii.widget:new ("999_clock")

local xmessagebox = "xmessage -center -buttons quit:0 -default quit -file -"
local function button_handler (ev, button)
	-- 3 is right button
	if button == 3 then
		os.execute("ncal -y | wmiisetsid " .. xmessagebox .. "&")
	end
end

widget:add_event_handler("RightBarClick", button_handler)



-- ------------------------------------------------------------
-- THE TIMER FUNCTION
--
-- The timer function will be called every X seconds.  If the 
-- timer function returns a number 

local function clock_timer (time_since_update)
        local fmt = wmii.get_conf("clock.format") or "%c"
        widget:show (os.date(fmt))

        -- returning a positive number of seconds before next wakeup, or
        -- nil (or no return at all) repeats the last schedule, or
        -- -1 to stop the timer
        return 1
end

local timer = wmii.timer:new (clock_timer, 1)

