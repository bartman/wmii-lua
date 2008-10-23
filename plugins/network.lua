--[[
=pod

=head1 NAME

network.lua - wmiirc-lua plugin for monitoring network interfaces

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
local os = require("os")
local posix = require("posix")
local io = require("io")
local type = type
local error = error
local pairs = pairs
local tostring = tostring

module("network")
api_version = 0.1

-- ------------------------------------------------------------
-- MODULE VARIABLES
local widget = nil
local timer  = nil

widget = wmii.widget:new ("350_network")

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

function update ( new_vol )
    local txt = ""
	local ssid = "iwconfig wlan0 |grep ESSID | awk -F: '{print $2}'"
	local wlan0ip = "ifconfig wlan0 | awk -F: '/inet addr/ {print $2}' | awk '{print $1}'"
	local eth0ip = "ifconfig eth0 | awk -F: '/inet addr/ {print $2}' | awk '{print $1}'"
	local str_ssid = _command(ssid)
	str_ssid = str_ssid.sub(str_ssid, 2, str_ssid.len(str_ssid)-3)
	local str = _command(wlan0ip)
	str = str.sub(str, 1, str.len(str))

	if wlan0ip == "" then
		txt = "wlan0: down eth: "
	else
		txt = "wlan0: " .. str .. "@(" .. str_ssid .. ") eth0: "
	end

	local str_eth0 = _command(eth0ip)
	str_eth0 = str_eth0.sub(str_eth0, 1, str_eth0.len(str_eth0))
	if str_eth0 == "" then
		txt = txt .. "down"
	else
		txt = txt .. str_eth0
	end

	widget:show(txt)
end

local function network_timer ( timer )
	update(0)
    return 60
end

timer = wmii.timer:new (network_timer, 1)
