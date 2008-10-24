--[[
=pod

=head1 NAME

mpd.lua - wmiirc-lua plugin for monitoring and controlling mpd (music player daemon)

=head1 SYNOPSIS

    -- in your wmiirc.lua:
    mpd = wmii.load_plugin("mpd")


=head1 DESCRIPTION

For binding the mpd controls to the multimedia keys you could add
the following keyhandlers to your wmiirc.lua:

wmii.add_key_handler('XF86AudioNext', mpd.next_song())

wmii.add_key_handler('XF86AudioPrev', mpd.prev_song())

wmii.add_key_handler('XF86AudioPlay', mpd.toggle_pause())

wmii.add_key_handler('XF86AudioStop', mpd.stop())

=head1 SEE ALSO

L<wmii(1)>, L<lua(1)>

=head1 AUTHOR

Jan-David Quesel <jdq@gmx.net>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008, Jan-David Quesel <jdq@gmx.net>

This is free software.  You may redistribute copies of it under the terms of
the GNU General Public License L<http://www.gnu.org/licenses/gpl.html>.  There
is NO WARRANTY, to the extent permitted by law.

=cut
--]]
local wmii = require("wmii")
local io = require("io")
local string = require("string")

module("mpd")
api_version=0.1

-- ------------------------------------------------------------
-- Configuration Settings
wmii.set_conf ("mpd.server", "127.0.0.1")
wmii.set_conf ("mpd.port", "6600")

-- ------------------------------------------------------------
-- Init Plugin
local widget = wmii.widget:new ("301_mpd_status")

local function _command ( cmd )

	if (cmd) then
		wmii.log( "about to run " .. cmd)
		local file = io.popen( cmd)
		local status = file:read("*a")
		file:close()

		return status:match("[^\n]*")
	else
		return ""
	end
end

local function update_mpd_status (time_since_update)
	local printout = _command("export MPD_HOST=" .. wmii.get_conf("mpd.server") .. "&& export MPD_PORT=" .. wmii.get_conf("mpd.port") .. " && mpc")

	widget:show(printout)
	return 5
end 

function next_song() 
	_command("export MPD_HOST=" .. wmii.get_conf("mpd.server") .. "&& export MPD_PORT=" .. wmii.get_conf("mpd.port") .. " && mpc next")
	update_mpd_status(0)
end

function prev_song()
	_command("export MPD_HOST=" .. wmii.get_conf("mpd.server") .. "&& export MPD_PORT=" .. wmii.get_conf("mpd.port") .. " && mpc prev")
	update_mpd_status(0)
end

function toggle_pause()
	_command("export MPD_HOST=" .. wmii.get_conf("mpd.server") .. "&& export MPD_PORT=" .. wmii.get_conf("mpd.port") .. " && mpc toggle")
	update_mpd_status(0)
end

function stop()
	_command("export MPD_HOST=" .. wmii.get_conf("mpd.server") .. "&& export MPD_PORT=" .. wmii.get_conf("mpd.port") .. " && mpc stop")
	update_mpd_status(0)
end

function register_action()
  wmii.add_action_handler ("mpd",
    function(act,args)           
      local actions = { 'play', 'pause', 'stop', 'next', 'prev' }
      local act = wmii.menu(actions, "mpd: ")                    
      local fn = function_handlers[act]      
      if fn then                       
        local r, err = pcall (fn)
      end                        
    end)
end

local timer = wmii.timer:new (update_mpd_status, 1)

