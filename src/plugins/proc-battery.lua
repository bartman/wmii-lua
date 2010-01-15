--[[
=pod

=head1 NAME

battery.lua - wmiirc-lua plugin for battery percentage

=head1 SYNOPSIS

    -- in your wmiirc
    wmii.load_plugin("battery")

    -- To configure (after loading plugin)

    -- Multiple batteries
    wmii.set_conf("battery.names", "BAT0,BAT1");

    -- Polling rate (in seconds)
    wmii.set_conf("battery.poll_rate", 30)

=head1 DESCRIPTION

This plugin module provides a battery usage display.

=head1 CONFIGURATION AND ENVIRONMENT

There are several configurable options at the moment, most of which will not
need to be modified from the defaults for most users.

=over 4

=item battery.names

A comma-separated list of battery names to poll for status.  This allows the
widget to display multiple battery names.

Defaults to "BAT0"

=item battery.poll_rate

Time in seconds to wait between checks for battery status.

Defaults to 30

=item battery.low

Provide a "low battery" warning at this percentage of remaining capacity.
Colour of widget will change to the defined value, and the low_action, if any,
will be invoked.

Defaults to 15

=item battery.low_fgcolor

Foreground colour of widget when in low battery state.

Defaults to #000000

=item battery.low_bgcolor

Background colour of widget when in low battery state.

Defaults to #FFFF66

=item battery.low_action

Shell command to invoke on entering low battery state.

Defaults to

    echo "Low battery" | xmessage -center -buttons quit:0 -default quit -file -

=item battery.critical

Provide a "critical battery" warning at this percentage of remaining capacity.
Colour of widget will change to the defined value, and the critical_action, if any,
will be invoked.

Defaults to 5

=item battery.critical_fgcolor

Foreground colour of widget when in critical battery state.

Defaults to #000000

=item battery.critical_bgcolor

Background colour of widget when in critical battery state.

Defaults to #FF0000

=item battery.critical_action

Shell command to invoke on entering critical battery state.

Defaults to

    echo "Critical battery" | xmessage -center -buttons quit:0 -default quit -file -

=back

=head1 BUGS AND LIMITATIONS

Please report problems to the author.
Patches are welcome.

=over 4

=item *

You can't have different low/critical warning thresholds or colours per
battery.  If you actually want this, please send a patch.

=back

=head1 SEE ALSO

L<wmii(1)>, L<lua(1)>

=head1 AUTHOR

Dave O'Neill <dmo@dmo.ca>

Based on a port by Stefan Riegler <sr@bigfatflat.net> of the ruby-wmiirc
standard-plugin.rb battery handling originally written Mauricio Fernandez.

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Stefan Riegler <sr@bigfatflat.net>
Copyright (c) 2008, Dave O'Neill <dmo@dmo.ca>

This is free software.  You may redistribute copies of it under the terms of
the GNU General Public License L<http://www.gnu.org/licenses/gpl.html>.  There
is NO WARRANTY, to the extent permitted by law.

=cut

--]]

local wmii   = require("wmii")
local io     = require("io")
local os     = require("os")
local string = require("string")

module("battery")
api_version=0.1

--
-- Configuration Settings
--
wmii.set_conf ("battery.poll_rate", 30)

wmii.set_conf ("battery.names", "BAT0")

wmii.set_conf ("battery.low", 15)
wmii.set_conf ("battery.low_fgcolor", "#000000")
wmii.set_conf ("battery.low_bgcolor", "#FFFF66")
wmii.set_conf ("battery.low_action",  'echo "Low battery" | xmessage -center -buttons quit:0 -default quit -file -')

wmii.set_conf ("battery.critical", 5)
wmii.set_conf ("battery.critical_fgcolor", "#000000")
wmii.set_conf ("battery.critical_bgcolor", "#FF0000")
wmii.set_conf ("battery.critical_action",  'echo "Critical battery" | xmessage -center -buttons quit:0 -default quit -file -')

-- Should not need to be modified on Linux
wmii.set_conf ("battery.statefile", "/proc/acpi/battery/%s/state")
wmii.set_conf ("battery.infofile",  "/proc/acpi/battery/%s/info")

wmii.set_conf ("battery.showtime", true)
wmii.set_conf ("battery.showrate", true)

--
-- Local Variables
--
local batteries       = { }

