#!/usr/bin/env lua

require "eventloop"

el = eventloop.new()

io.stderr:write("---- adding dsat\n")
el:add_exec ("dstat --load --nocolor --noheaders --noupdate",
                function (line)
                        print ("    ** callback: " .. line)
                end)

io.stderr:write("---- running loop\n")
el:run_loop(10)

io.stderr:write("---- finished\n")
