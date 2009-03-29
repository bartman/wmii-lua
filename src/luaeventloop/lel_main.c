#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <signal.h>

#include <lua.h>
#include <lauxlib.h>

#include "lel_debug.h"
#include "lel_util.h"
#include "lel_instance.h"


/* ------------------------------------------------------------------------
 * lua: x = eventloop.new() -- create a new eventloop object
 */
static int l_new (lua_State *L)
{
	struct lel_eventloop *el;

	DBGF("** eventloop.new () **\n");

	el = (struct lel_eventloop*)lua_newuserdata(L, sizeof (struct lel_eventloop));

	luaL_getmetatable (L, L_EVENTLOOP_MT);
	lua_setmetatable (L, -2);

	memset (el, 0, sizeof(*el));
	FD_ZERO (&el->all_fds);

	return 1;
}

static int l_eventloop_gc (lua_State *L)
{
	struct lel_eventloop *el;
	
	el = lel_checkeventloop (L, 1);

	DBGF("** eventloop:__gc (%p) **\n", el);

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
	{ "__tostring",		l_eventloop_tostring },
	{ "__gc",		l_eventloop_gc },

	{ "add_exec",		l_eventloop_add_exec },
	{ "check_exec",		l_eventloop_check_exec },
	{ "kill_exec",		l_eventloop_kill_exec },

	{ "run_loop",		l_eventloop_run_loop },

	{ "kill_all",		l_eventloop_kill_all },

	{ NULL,			NULL },
};

/* ------------------------------------------------------------------------
 * the class metatable
 */
static int lel_init_eventloop_class (lua_State *L)
{
	luaL_newmetatable(L, L_EVENTLOOP_MT);

	// setup the __index and __gc field
	lua_pushstring (L, "__index");
	lua_pushvalue (L, -2);		// pushes the new metatable
	lua_settable (L, -3);		// metatable.__index = metatable

	luaL_openlib (L, NULL, instance_table, 0);
	luaL_openlib (L, "eventloop", class_table, 0);

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
LUALIB_API int luaopen_eventloop (lua_State *L)
{
	return lel_init_eventloop_class (L);
}
