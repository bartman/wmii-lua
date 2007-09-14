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

#if 0
static my_checkfunction (lua_State *L)
{

}
#endif

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
	struct eventloop *el;
	struct program *prog;
	const char *cmd;
	int pfds[2];			// 0 is server, 1 is client
	int rc, pid;

	el = lel_checkeventloop (L, 1);
	cmd = luaL_checkstring (L, 2);
	(void)luaL_checktype (L, 3, LUA_TFUNCTION);

	DBGF("** eventloop:add_exec (%s, ...) **\n", cmd);
l_stack_dump ("  ", L);

#if 1		// TODO fix me!
if (el->prog)
	return lel_pusherror (L, "only one at a time for now");
#endif

	// spawn off a worker process

	rc = pipe(pfds);
	if (rc<0)
		return lel_pusherror (L, "failed to create a pipe");

	pid = vfork();
	if (pid<0) {
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

	// create a new program entry
	prog = (struct program*) malloc (sizeof (struct program));
	if (!prog)
		return lel_pusherror (L, "failed to allocate program structure");

	prog->cmd = strdup (cmd);
	prog->pid = pid;
	prog->fd = pfds[0];

	if (el->max_fd < prog->fd)
		el->max_fd = prog->fd;

	FD_SET (prog->fd, &el->all_fds);

	el->prog = prog;

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
	struct eventloop *el;
	struct program *prog;
	int fd;

	el = lel_checkeventloop (L, 1);
	fd = luaL_checknumber (L, 2);

	// ...
	DBGF("** eventloop:kill_exec (%d) **\n", fd);
l_stack_dump ("  ", L);

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
	
	return 0;
}

/* ------------------------------------------------------------------------
 * runs the select loop over all registered execs with timeout
 *
 * lua: el.run_loop (timeout)
 */
static void loop_handle_event (lua_State *L, struct program *prog);
int l_eventloop_run_loop (lua_State *L)
{
	struct eventloop *el;
	int timeout;
	fd_set rfds, xfds;
	struct timeval tv;
	int rc;

	el = lel_checkeventloop (L, 1);
	timeout = luaL_optnumber (L, 2, 0);

	DBGF("** eventloop:run_loop (%d) **\n", timeout);
l_stack_dump ("  ", L);

	// init for select

	rfds = el->all_fds;
	tv.tv_sec = timeout;
	tv.tv_usec = 0;

	// run the loop

	for (;;) {
		struct program *prog;

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
			loop_handle_event (L, prog);
		}

		// get ready for next run...

		rfds = el->all_fds;
		tv.tv_sec = timeout;
		tv.tv_usec = 0;
	}
	
	return 0;
}

static void loop_handle_event (lua_State *L, struct program *prog)
{
	char buffer[4096];
	int rc;


	rc = read (prog->fd, buffer, 4096);

#if 1	// TODO hack hack hack
	if (!rc) {
		fprintf (stderr, "XXX: EOF\n");
		exit(1);
	}
#endif

	printf ("event(%03d):  ", rc);
	fflush (stdout);

	if (rc>0) {
		char *p;

		for (p = buffer + rc - 1; p >= buffer; p--) {
			if (isgraph(*p))
				break;
			*p = '_';
		}

		write (1, buffer, rc);
	}
	printf ("\n");

	// TODO call the callback function
}

