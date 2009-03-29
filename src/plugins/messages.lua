--
-- Copyright (c) 2007, Bart Trojanowski <bart@jukie.net>
--
-- Notification area for wmii bar
--
-- To get a messages use:
--
--      wmiir xwrite /event msg anything you want to see
--
-- If you have a script that seldom generates one-line events, you can run:
--
--      somescript | sed -u 's/^/msg /' | wmiir write /event
-- or
--      ssh remote tail -F log-file | xargs -n1 -i wmiir xwrite /event "msg {}"
--

local wmii = require("wmii")
local os = require("os")
local math = require("math")
local string = require("string")
local tostring = tostring

module ("messages")
api_version=0.1

-- local variables
local color_index = 0
local colors = {}
local color_start = {{0xFF,0xFF,0xFF}, {0xAA,0x22,0xAA}, {0xFF,0x00,0x00}}
local color_end   = {{0x44,0x44,0x44}, {0x22,0x22,0x22}, {0x33,0x33,0x33}}
local color_steps = 10

-- build up the colours palett
local i,t,r
for i=1,color_steps do
        local x = ""
        for t=1,3 do
                local s=color_start[t]
                local e=color_end[t]
                x = x .. '#'
                for r=1,3 do
                        local d = (e[r] - s[r]) / color_steps
                        local c = math.floor(s[r] + (i * d))
                        x = x .. string.format("%02x", c)
                end
                x = x .. ' '
        end
        colors[i] = x
end

-- get a widget; 0 is the first location in the /rbar, so the middle
local widget = wmii.widget:new ("0")

-- function that cycles the colours
local timer = wmii.timer:new (function (time_since_update)
        color_index = color_index + 1
        if not colors[color_index] then
                return -1
        end

        widget:show (nil, colors[color_index])
        return 1
end)

-- finally, an event we can listen for
wmii.add_event_handler ("msg", function (ev, args)
        wmii.log("msg: " .. tostring(args))

        timer:stop()
        color_index = 1
        widget:show (tostring(args), colors[color_index])
        timer:resched(1)
end)