-- The actual work performed here.
-- parses info, state file and preps for display
local function update_single_battery ( battery )

	local printout = "N/A"
	local colors   = wmii.get_ctl("normcolors")

	local fbatt    = io.open(string.format(wmii.get_conf("battery.statefile"), battery["name"] ),"r")
	if fbatt == nil then
		return battery["widget"]:show(printout, colors)
	end

	local batt = fbatt:read("*a")
        fbatt:close()

	local battpresent = batt:match('present:%s+(%w+)')
	if battpresent ~= "yes" then
		return battery["widget"]:show(printout, colors)
	end

	local low          = wmii.get_conf ("battery.low")
	local critical     = wmii.get_conf ("battery.critical")

	local fbattinfo    = io.open(string.format(wmii.get_conf("battery.infofile"), battery["name"]),"r")
	local battinfo     = fbattinfo:read("*a")
        fbattinfo:close()

	local batt_percent = batt:match('remaining capacity:%s+(%d+)')
	                     / battinfo:match('last full capacity:%s+(%d+)') * 100
	local batt_state   = batt:match('charging state:%s+(%w+)')

	-- Take action in case battery is low/critical
	if batt_percent <= critical then
		if batt_state == "discharging" and not battery["warned_crit"] then
			wmii.log("Warning about critical battery.")
			os.execute(wmii.get_conf("battmon.critical_action"), "&")
			battery["warned_crit"] = true
		end
		colors = string.gsub(colors, "^%S+ %S+",
			wmii.get_conf ("battery.critical_fgcolor")
			.. " "
			..  wmii.get_conf ("battery.critical_bgcolor"),
			1)
	elseif batt_percent <= low then
		if batt_state == "discharging" and not battery["warned_low"] then
			wmii.log("Warning about low battery.")
			os.execute(wmii.get_conf("battmon.low_action"), "&")
			battery["warned_low"] = true
		end
		colors = string.gsub(colors, "^%S+ %S+",
			wmii.get_conf ("battery.low_fgcolor")
			.. " "
			..  wmii.get_conf ("battery.low_bgcolor"),
			1)
	else
		battery["warned_low"] = true
		battery["warned_crit"] = true
	end


	-- If percent is 100 and state is discharging then
	-- the battery is full and not discharging.
	if (batt_state == "charged") or (batt_state == "discharging" and batt_percent >= 97)  then
		batt_state = "="
	end
	if batt_state == "charging" then
		batt_state = "^"
	end
	if batt_state == "discharging" then
		batt_state = "v"
	end

	local batt_rate = batt:match('present rate:%s+(%d+)') * 1

	local batt_time = ""
	if wmii.get_conf(battery.showtime) then
		batt_time = "inf"
		if batt_rate > 0 then
			if batt_state == "^" then
				batt_time = (battinfo:match('last full capacity:%s+(%d+)') - batt:match('remaining capacity:%s+(%d+)')) / batt_rate
			else
				batt_time = batt:match('remaining capacity:%s+(%d+)') / batt_rate
			end
			local hour = string.format("%d",batt_time)
			local min = (batt_time - hour) * 60

			if min > 59 then
				min = min - 60
				hour = hour + 1
			end
			if min < 0 then
				min = 0
			end
			batt_time = hour .. ':'
			batt_time = batt_time .. string.format("%.2d",min)
		end
	end

	local battrate_string = ""
	if wmii.get_conf(battery.showrate) then
		batt_rate = batt_rate/1000
		battrate_string = string.format("%.2f",batt_rate) .. 'W '
	end
	printout =  battrate_string .. batt_time .. '(' .. batt_state .. string.format("%.0f",batt_percent) .. batt_state .. ')'

	battery["widget"]:show(printout, colors)
end

-- ------------------------------------------------------------
-- The battery status update function (wmii.timer function)
local function update_batt_data (time_since_update)

	local batt_names = wmii.get_conf("battery.names");

	for battery in batt_names:gmatch("%w+") do
		if( not batteries[battery] ) then
			batteries[battery] = {
				name        = battery,
				widget      = wmii.widget:new ("901_battery_" .. battery),
				warned_low  = false,
				warned_crit = false,
			}
		end
		update_single_battery( batteries[battery] )
	end

	return wmii.get_conf("battery.poll_rate")
end


local timer = wmii.timer:new (update_batt_data, 1)

