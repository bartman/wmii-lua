--
-- Copyright (c) 2008, Bart Trojanowski <bart@jukie.net>
--
-- This plugin binds Mod1-' to create a terminal with the same working
-- directory as the last directory entered on the shell[*] in that view.
--
-- [*] you will have to modify your zshrc or bashrc to generate the
--     "ShellChangeDir" wmii event.
--
-- zshrc:
--      chpwd_functions+='zsh_wmii_chpwd'
--      function zsh_wmii_chpwd () { echo "ShellChangeDir $PWD" | wmiir write /event ; }
--
-- bashrc:
--      function cd () { builtin cd $@ && \
--                       ( echo "ShellChangeDir $PWD" | wmiir write /event ) ; }
--
local wmii = require("wmii")
local os = require("os")
local io = require("io")
local math = require("math")
local type = type
local error = error
local tostring = tostring

module("view_workdir")
api_version = 0.1

local view_workdirs = {}

wmii.add_event_handler("ShellChangeDir", 
        function(ev,arg)
                wmii.log("view_workdir: arg is " .. type(arg))
                if type(arg) == 'string' then
                        local view = wmii.get_view()
                        wmii.log("view_workdir: view is " .. type(view))
                        if type(view) == 'string' then
                                wmii.log("view_workdir: view_workdirs["..view.."] = "..arg)
                                view_workdirs[view] = arg
                        end
                end
        end)

wmii.add_key_handler("Mod1-apostrophe",
        function (key)
                local xterm = wmii.get_conf("xterm") or "xterm"
                local cd_cmd = ''

                local view = wmii.get_view()
                wmii.log("view_workdir: view is " .. type(view))
                if type(view) == 'string' then
                        local dir = view_workdirs[view]
                        if type(dir) == 'string' then
                                cd_cmd = "cd '"..dir.."' ; "
                        end
                end

                wmii.log ("    executing: " .. cd_cmd .. xterm)
                os.execute (cd_cmd .. xterm .. " &")
        end)

