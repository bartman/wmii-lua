--[[
=pod

=head1 NAME

cpu.lua - wmiirc-lua plugin for monitoring acpi stuff

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
local io = require("io")
local type = type
local error = error

module("cpu")
api_version = 0.1

-- ------------------------------------------------------------
-- MODULE VARIABLES
local widget = nil
local timer  = nil

widget = wmii.widget:new ("400_cpu")

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

local function create_string ( )
	wmii.log( "create string")
	local cmd = "cpufreq-info |grep 'current CPU fre'|uniq | awk '{print $5 $6}'"
	local cmd2 = "cpufreq-info | grep \'The gove\'|awk '{print $3}' | uniq"
	local cmd3 = "echo `awk '/remaining/ {print $3}' /proc/acpi/battery/BAT0/state`\*100/`awk '/last/ {print $4}' /proc/acpi/battery/BAT0/info` | bc"
	local str2 = _command(cmd2)
	str2 = str2.sub(str2, 2, str2.len(str2)-1)
	local str = _command(cmd)
	str = str.sub(str, 1, str.len(str)-1)
	return str .. "(" .. str2 .. ") BAT0: " .. _command(cmd3) .. "%"
end

function update ( new_vol )
	local str = create_string()

	widget:show(str)
end

local function cpu_timer ( timer )

	wmii.log("cpu_timer()")
	update(0)
    return 10
end

timer = wmii.timer:new (cpu_timer, 1)
