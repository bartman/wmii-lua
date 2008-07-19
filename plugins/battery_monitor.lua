--
-- Copyright (c) 2007, Stefan Riegler <sr@bigfatflat.net>
--
-- Battery Monitor Plugin, based on the implementation for ruby-wmiirc,
-- standard-plugin.rb by Mauricio Fernandez <mfp@acm.org> 
-- http://eigenclass.org/hiki.rb?wmii+ruby
--
-- Licensed under the terms and conditions of the GPL
--

local wmii = require("wmii")
local io = require("io")
local os = require("os")
local string = require("string")
local tonumber = tonumber

module("battery_monitor")
api_version=0.1

-- ------------------------------------------------------------
-- Configuration Settings
wmii.set_conf ("batmon.statefile", "/proc/acpi/battery/BAT0/state")
wmii.set_conf ("batmon.infofile", "/proc/acpi/battery/BAT0/info")

wmii.set_conf ("batmon.low", 8)
wmii.set_conf ("batmon.low_action", 'echo "Low battery" | xmessage -center -buttons quit:0 -default quit -file -')

wmii.set_conf ("batmon.critical", 2)
wmii.set_conf ("batmon.critical_action", 'echo "Critical battery" | xmessage -center -buttons quit:0 -default quit -file -')

wmii.set_conf ("batmon.warned_low", "false")
wmii.set_conf ("batmon.warned_critical", "false")

-- ------------------------------------------------------------
-- Local Variables
local warned_low = false
local warned_critical = false

local low = wmii.get_conf ("batmon.low")
local critical = wmii.get_conf ("batmon.critical")

local batt = nil
local battinfo = nil
local battpresent = nil

local printout, text = nil

-- ------------------------------------------------------------
-- Init Plugin
local widget = wmii.widget:new ("901_battery_monitor")


-- ------------------------------------------------------------
-- The battery status update function (wmii.timer function)
-- parses info, state file and preps for display
--
local function update_batt_data (time_since_update)

	local fbatt = io.open(wmii.get_conf("batmon.statefile"),"r")
	local fbattinfo = io.open(wmii.get_conf("batmon.infofile"),"r")

	if fbatt ~= nil then
		batt = fbatt:read("*a")
		battinfo = fbattinfo:read("*a")

		battpresent = batt:match('present:%s+(%w+)')

		if battpresent == "yes" then
			batt_percent =	batt:match('remaining capacity:%s+(%d+)') / 
					battinfo:match('last full capacity:%s+(%d+)') * 100
			batt_state = batt:match('charging state:%s+(%w+)')

			-- 
			-- Take action in case battery is low/critical
			--
			if batt_state == "discharging" and batt_percent <= critical then
				if not warned_critical then
					wmii.log("Warning about critical battery.")
					os.execute(wmii.get_conf("battmon.critical_action"), "&")
					warned_critical = true
				end
			elseif batt_state == "discharging" and batt_percent <= low then
				if not warned_low then
					wmii.log("Warning about low battery.")
					os.execute(wmii.get_conf("battmon.low_action"), "&")
					warned_low = true
				end
			else
				warned_low = false
				warned_critical = false
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

			printout = batt_state .. string.format("%.0f",batt_percent) .. batt_state
		else
			printout = "N/A"
		end
	end

	widget:show(printout)
	return 5
end 
-- function update_batt_data
-- ----------------------------------------------

local timer = wmii.timer:new (update_batt_data, 1)

