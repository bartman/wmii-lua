--
-- Copyright (c) 2007, Bart Trojanowski <bart@jukie.net>
--
-- Simple load applet for wmii bar.
--
-- NOTE: dstat is required.
--
local wmii = require("wmii")
local os = require("os")
local type = type

module("dstat_load")

widget = wmii.widget:new ("800_dstat_load")
wmii.add_exec ("TERM=vt100 dstat --load --nocolor --noheaders --noupdate 1",
                function (line)
                        if not (type(line) == "string") then
                                return
                        end

                        local line = line:gsub ("%W%W+", " ")
                        if line:len() > 3 then
                                widget:show (line)
                        end
                end)
