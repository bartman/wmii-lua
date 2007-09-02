--
-- Copyrigh (c) 2007, Bart Trojanowski <bart@jukie.net>
--
-- Simple wmiir like interface.
--
-- The current intent is to wrap around the wmiir executable.
-- This is just a proof of concept, and eventually this will 
-- be rewritten in C to use libixp.
-- 
local base = _G
local io = require("io")
local os = require("os")
local posix = require("posix")
local string = require("string")
local print = print
local pairs = pairs

module("wmii")

local wmiir = "wmiir"

-- ------------------------------------------------------------------------
-- TODO I would like to be able to return an interator
function ls (dir, fmt)
        local tmpfile = os.tmpname()
        local fmt = fmt or ""

        os.execute (wmiir .. " ls " .. fmt .. " " .. dir .. " > " .. tmpfile)

        local fh = io.open (tmpfile, "rb")
        os.remove (tmpfile)

        local data = fh:read("*a")      -- read everything

        io.close (fh)

        return data
end

-- ------------------------------------------------------------------------
-- read all contents of a wmii virtual file
function read (file)
        local tmpfile = os.tmpname()

        os.execute (wmiir .. " read " .. file .. " > " .. tmpfile)

        local fh = io.open (tmpfile, "rb")
        os.remove (tmpfile)

        local data = fh:read("*a")      -- read all
        io.close (fh)

        return data
end

-- ------------------------------------------------------------------------
-- return an iterator which walks all the lines in the file
--
-- example:
--     for event in wmii.iread("/event")
--         ...
--     end
function iread (file)
        local tmpfile = os.tmpname()
        os.remove (tmpfile)

        io.write ("-- tmpname " .. tmpfile .. "\n")

        local rc = posix.mkfifo (tmpfile)
        io.write ("-- mkfifo " .. rc .. "\n")

        rc = posix.fork ()
        if rc < 0 then
                io.write ("-- fork failed " .. rc .. "\n")
                return function ()
                        return nil
                end
        end
        if rc == 0 then -- child
                os.execute (wmiir .. " read " .. file .. " > " .. tmpfile)
                posix.exec ("/usr/bin/env", "cat", "/dev/null")
        end

        -- parent

        local fh = io.open (tmpfile, "rb")
        os.remove (tmpfile)

        return function ()
                local line = fh:read("*l")      -- read a line
                if not line then
                        io.write ("-- closing " .. file .. "\n")
                        io.close (fh)
                end
                return line
        end
end

-- ------------------------------------------------------------------------
-- returns an events iterator
function ievents ()
        local it = iread("/event")

        return function ()
                local line = it()
                return string.match(line, "(%S+)%s(.+)")
        end
end

-- ------------------------------------------------------------------------
-- write a value to a wmii virtual file system
function write (file, value)
        local tmpfile = os.tmpname()

        local fh = io.open (tmpfile, "wb")
        fh:write(value)
        io.close (fh)

        os.execute (wmiir .. " write " .. file .. " < " .. tmpfile)
        os.remove (tmpfile)
end

-- ------------------------------------------------------------------------
-- write a value to a wmii virtual file system
function configure (config)
        local x, y
        for x, y in pairs(config) do
                write ("/ctl", x .. " " .. y)
        end
end

-- ------------------------------------------------------------------------
-- displays the a tag selection menu, returns selected tag
function tagmenu ()
        local tmpfile = os.tmpname()

        os.execute ("wmiir ls /tag | sed 's|/||; /^sel$/d' | dmenu > " .. tmpfile)

        local fh = io.open (tmpfile, "rb")
        os.remove (tmpfile)

        local tag = fh:read("*l")
        io.close (fh)

        return tag
end

-- ------------------------------------------------------------------------
-- displays the a program menu, returns selected program
function progmenu ()
        local tmpfile = os.tmpname()

        os.execute ("dmenu_path | dmenu > " .. tmpfile)

        local fh = io.open (tmpfile, "rb")
        os.remove (tmpfile)

        local prog = fh:read("*l")
        io.close (fh)

        return prog
end


