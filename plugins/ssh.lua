--[[
=pod

=head1 NAME

ssh.lua - SSH menu for known hosts.

=head1 SYNOPSIS

Add something like:

  wmii.load_plugin ("ssh")
  wmii.add_key_handler ("Mod1-z", ssh.show_menu)

into your wmiirc.lua.

=head1 DESCRIPTION

This reads ~/.ssh/known_hosts in order to display a menu of hosts (and IP
addresses) found in the file.  It assumes 'HashKnownHosts no' is set in
~/.ssh/config (otherwise it displays the hashed hosts).

=head1 SEE ALSO

L<wmii(1)>, L<lua(1)>

=head1 AUTHOR

David Leadbeater <dgl@dgl.cx>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008, David Leadbeater <dgl@dgl.cx>

This is free software.  You may redistribute copies of it under the terms of
the GNU General Public License L<http://www.gnu.org/licenses/gpl.html>.  There
is NO WARRANTY, to the extent permitted by law.

=cut
--]]

local wmii = require("wmii")
local os = require("os")
local io = require("io")
local type = type

module ("ssh")
api_version=0.1

local hosts

function load_hosts()
  hosts = {}

  local file = io.open(os.getenv("HOME") .. "/.ssh/known_hosts", "r")
  if file then
    local line = file:read("*line")

    while line do
      local host = line:match("([^ ,]+)")
      hosts[host] = 1
      line = file:read("*line")
    end
    file:close()
  end
end

function show_menu()
  local str = wmii.menu(hosts, "ssh:")
  if type(str) == "string" then
    local cmd = wmii.get_conf("xterm") .. " -e ssh " .. str .. " &"
    os.execute(cmd)
  end
end

load_hosts()
