--[[
=pod

=head1 NAME

cpugraph.lua - wmiirc-lua plugin for monitoring cpu frequency

=head1 SYNOPSIS

    -- in your wmiirc.lua:
    wmii.load_plugin("cpugraph")


=head1 DESCRIPTION

=head1 SEE ALSO

L<wmii(1)>, L<lua(1)>

=head1 AUTHOR

Jan-David Quesel <jdq@gmx.net>
Jean Richard <jean@geemoo.ca>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008, Jan-David Quesel <jdq@gmx.net>
Copyright (c) 2010, Jean Richard <jean@geemoo.ca>

This is free software.  You may redistribute copies of it under the terms of
the GNU General Public License L<http://www.gnu.org/licenses/gpl.html>.  There
is NO WARRANTY, to the extent permitted by law.

=cut
--]]

local wmii = require("wmii")
local os = require("os")
local posix = require("posix")
local io = require("io")
local string = require("string")
local type = type
local error = error
local pairs = pairs
local tostring = tostring

module("cpugraph")
api_version = 0.1

-- ------------------------------------------------------------
-- MODULE VARIABLES
local widget = nil
local timer  = nil

widget = wmii.widget:new ("400_cpugraph")

-- used to remember the cpu speeds from past intervals
history = { }

-- ------------------------------------------------------------
-- looks into /sys/devices/system/cpu and gets a list of all 
-- 	cpus in the system.. returns it as a list
local function cpu_list()
	local dir = "/sys/devices/system/cpu/"
	local _,cpu
	local list = {}
	for _,cpu in pairs(posix.glob(dir .. 'cpu[0-9]*')) do
		local stat
		if cpu then
			stat = posix.stat(cpu)
			if stat and stat.type == 'directory' then
				list[#list+1] = cpu
			end
		end
	end
	return list
end

-- ------------------------------------------------------------------
-- read a file, return the first line
local function read_sys_line(file, fmt)
	local ret = nil
	local fd = io.open(file)
	if fd then
		ret = fd:read(fmt or "*l")
	end
	return ret
end


-- ------------------------------------------------------------------
-- read a file and return the first line as a number
local function read_sys_number(file)
	local ret = read_sys_line(file, "*n")
	if type(ret) ~= type(1) then
		ret = 0
	end
	return ret
end


-- ------------------------------------------------------------------
-- create a string describing the cpu speed for the last 10 intervals
local function create_string(cpu)

	-- read all the info we need and define other vars
	local curfreq = read_sys_number(cpu .. '/cpufreq/scaling_cur_freq')
	local minfreq = read_sys_number(cpu .. '/cpufreq/scaling_min_freq')
	local maxfreq = read_sys_number(cpu .. '/cpufreq/scaling_max_freq')
	local freqsym = " "
	local cpuname = string.gsub(cpu, ".*/", "")

	-- figure out how big each frequency division is
	local increment = (maxfreq - minfreq) / 3

	-- figure out what symbol to use.. we split the bar into 3
	if (curfreq <= minfreq + increment) then
		freqsym = "."
	elseif (curfreq <= (minfreq + 2*increment)) then
		freqsym = "o"
	else 
		freqsym = "O"
	end

	-- now shift over the history if needed and glue on this char
	history[cpuname] = string.sub(history[cpuname], 2, -1)
	history[cpuname] = history[cpuname] .. freqsym

	-- now that we are done, return it
	return history[cpuname]
end


-- ------------------------------------------------------------------
-- update our plugin's display widgets
function update ()
	local txt = ""
	local _, cpu
	local list = cpu_list()
	local space = ""
	for _,cpu in pairs(list) do
		txt = txt .. space .. create_string(cpu)
		space = "   "
	end

	widget:show(txt)
end


-- ------------------------------------------------------------------
-- schedule updates of our plugin
local function cpugraph_timer ( timer )
	update()
	return 3
end


-- ------------------------------------------------------------------
-- initialize our cpu speed history var for each cpu in system
local function init_history ()
	local txt = ""
	local _, cpu
	local list = cpu_list()
	local space = ""
	for _,cpu in pairs(list) do
		local cpuname = string.gsub(cpu, ".*/", "")
		history[cpuname] = string.rep("_", 10)
	end
end

-- ------------------------------------------------------------------

-- initialize the values in our history var for all the cpus we have
init_history()

-- now setup our timer to call the update function
timer = wmii.timer:new (cpugraph_timer, 2)
