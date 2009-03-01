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
local posix = require("posix")
local io = require("io")
local type = type
local error = error
local pairs = pairs
local tostring = tostring

module("cpu")
api_version = 0.1

-- ------------------------------------------------------------
-- MODULE VARIABLES
local widget = nil
local timer  = nil

widget = wmii.widget:new ("400_cpu")

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


function read_file(path)
      local fd = io.open(path, "r")
      if fd == nil then
              return nil
      end

      local text = fd:read("*a")
       fd:close()

       if type(text) == 'string' then
               text = text:match('(%w+)')
       end

      return text
end


local function create_string(cpu)
       local govfile = cpu .. '/cpufreq/scaling_governor'
       local gov = read_file(govfile) or ""

       local frqfile = cpu .. '/cpufreq/scaling_cur_freq'
       local frq = read_file(frqfile) or ""

       if type(frq) == 'string' then
               local mhz = frq:match('(.*)000')
               if mhz then
                       frq = mhz .. " MHz"
               else
                       frq = frq .. "kHz"
               end
       else
               frq = ""
       end

      return frq .. "(" .. gov .. ")" 
end


function update ( new_vol )
       local txt = ""
       local _, cpu
       local list = cpu_list()
	   local space = ""
       for _,cpu in pairs(list) do
		   local str = create_string(cpu)
		   if txt == str then
			   txt = "2x " .. txt
		   else
               txt = txt .. create_string(cpu) .. space
		   end
		   space = " "
       end

	widget:show(txt)
end

local function cpu_timer ( timer )
	update(0)
    return 10
end

timer = wmii.timer:new (cpu_timer, 1)
