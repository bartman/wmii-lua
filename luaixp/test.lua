#!/usr/bin/env lua

require "ixp"

print ("testing...")
ixp.test ()

print ("create new ixp...")
x = ixp.new("unix!/tmp/ns.bart.:0/wmii")

print ("testing...")
x:test ()


print ("writing...")
x:write ("/lbar/1", '#FF0000 #00FF00 #0000FF 1xxx')

print ("reading...")
data = x:read ("/lbar/1")
print (data)

print ("stating...")
data = x:stat ("/event")
for k,v in pairs (data) do
        local hex = ""
        if type(v) == "number" then
                hex = string.format(" (0x%x)",v)
        end
        print ("  "..k.." = " .. tostring(v) .. hex)
end

print ("directory list...")
for data in x:idir ("/") do
        local slash = ""
        if data.modestr:match("^d") then
                slash = "/"
        end
        print ("  " .. data.name .. slash)
end


print ("iterating...")
for ev in x:iread("/event") do
        print ("ev: '" .. ev .. "'")
end

print ("finished!")
