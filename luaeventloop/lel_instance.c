#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <signal.h>
#include <ctype.h>

#include <lua.h>
#include <lauxlib.h>

#include "lel_debug.h"
#include "lel_util.h"
#include "lel_instance.h"


/* ------------------------------------------------------------------------
 * utility functions
 */

struct lel_eventloop *lel_checkeventloop (lua_State *L, int narg)
{
	void *ud = luaL_checkudata (L, narg, L_EVENTLOOP_MT);
	luaL_argcheck (L, ud != NULL, 1, "`eventloop' expected");
	return (struct lel_eventloop*)ud;
}

int l_eventloop_tostring (lua_State *L)
{
	struct lel_eventloop *el = lel_checkeventloop (L, 1);
	lua_pushfstring (L, "eventloop instance %p", el);
	return 1;
}

/* ------------------------------------------------------------------------
 * executes a new process to handle events from another source
 *
 * lua: fd = el:add_exec(cmd, function) 
 *
 *    cmd - a string with program and parameters for execution
 *    function - a function to call back with data read
 *    fd - returned is the file descriptor or nil on error
 */

int l_eventloop_add_exec (lua_State *L)
{
	struct lel_eventloop *el;
	struct lel_program *prog;
	const char *cmd;
	int pfds[2];			// 0 is server, 1 is client
	int rc, pid;

	el = lel_checkeventloop (L, 1);
	cmd = luaL_checkstring (L, 2);
	(void)luaL_checktype (L, 3, LUA_TFUNCTION);

	DBGF("** eventloop:add_exec (%s, ...) **\n", cmd);

#if 1		// TODO fix me!
if (el->prog)
	return lel_pusherror (L, "only one at a time for now");
#endif

	// create a new program entry
	prog = (struct lel_program*) malloc (sizeof (struct lel_program) 
			+ PROGRAM_IO_BUF_SIZE);
	if (!prog)
		return lel_pusherror (L, "failed to allocate program structure");

	// spawn off a worker process
	rc = pipe(pfds);
	if (rc<0) {
		free (prog);
		return lel_pusherror (L, "failed to create a pipe");
	}

	pid = vfork();
	if (pid<0) {			// fork failed...
		free (prog);
		close (pfds[0]);
		close (pfds[1]);
		return lel_pusherror (L, "failed to fork()");
	}

	if (! pid) {			// client...
		close (pfds[0]);	// close the server end
		dup2(pfds[1], 1);	// stdout to client's end of pipe
		close (pfds[1]);	// close the client end
		execlp ("sh", "sh", "-c", cmd, NULL);
		exit (1);
	}

	// back in server...
	close (pfds[1]);			// close the client end

	// time to setup the program entry
	memset (prog, 0, sizeof(*prog));

	prog->cmd = strdup (cmd);
	prog->pid = pid;
	prog->fd = pfds[0];

	if (el->max_fd < prog->fd)
		el->max_fd = prog->fd;

	FD_SET (prog->fd, &el->all_fds);

	el->prog = prog;

	// everything is setup, but we need to get a hold of the function later;
	// we add the function to the L_EVENTLOOP_MT with the fd as the key...
	luaL_getmetatable (L, L_EVENTLOOP_MT);	// [-3] = get the table
	lua_pushinteger (L, prog->fd);		// [-2] = the key
	lua_pushvalue (L, 3);			// [-1] = the function (3rd arg)
	lua_settable (L, -3);			// eventloop[fd] = function

	lua_pushinteger (L, pid);
	return 1;
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
	struct lel_eventloop *el;
	struct lel_program *prog;
	int fd;

	el = lel_checkeventloop (L, 1);
	fd = luaL_checknumber (L, 2);

	DBGF("** eventloop:kill_exec (%d) **\n", fd);

#if 1			// TODO this is a hack
	prog = el->prog;
	if (! prog)
		return 0;

	el->prog = NULL;
	el->max_fd = 0;
#endif

	FD_CLR (prog->fd, &el->all_fds);

	kill (prog->pid, SIGTERM);
	close (prog->fd);
	free (prog);

	// and we still have to remove it from the table
	luaL_getmetatable (L, L_EVENTLOOP_MT);	// [-3] = get the table
	lua_pushinteger (L, prog->fd);		// [-2] = the key
	lua_pushnil (L);			// [-1] = nil
	lua_settable (L, -3);			// eventloop[fd] = function

	// cleanup
	lua_gc (L, LUA_GCSTEP, 10);
	
	return 0;
}

/* ------------------------------------------------------------------------
 * runs the select loop over all registered execs with timeout
 *
 * lua: el.run_loop (timeout)
 */
static int loop_handle_event (lua_State *L, struct lel_program *prog);
int l_eventloop_run_loop (lua_State *L)
{
	struct lel_eventloop *el;
	int timeout;
	fd_set rfds, xfds;
	struct timeval tv;
	int rc;

	el = lel_checkeventloop (L, 1);
	timeout = luaL_optnumber (L, 2, 0);

	DBGF("** eventloop:run_loop (%d) **\n", timeout);

	// init for select

	rfds = el->all_fds;
	tv.tv_sec = timeout;
	tv.tv_usec = 0;

	// run the loop

	for (;;) {
		struct lel_program *prog;

		rc = select (el->max_fd+1, &rfds, NULL, &xfds, &tv);
		if (rc<0)
			return lel_pusherror (L, "select failed");

		if (!rc)
			continue;

#if 1		// TODO again, a hack, should go through all programs
		prog = el->prog;
		if (!prog)
			continue;
#endif

#if 1		// TODO hack hack hack
		if (FD_ISSET (prog->fd, &xfds)) {
			fprintf (stderr, "XXX: exception\n");
			exit(1);
		}
#endif

		if (FD_ISSET (prog->fd, &rfds)) {
			(void)loop_handle_event (L, prog);
		}

		// get ready for next run...
		rfds = el->all_fds;
		tv.tv_sec = timeout;
		tv.tv_usec = 0;
	}
	
	return 0;
}

static int loop_handle_event (lua_State *L, struct lel_program *prog)
{
	int top, rc, err;

	// backup top of stack
	top = lua_gettop (L);

	// get some data
	rc = read (prog->fd, prog->buf, PROGRAM_IO_BUF_SIZE);
	err = errno;

	// find the call back function
	luaL_getmetatable (L, L_EVENTLOOP_MT);	// [-2] = get the table
	lua_pushinteger (L, prog->fd);		// [-1] = the key
	lua_gettable (L, -2);			// push (eventloop[fd])

	// issue callback
	if (rc > 0) {
		// success
		lua_pushstring (L, prog->buf);
		lua_call (L, 1, 0);

	} else {
		// no more data
		lua_pushnil (L);
		if (rc == 0) {
			// stream ended
			lua_pushstring (L, "EOF");
		} else {
			// error
			lua_pushstring (L, strerror(err));
		}
		lua_call (L, 2, 0);
	}

	// restore top of stack
	lua_settop (L, top);

	return rc;
}

