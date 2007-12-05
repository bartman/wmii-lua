
local os = require("os")
local io = require("io")
local string = require("string")
--       local posix = require("posix")
--       local table = require("table")
--       local math = require("math")
--       local type = type
--       local error = error
local print = print
--       local pcall = pcall
--       local pairs = pairs
--       local package = package
--       local require = require
local tostring = tostring
--       local tonumber = tonumber
local setmetatable = setmetatable

module("history")


history = {}
function new (size)
        local o = {}

        setmetatable (o,history)
        history.__index = history

        o.data = {}
        o.data[size] = nil
        o.size = size
        o.count = 0
        o.last = 0

        return o
end

function history:add (entry)
        if self.count < self.size then
                self.count = self.count + 1
                self.last = self.count
                self.data[self.last] = entry
        else
                self.last = 1 + (self.last % self.size)
                self.data[self.last] = entry
        end
end

function history:oldest ()
        if self.count then
                local i = 1 + ((self.last + self.size - self.count) % self.size)
                return self.data[i]
        end
        return nil
end

function history:newest ()
        if self.count then
                return self.data[self.last]
        end
        return nil
end

function history:walk_reverse ()
        local s = self
        local count = s.count
        local index = s.last

        return function ()
                local ret = nil
                if count > 0 then
                        local i = 1 + (s.size + index - 1) % s.size
                        ret = s.data[i]
                        count = count - 1
                        index = index - 1
                end
                return ret
        end
end


