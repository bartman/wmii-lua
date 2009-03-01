--[[
=pod

=head1 NAME

network.lua - wmiirc-lua plugin for monitoring network interfaces

=head1 SYNOPSIS

    -- in your wmiirc.lua:
    wmii.load_plugin("network")


=head1 DESCRIPTION

For the options you can define something like

wmii.set_conf("network.interfaces.wired", "eth0")
wmii.set_conf("network.interfaces.wireless", "wlan0")

which will show informations about the wireless device wlan0 and
the non-wireless device eth0

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
local pairs = pairs

module("network")
api_version = 0.1

wmii.set_conf("network.interfaces.wired", "eth0")
wmii.set_conf("network.interfaces.wireless", "")

local devices = { }
-- ------------------------------------------------------------
-- MODULE VARIABLES
local timer  = nil

local function _command ( cmd )

	if (cmd) then
		wmii.log( "about to run " .. cmd)
		local file = io.popen( cmd)
		local status = file:read("*a")
		file:close()

		return status
		--return status:match("[^\n]*")
	else
		return ""
	end
end

local function create_device_string(device)
	local ip = "ifconfig " .. device["name"] 
	local ipstr = _command(ip)
	ipstr = ipstr:gmatch("inet addr:([0-9.]+)")()
	if ipstr == nil or ipstr == "" then
		txt = device["name"] .. ": down"
	else
		ipstr = ipstr.sub(ipstr, 1, ipstr.len(ipstr))
		txt = device["name"] .. ": " .. ipstr 
		if device["wireless"] then
			local ssid = "iwconfig " .. device["name"]
			local str_ssid = _command(ssid)
			str_ssid = str_ssid:gmatch("ESSID:\"(.*)\"")()
			txt = txt .. "@(" .. str_ssid .. ")"
		end
	end

	device["widget"]:show(txt)
end


local function generate_lists() 
	wmii.log("generating interface list")
	local strings = wmii.get_conf("network.interfaces.wired")
	for str in strings:gmatch("%w+") do
		devices[#devices+1] = {
								name        = str,
								widget      = wmii.widget:new ("350_network_" .. str),
								wireless = false
							  }
		wmii.log("found " .. str)
	end
	local strings = wmii.get_conf("network.interfaces.wireless")
	for str in strings:gmatch("%w+") do
		devices[#devices+1] = {
								name        = str,
								widget      = wmii.widget:new ("350_network_" .. str),
								wireless = true
							  }
		wmii.log("found " .. str)
	end

end

local function update ()
	for _,device in pairs(devices) do
		create_device_string(device)
	end
end

local function network_timer ( timer )
	if #devices == 0 then
		generate_lists()
	end
	update()
    return 60

end

timer = wmii.timer:new (network_timer, 1)
