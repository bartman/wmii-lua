#!/usr/bin/env lua

require "wmii"

wmii.write ("/lbar/1", '#FF0000 #00FF00 #0000FF xxx')

foo = wmii.ls ("/lbar")
io.write ("ls ::\n" .. foo .. "\n")

foo = wmii.ls ("/lbar", "-l")
io.write ("ls -l ::\n" .. foo .. "\n")

foo = wmii.read ("/lbar/1")
io.write ("read /lbar/1 ::\n")

for x in foo do
        io.write (x .. "\n")
end


