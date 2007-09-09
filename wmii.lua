--
-- Copyrigh (c) 2007, Bart Trojanowski <bart@jukie.net>
--
-- Simple wmiir like interface.
--
-- The current intent is to wrap around the wmiir executable.
-- This is just a proof of concept, and eventually this will 
-- be rewritten in C to use libixp.
-- 
-- git://www.jukie.net/wmiirc-lua.git/

package.cpath = package.cpath .. ";" .. os.getenv("HOME") .. "/.wmii-3.5/ixp/?.so"
require "ixp"
local ixp = ixp

local base = _G
local io = require("io")
local os = require("os")
local posix = require("posix")
local string = require("string")
local table = require("table")
local math = require("math")
local type = type
local error = error
local print = print
local pairs = pairs
local tostring = tostring

module("wmii")

-- ------------------------------------------------------------------------
-- module variables

-- wmiir points to the wmiir executable
local wmiir = "wmiir"

-- wmii_adr is the address we use when connecting using ixp
local wmii_adr = os.getenv("WMII_ADDRESS")
        or ("unix!/tmp/ns." ..  os.getenv("USER") ..  "." 
            .. os.getenv("DISPLAY"):match("(:%d+)") .. "/wmii")

-- wmixp is the ixp context we use to talk to wmii
local wmixp = ixp.new(wmii_adr)

-- history of previous views, view_hist[#view_hist] is the last one
view_hist = {}                  -- sorted with 1 being the oldest
view_hist_max = 10              -- max number to keep track of


-- ------------------------------------------------------------------------
-- returns an iterator
function ls (dir, fmt)
        local verbose = fmt and fmt:match("l")

        local s = wmixp:stat(dir)
        if not s then
                return function () return nil end
        end
        if s.modestr:match("^[^d]") then
                return function ()
                        return stat2str(verbose, s)
                end
        end

        local itr = wmixp:idir (dir)
        if not itr then
                --return function ()
                        return nil
                --end
        end


        return function ()
                local s = itr()
                if s then
                        return stat2str(verbose, s)
                end
                return nil
        end
end

function stat2str(verbose, stat)
        if verbose then
                return string.format("%s %s %s %5d %s %s", stat.modestr, stat.uid, stat.gid, stat.length, stat.timestr, stat.name)
        else
                if stat.modestr:match("^d") then
                        return stat.name .. "/"
                else
                        return stat.name
                end
        end
end

-- ------------------------------------------------------------------------
-- read all contents of a wmii virtual file
function read (file)
        return wmixp:read (file)
end

-- ------------------------------------------------------------------------
-- return an iterator which walks all the lines in the file
--
-- example:
--     for event in wmii.iread("/event")
--         ...
--     end
function iread (file)
        return wmixp:iread(file)
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
-- create a wmii file, optionally write data to it
function create (file, data)
        wmixp:create(file, data)
end

-- ------------------------------------------------------------------------
-- remove a wmii file
function remove (file)
        wmixp:remove(file)
end

-- ------------------------------------------------------------------------
-- write a value to a wmii virtual file system
function write (file, value)
        wmixp:write (file, value)
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
-- displays the menu given an table of entires, returns selected text
function menu (tbl)

        local infile = os.tmpname()
        local fh = io.open (infile, "w+")

        for n in pairs(tbl) do
                fh:write (n)
                fh:write ("\n")
        end
        fh:close()

        local outfile = os.tmpname()

        os.execute ("dmenu < " .. infile .. " > " .. outfile)

        fh = io.open (outfile, "r")
        os.remove (outfile)

        local sel = fh:read("*l")
        fh:close()

        return sel
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

-- ------------------------------------------------------------------------
-- displays the a program menu, returns selected program
function gettags()
        local t = {}
        local s
        for s in wmixp:idir ("/tag") do
                if s.name and not (s.name == "sel") then
                        t[#t + 1] = s.name
                end
        end
        table.sort(t)
        return t
end

-- ------------------------------------------------------------------------
-- displays the a program menu, returns selected program
function getview()
        local v = wmixp:read("/ctl") or ""
        return v:match("view%s+(%S+)")
end

-- ------------------------------------------------------------------------
-- changes the current view
--   if the argument is a number it shifts the view left or right by that count
--   if the argument is a string it moves to that view name
function setview(sel)
        local cur = getview()
        local all = gettags()

        if #all < 2 then
                -- nothing to do if we have less then 2 tags
                return

        elseif type(sel) == "number" then
                -- range check
                if (sel < - #all) or (sel > #all) then
                        error ("view selector is out of range")
                end

                -- find the one that's selected index
                local curi = nil
                local i,v
                for i,v in pairs (all) do
                        if v == cur then curi = i end
                end

                -- adjust by index
                local newi = math.fmod(#all + curi + sel - 1, #all) + 1
                if (newi < - #all) or (newi > #all) then
                        error ("error computng new view")
                end

                sel = all[newi]

        elseif not (type(sel) == "string") then
                error ("number or string argument expected")
        end

        -- set new view
        write ("/ctl", "view " .. sel)
end

function toggleview()
        local last = view_hist[#view_hist]
        if last then
                setview(last)
        end
end
