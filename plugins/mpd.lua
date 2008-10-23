--[[
=pod

=head1 NAME

mpd.lua - wmiirc-lua plugin for monitoring and controlling mpd (music player daemon)

=head1 SYNOPSIS

    -- in your wmiirc.lua:
    wmii.load_plugin("cpu")


=head1 DESCRIPTION

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
local os = require("os")
local string = require("string")
local tonumber = tonumber

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

local timer = wmii.timer:new (update_mpd_status, 1)

