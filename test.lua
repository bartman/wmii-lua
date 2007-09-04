#!/usr/bin/env lua

require "wmii"
require "ixp"

wmii.write ("/lbar/1", '#FF0000 #00FF00 #0000FF xxx')

foo = wmii.ls ("/")
io.write ("ls ::\n" .. foo .. "\n")

foo = wmii.ls ("/lbar", "-l")
io.write ("ls -l ::\n" .. foo .. "\n")

foo = wmii.read ("/lbar/1")
io.write ("read /lbar/1 ::\n" .. foo .. "\n\n")


io.write ("read some events...\n")
--[[
for x in wmii.iread("/event") do
        io.write ("ev: " .. x .. "\n")
end
]]--
for x,y in wmii.ievents() do
        io.write ("ev: " .. x .. " - " .. y .. "\n")
end

