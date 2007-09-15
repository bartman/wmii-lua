--
-- Copyright (c) 2007, Bart Trojanowski <bart@jukie.net>
--
-- Simple load applet for wmii bar.
--
-- NOTE: dstat is required.
--
local wmii = require("wmii")
local os = require("os")

module("dstat_load")

widget = wmii.widget:new ("800_dstat_load")
wmii.add_exec ("dstat --load --nocolor --noheaders --noupdate 1",
                function (line)
                        widget:show (line)
                end)
