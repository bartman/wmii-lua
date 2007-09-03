#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

#include <ixp.h>

#define MYNAME		"ixp"
#define MYVERSION	MYNAME " library for " LUA_VERSION " / Nov 2003"

#include "lua.h"
#include "lauxlib.h"

static IxpClient *client;

static int pusherror(lua_State *L, const char *info)
{
	lua_pushnil(L);
	if (info==NULL)
		lua_pushstring(L, strerror(errno));
	else
		lua_pushfstring(L, "%s: %s", info, strerror(errno));
	lua_pushnumber(L, errno);
	return 3;
}

/* lua: ixptest() */
static int l_test (lua_State *L)
{
	printf ("** ixptest **\n");
	return pusherror (L, "some error occurred");
}

/* lua: write(file, data) */
static int l_write (lua_State *L)
{
	IxpCFid *fid;
	const char *file;
	const char *data;
	size_t data_len;
	int rc;

	file = luaL_checkstring (L, 1);
	data = luaL_checklstring (L, 2, &data_len);

	fid = ixp_open(client, (char*)file, P9_OWRITE);
	if(fid == NULL)
		return pusherror (L, "count not open p9 file");

	rc = ixp_write(fid, (char*)data, data_len);
	if (rc < 0)
		return pusherror (L, "failed to write to p9 file");
	else if (rc != data_len)
		return pusherror (L, "short write");

	ixp_close(fid);
	return 0;
}

static const luaL_reg R[] =
{
	{ "test",		l_test },

	{ "write",		l_write },
	{ NULL,			NULL },
};

LUALIB_API int luaopen_ixp (lua_State *L)
{
	const char *address = "unix!/tmp/ns.bart.:0/wmii";
	client = ixp_mount((char*)address);

	luaL_register (L, MYNAME, R);
	lua_pushliteral (L, "version");
	lua_pushliteral (L, MYVERSION);
	lua_settable (L, -3);
	return 1;
}
