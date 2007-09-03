#!/usr/bin/env lua

require "ixp"

print ("testing...")
ixp.test ()

print ("writing...")
ixp.write ("/lbar/1", '#FF0000 #00FF00 #0000FF 1xxx')

print ("reading...")
data = ixp.read ("/lbar/1")
print (data)

print ("iterating...")
for ev in ixp.iread("/event") do
        print (ev)
end
