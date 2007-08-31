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

module("wmii")

-- TODO I would like to be able to return an interator
function ls (dir, fmt)
        local tmpfile = os.tmpname()
        local fmt = fmt or ""

        os.execute ("wmiir ls " .. fmt .. " " .. dir .. " > " .. tmpfile)

        local fh = io.open (tmpfile, "rb")
        os.remove (tmpfile)

        local data = fh:read("*a")      -- read everything

        io.close (fh)

        return data
end

-- TODO I would like to return a line iterator
function read (file)
        local tmpfile = os.tmpname()

        os.execute ("wmiir read " .. file .. " > " .. tmpfile)

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

-- write a value to a wmii virtual file system
function write (file, value)
        os.execute ("echo -n '" .. value .. "' | wmiir write " .. file)
end

