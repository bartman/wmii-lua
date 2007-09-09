#!/usr/bin/env lua

require "wmii"

wmii.write ("/lbar/1", '#FF0000 #00FF00 #0000FF xxx')

foo = wmii.read ("/lbar/1")
print ("read /lbar/1 ::\n" .. foo .. "\n")

print ("ls / ::")
for foo in  wmii.ls ("/") do
        print ("    ", foo)
end
print ("")

print ("ls -l /lbar ::")
for foo in wmii.ls ("/lbar", "-l") do
        print ("    ", foo)
end
print ("")

print ("switch view left...")
wmii.setview(1)
posix.sleep(1)
print ("switch view right...")
wmii.setview(-1)
posix.sleep(1)
print ("")

print ("toggle view...")
wmii.toggleview()
posix.sleep(1)
print ("toggle view...")
wmii.toggleview()
print ("")

--[[
print ("read some events...\n")
for x in wmii.iread("/event") do
        print ("ev: " .. x .. "\n")
end
for x,y in wmii.ievents() do
        print ("ev: " .. x .. " - " .. y)
end
]]--

