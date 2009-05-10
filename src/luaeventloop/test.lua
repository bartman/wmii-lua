#!/usr/bin/env lua

require "eventloop"

el = eventloop.new()

io.stderr:write("---- adding dsat --load\n")
el:add_exec ("dstat --load --nocolor --noheaders --noupdate",
                function (line)
                        local line = line:gsub("\n$","")
                        print ("    ** load: " .. line)
                end)

io.stderr:write("---- adding dstat --int\n")
el:add_exec ("dstat --int --nocolor --noheaders --noupdate",
                function (line)
                        local line = line:gsub("\n$","")
                        print ("    ** int: " .. line)
                end)

io.stderr:write("---- running loop\n")
el:run_loop(10)

io.stderr:write("---- finished\n")
