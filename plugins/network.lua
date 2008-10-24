--[[
=pod

=head1 NAME

network.lua - wmiirc-lua plugin for monitoring network interfaces

=head1 SYNOPSIS

    -- in your wmiirc.lua:
    wmii.load_plugin("network")


=head1 DESCRIPTION

For the options you can define something like

wmii.set_conf("network.interfaces", "wlan0,true,eth0,false")

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

wmii.set_conf("network.interfaces", "eth0,false")

local devices = { }
local wireless_devices = { }
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

local function create_device_string(device,wireless)
	local ip = "ifconfig " .. device .. "| awk -F: '/inet addr/ {print $2}' | awk '{print $1}'"
	local ipstr = _command(ip)
	if ipstr == "" then

		txt = device .. ": down"
	else
		ipstr = ipstr.sub(ipstr, 1, ipstr.len(ipstr))
		txt = device .. ": " .. ipstr 
		if wireless then
			local ssid = "iwconfig " .. device .. " |grep ESSID | awk -F: '{print $2}'"
			local str_ssid = _command(ssid)
			str_ssid = str_ssid.sub(str_ssid, 2, str_ssid.len(str_ssid)-3)
			txt = txt .. "@(" .. str_ssid .. ")"
		end
	end
	return txt
end

local function update ()
    local txt = ""

	local space = ""
	for _,device in pairs(wireless_devices) do
		txt = txt .. space .. create_device_string(device,true)
		space = " "
	end
	for _,device in pairs(devices) do
		txt = txt .. space .. create_device_string(device,false)
		space = " "
	end
	widget:show(txt)
end

local function generate_lists() 
	local strings = wmii.get_conf("network.interfaces")

	local string_list = { }

	for str in strings:gmatch("%w+") do
		string_list[#string_list+1] = str
    end

	local i = 1
	while i < #string_list do
		if string_list[i+1] == "true" then
			wireless_devices[#wireless_devices+1] = string_list[i]
		else
			devices[#devices+1] = string_list[i]
		end
		i = i + 2
	end
end

local function network_timer ( timer )
	if #devices == 0 and #wireless_devices == 0 then
		generate_lists()
	end
	update()
    return 60
end


timer = wmii.timer:new (network_timer, 1)
