--[[
=pod

=head1 NAME

volume.lua - wmiirc-lua plugin for volume control

=head1 SYNOPSIS

    -- in your wmiirc.lua:
    wmii.load_plugin("volume")

    -- If you also want keybindings for volume control, you might want to add:
    wmii.add_key_handler('Mod1-minus', function (key)
    	volume.update_volume(-1)
    end
    wmii.add_key_handler('Mod1-plus', function (key)
    	volume.update_volume(1)
    end


=head1 DESCRIPTION

This plugin module provides a volume control widget that uses I<amixer> to view and control volume.

The following controls are available:

=over 4

=item left mouse click

Spawns a mixer  (TODO: not implemented yet)

=item right mouse click

Mutes master volume

=item scroll wheel up/down

Adjusts volume up/down

=back

=head1 CONFIGURATION AND ENVIRONMENT

There are two configurable options at the moment, modifiable via wmii.set_conf():

=over 4

=item volume.update

Interval in seconds for polling the mixer, to determine current volume level.
Without this, your volume display can get out of sync with reality if other
apps adjust the mixer volume.

Default value is 10.

=item volume.mixer

The name of the mixer setting to adjust.  Default is 'Master', which should
work fine for most, but if you have a more complex audio setup, you may wish to
change this.

=back

=head1 MIXER API

One public method is provided.  It can be used in your own plugins, in
keybindings, etc.

=over 4

=item update_volume ( val )

Updates the volume, and changes the plugin display.

If 'val' is numeric and positive, volume is increased by that many steps
(volume controls currently work against "exact hardware value" as described in
the L<amixer(1)> manual.  The scale varies from hardware to hardware -- pinal
Tap's goes to 11.  Mine goes to 2^5 - 1.).

If 'val' is negative, volume is decremented that many steps.

If 'val' is set to the string 'mute', volume is muted.  If set to 'unmute',
volume is unmuted.

=back

=head1 BUGS AND LIMITATIONS

Please report problems to the author.
Patches are welcome.

Current known issues and TODO items:

=over 4

=item left-click does not spawn a mixer app

=item validity and bounds-checking on update_volume()

=item rather than using hardware values, increment/decrement with percentages?

=back

=head1 SEE ALSO

L<wmii(1)>, L<lua(1)>

=head1 AUTHOR

Dave O'Neill <dmo@dmo.ca>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Dave O'Neill <dmo@dmo.ca>

This is free software.  You may redistribute copies of it under the terms of
the GNU General Public License L<http://www.gnu.org/licenses/gpl.html>.  There
is NO WARRANTY, to the extent permitted by law.

=cut
--]]

local wmii = require("wmii")
local os = require("os")
local io = require("io")
local math = require("math")
local type = type
local error = error

module("volume")
api_version = 0.1

-- ------------------------------------------------------------
-- VOLUME CONFIGURATION VARIABLES
--
-- these can be overridden by wmiirc

wmii.set_conf ("volume.update", 10);
wmii.set_conf ("volume.mixer", "Master");

-- ------------------------------------------------------------
-- MODULE VARIABLES
local widget = nil
local timer  = nil

widget = wmii.widget:new ("999_volume")

local function _amixer_command ( cmd )

	wmii.log( "about to run " .. cmd)
	local file = io.popen( cmd )
	local status = file:read("*a")
	file:close()

	local volume
	-- omfg.  lua regexes are uuuugly
	volume = status:match("%[(%d+%%)%]");
	if status:match("%[off%]") then
		volume = "OFF"
	end

	return volume
end

local function mixer_set_volume (value)
	wmii.log( "mixer_set_volume(" .. value .. ")")
	local mixer = wmii.get_conf("volume.mixer")
	return _amixer_command("amixer set \"" .. mixer .. ",0\" " .. value)
end

local function mixer_get_volume ( )
	wmii.log( "mixer_get_volume")
	local mixer = wmii.get_conf("volume.mixer")
	return _amixer_command("amixer get \"" .. mixer .. ",0\"")
end

function update_volume ( new_vol )

	wmii.log("update_volume(" .. new_vol .. ")")
	local value

	if type( new_vol ) == "number" then
		local sign

		if new_vol < 0 then
			sign = "-"
		else
			sign = "+"
		end
		value = math.abs( new_vol ) .. sign
	else
		value = new_vol
	end


	local volume = mixer_set_volume( value )

	widget:show("VOL [" .. volume .. "]")
end

local function button_handler (ev, button)

	wmii.log("button_handler(" .. ev .. "," .. button .. ")")
	if button == 1 then
		-- left click
	elseif button == 2 then
		-- middle click
	elseif button == 3 then
		-- right click
		local action
		local cur_volume = mixer_get_volume()
		if cur_volume == "OFF" then
			action = "unmute"
		else
			action = "mute"
		end
		update_volume( action )
	elseif button == 4 then
		-- scroll up
		update_volume( 1 )
	elseif button == 5 then
		-- scroll down
		update_volume( -1 )
	end
end

widget:add_event_handler("RightBarClick", button_handler)


local function volume_timer ( timer )

	wmii.log("volume_timer()")
	update_volume(0)

        -- returning a positive number of seconds before next wakeup, or
        -- nil (or no return at all) repeats the last schedule, or
        -- -1 to stop the timer
        return 10
end

timer = wmii.timer:new (volume_timer, 1)
