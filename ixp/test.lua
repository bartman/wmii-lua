#!/usr/bin/env lua

require "ixp"

print ("testing...")
ixp.test ()

print ("writing...")
ixp.write ("/lbar/1", '#FF0000 #00FF00 #0000FF 1xxx')

print ("reading...")
data = ixp.read ("/lbar/1")
print (data)

print ("stating...")
data = ixp.stat ("/event")
for k,v in pairs (data) do
        local hex = ""
        if type(v) == "number" then
                hex = string.format(" (0x%x)",v)
        end
        print ("  "..k.." = " .. tostring(v) .. hex)
end

print ("directory list...")
for data in ixp.idir ("/") do
        local slash = ""
        if data.modestr:match("^d") then
                slash = "/"
        end
        print ("  " .. data.name .. slash)
end


--[[
print ("iterating...")
for ev in ixp.iread("/event") do
        print (ev)
end
]]--
