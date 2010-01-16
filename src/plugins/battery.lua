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
widget to display multiple battery names.  If left blank, will display all
batteries.

Defaults to ""

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

=item battery.practically_full_percentage

This is a workaround for faulty batteries.  Set this lower if you want your battery to report being
full at a lower percentage than 100.

Defaults to 99

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
Bart Trojanowski <bart@jukie.net>

Based on a port by Stefan Riegler <sr@bigfatflat.net> of the ruby-wmiirc
standard-plugin.rb battery handling originally written Mauricio Fernandez.

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Stefan Riegler <sr@bigfatflat.net>
Copyright (c) 2008, Dave O'Neill <dmo@dmo.ca>
Copyright (c) 2010, Bart Trojanowski <bart@jukie.net>

This is free software.  You may redistribute copies of it under the terms of
the GNU General Public License L<http://www.gnu.org/licenses/gpl.html>.  There
is NO WARRANTY, to the extent permitted by law.

=cut

--]]

local wmii   = require("wmii")
local io     = require("io")
local os     = require("os")
local string = require("string")
local posix  = require("posix")
local type   = type
local tostring = tostring

module("battery")
api_version=0.1

--
-- Configuration Settings
--
wmii.set_conf ("battery.poll_rate", 30)

wmii.set_conf ("battery.names", "") -- leave empty to use all available batteries

wmii.set_conf ("battery.low", 15)
wmii.set_conf ("battery.low_fgcolor", "#000000")
wmii.set_conf ("battery.low_bgcolor", "#FFFF66")
wmii.set_conf ("battery.low_action",  'echo "Low battery" | xmessage -center -buttons quit:0 -default quit -file -')

wmii.set_conf ("battery.critical", 5)
wmii.set_conf ("battery.critical_fgcolor", "#000000")
wmii.set_conf ("battery.critical_bgcolor", "#FF0000")
wmii.set_conf ("battery.critical_action",  'echo "Critical battery" | xmessage -center -buttons quit:0 -default quit -file -')

wmii.set_conf ("battery.practically_full_percentage", 99)

-- Should not need to be modified on Linux
wmii.set_conf ("battery.sysdir", "/sys/class/power_supply")
-- ... see http://wiki.openmoko.org/wiki/GTA02_sysfs#power_supply_battery_information for more info

wmii.set_conf ("battery.showtime", true)
wmii.set_conf ("battery.showrate", true)

--
-- Local Variables
--
local batteries       = { }

-- read a /sys file, return the first line
local function read_sys_line(file, fmt)
        local ret = nil
        local fd = io.open(file)
        if fd then
                ret = fd:read(fmt or "*l")
        end
        return ret
end
local function read_sys_number(file)
        local ret = read_sys_line(file, "*n")
        if type(ret) ~= type(1) then
                ret = 0
        end
        return ret
end

-- The actual work performed here.
-- parses info, state file and preps for display
local function update_single_battery ( name )

        local battery = batteries[name]
        if not battery then
                batteries[name] = {
                        name        = name,
                        widget      = wmii.widget:new ("901_battery_" .. name),
                        warned_low  = false,
                        warned_crit = false,
                }
                battery = batteries[name]
        end

	local printout = "N/A"
	local colors   = wmii.get_ctl("normcolors")

        local sysdir   = string.format("%s/%s", wmii.get_conf("battery.sysdir"), name)

        local batt_present     = read_sys_number(sysdir .. '/present')      -- 0 or 1
        local batt_energy_now  = read_sys_number(sysdir .. '/energy_now')   -- µWh
        local batt_energy_full = read_sys_number(sysdir .. '/energy_full')  -- µWh
        local batt_current_now = read_sys_number(sysdir .. '/current_now')  -- µAh
        local batt_power_now   = read_sys_number(sysdir .. '/power_now')    -- µW
        local batt_status      = read_sys_line(sysdir .. '/status')         -- Full, Charging, Discharging, Unknown

        -- the /sys reporting interface is not present
	if not batt_present or not batt_energy_now or not batt_energy_full or not batt_status then
		return battery["widget"]:show(printout, colors)
	end

	local batt_percent = batt_energy_now / batt_energy_full * 100
        if batt_percent > 100 then
                batt_percent = 100
        end

	local low              = wmii.get_conf ("battery.low")
	local critical         = wmii.get_conf ("battery.critical")
        local practically_full = wmii.get_conf ("battery.practically_full_percentage")

	-- Take action in case battery is low/critical
	if batt_percent <= critical then
		if batt_status == "Discharging" and not battery["warned_crit"] then
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
		if batt_status == "Discharging" and not battery["warned_low"] then
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
        local batt_state = "?"
        if batt_status == "Unknown" then
		batt_state = "-"
        elseif (batt_status == "Full") or (batt_percent >= practically_full)  then
		batt_state = "="
        elseif batt_status == "Charging" then
		batt_state = "^"
        elseif batt_status == "Discharging" then
		batt_state = "v"
	end

        -- done calculating, compose the output
        printout = ""

	if wmii.get_conf(battery.showrate) and batt_power_now then
                printout = printout .. string.format("%.2fW ", batt_power_now / 1000000)
	end

	if wmii.get_conf(battery.showtime) and batt_current_now and batt_current_now ~= 0 then
                local hours = 0
                if batt_state == "^" then
                        hours = (batt_energy_full - batt_energy_now) / batt_current_now
                else
                        hours = batt_energy_now / batt_current_now
                end
                printout = printout .. string.format("%d:%0.2d ", hours, (hours*60) % 60)
	end

	printout = printout .. '(' .. batt_state .. string.format("%.0f", batt_percent) .. batt_state .. ')'

	battery["widget"]:show(printout, colors)
end

-- ------------------------------------------------------------
-- The battery status update function (wmii.timer function)
local function update_batt_data (time_since_update)

	local batt_names = wmii.get_conf("battery.names");

        if type(batt_names) == type("") and batt_names ~= "" then
                for name in batt_names:gmatch("%w+") do
                        update_single_battery(name)
                end
        else
                local sysdir = wmii.get_conf("battery.sysdir")
                for name in posix.files(sysdir) do
                        local type_file = string.format("%s/%s/type", sysdir, name)
                        local batt_type = read_sys_line(type_file)
                        if batt_type == "Battery" then
                                update_single_battery(name)
                        end
                end
        end

	return wmii.get_conf("battery.poll_rate")
end


local timer = wmii.timer:new (update_batt_data, 1)

