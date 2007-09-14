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
 * utility functions
 */

struct eventloop *lel_checkeventloop (lua_State *L, int narg)
{
	void *ud = luaL_checkudata (L, narg, L_EVENTLOOP_MT);
	luaL_argcheck (L, ud != NULL, 1, "`eventloop' expected");
	return (struct eventloop*)ud;
}

int l_eventloop_tostring (lua_State *L)
{
	struct eventloop *el = lel_checkeventloop (L, 1);
	lua_pushfstring (L, "eventloop instance %p", el);
	return 1;
}

/* ------------------------------------------------------------------------
 * executes a new process to handle events from another source
 *
 * lua: fd = el:add_exec(program, function) 
 *
 *    program - a string with program to execute
 *    function - a function to call back with data read
 *    fd - returned is the file descriptor or nil on error
 */

int l_eventloop_add_exec (lua_State *L)
{
	struct eventloop *el;
	const char *program;
	//int rc;

	el = lel_checkeventloop (L, 1);
	program = luaL_checkstring (L, 2);
	//function = luaL_checklstring (L, 3, &data_len);

	// ...

	return 0;
}

/* ------------------------------------------------------------------------
 * kills off a previously spawned off process and cleans up
 * (actually, it just closes the fifo)
 *
 * lua: el:kill_exec(fd)
 *
 *    fd - return from add_exec()
 */

int l_eventloop_kill_exec (lua_State *L)
{
	struct eventloop *el;
	int fd;
	//int rc;

	el = lel_checkeventloop (L, 1);
	fd = luaL_checknumber (L, 2);

	// ...
	
	return 0;
}

/* ------------------------------------------------------------------------
 * runs the select loop over all registered execs with timeout
 *
 * lua: el.run_loop (timeout)
 */
int l_eventloop_run_loop (lua_State *L)
{
	struct eventloop *el;
	int timeout;

	el = lel_checkeventloop (L, 1);
	timeout = luaL_optnumber (L, 2, 0);

	// ...
	
	return 0;
}

