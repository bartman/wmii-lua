#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <signal.h>

#include <ixp.h>

#include <lua.h>
#include <lauxlib.h>

#include "lixp_debug.h"
#include "lixp_util.h"
#include "lixp_instance.h"


/* ------------------------------------------------------------------------
 * lua: x = ixp.new("unix!/tmp/ns.bart.:0/wmii") -- create a new ixp object
 */
static int l_new (lua_State *L)
{
	const char *adr;
	IxpClient *cli;
	struct ixp *ixp;

	adr = luaL_checkstring (L, 1);

	DBGF("** ixp.new ([%s]) **\n", adr);

	cli = ixp_mount((char*)adr);
	if (!cli)
		return lixp_pusherror (L, "could not open ixp connection");

	ixp = (struct ixp*)lua_newuserdata(L, sizeof (struct ixp));

	luaL_getmetatable (L, L_IXP_MT);
	lua_setmetatable (L, -2);

	ixp->address = strdup (adr);
	ixp->client = cli;

	return 1;
}

static int l_ixp_gc (lua_State *L)
{
	struct ixp *ixp = lixp_checkixp (L, 1);

	DBGF("** ixp:__gc (%p [%s]) **\n", ixp, ixp->address);

	ixp_unmount (ixp->client);
	free ((char*)ixp->address);

	return 0;
}

/* ------------------------------------------------------------------------
 * the class method table 
 */
static const luaL_reg class_table[] =
{
	{ "new",		l_new },
	
	{ NULL,			NULL },
};

/* ------------------------------------------------------------------------
 * the instance method table 
 */
static const luaL_reg instance_table[] =
{
	{ "__tostring",		l_ixp_tostring },
	{ "__gc",		l_ixp_gc },

	{ "write",		l_ixp_write },
	{ "read",		l_ixp_read },

	{ "create",		l_ixp_create },
	{ "remove",		l_ixp_remove },

	{ "iread",		l_ixp_iread },
	{ "idir",		l_ixp_idir },

	{ "stat",		l_ixp_stat },

	{ NULL,			NULL },
};

/* ------------------------------------------------------------------------
 * the class metatable
 */
static int lixp_init_ixp_class (lua_State *L)
{
	luaL_newmetatable(L, L_IXP_MT);

	// setup the __index and __gc field
	lua_pushstring (L, "__index");
	lua_pushvalue (L, -2);		// pushes the new metatable
	lua_settable (L, -3);		// metatable.__index = metatable

	luaL_openlib (L, NULL, instance_table, 0);
	luaL_openlib (L, "ixp", class_table, 0);

#if 0
	luaL_register (L, MYNAME, R);
	lua_pushliteral (L, "version");
	lua_pushliteral (L, MYVERSION);
	lua_settable (L, -3);
#endif
	return 1;
}

/* ------------------------------------------------------------------------
 * library entry
 */
LUALIB_API int luaopen_ixp (lua_State *L)
{
	lixp_init_iread_mt (L);
	lixp_init_idir_mt (L);

	return lixp_init_ixp_class (L);
}
