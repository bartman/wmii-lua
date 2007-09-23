--
-- Copyright (c) 2007, Bart Trojanowski <bart@jukie.net>
--
-- Simple load applet for wmii bar.
--
-- NOTE: dstat is required.
--
local wmii = require("wmii")
local os = require("os")
local math = require("math")
local string = require("string")
local type = type
local tonumber = tonumber
local tostring = tostring

module("dstat_load")
api_version=0.1

local palette = { "#888888",
                  "#999988",
                  "#AAAA88",
                  "#BBBB88",

                  "#CCCC88",
                  "#CCBB88",
                  "#CCAA88",

                  "#DD9988",
                  "#EE8888",
                  "#FF4444",
          }

local widget = wmii.widget:new ("800_dstat_load")
wmii.add_exec ("TERM=vt100 dstat --load --nocolor --noheaders --noupdate 1",
                function (line)
                        if type(line) ~= "string" then
                                return
                        end

                        local line = line:gsub ("%W%W+", " ")
                        if line:len() < 5 then
                                return
                        end

                        local tmp = line:match("([%d.]+)%D")
                        local current = tonumber(tmp)

                        local colors = nil
                        if type(current) == "number" then
                                local index = math.min (math.floor(current * (#palette-1)) + 1, #palette)
                                local normal = wmii.get_ctl("normcolors")
                                colors = string.gsub(normal, "^%S+", palette[index], 1)
                        end

                        widget:show (line, colors)
                end)
