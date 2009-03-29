--
-- Copyright (c) 2007, Bart Trojanowski <bart@jukie.net>
--
-- Browser integration for wmii.
--
-- This plugin depends on xclip utility.
--

local wmii = require("wmii")
local os = require("os")
local string = require("string")
local tostring = tostring
local type = type

module ("browser")
api_version=0.1

-- configuration defaults

wmii.set_conf ("browser", "firefox")

-- new handlers

wmii.add_action_handler ("browser", function (act, args)
        local url = ""
        if type(args) == "string" then
                -- create an quoted string, with quotes in the argument escaped
                url = args:gsub("^%s*",""):gsub("%s*$","")
                url = "'" .. url:gsub("'", "\\'") .. "'"
        else
                -- TODO: need to escape this
                url = '"`xclip -o`"'
        end
        local browser = wmii.get_conf ("browser") or "x-www-browser"
        local cmd = browser .. " " .. url .. " &"
        wmii.log ("    executing: " .. cmd)
        os.execute (cmd)
end)

wmii.add_action_handler ("google", function (act, args)
        local search = ""
        if type(args) == "string" then
                -- create an quoted string, with quotes in the argument escaped
                search = args:gsub("^%s*",""):gsub("%s*$","")
                search = search:gsub("'", "\\'")
        else
                -- TODO: need to escape this
                search = '`xclip -o`'
        end
        local browser = wmii.get_conf ("browser") or "x-www-browser"
        local cmd = browser .. " \"http://google.com/search?q=" .. search .. "\" &"
        wmii.log ("    executing: " .. cmd)
        os.execute (cmd)
end)
