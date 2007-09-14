#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <signal.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/wait.h>

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
 * dealing with program list
 */

static int progs_compare (const void *_one, const void *_two)
{
	const struct lel_program *const*one = _one;
	const struct lel_program *const*two = _two;

	return (*one)->fd - (*two)->fd;
}

static void progs_add (struct lel_eventloop *el, struct lel_program *prog)
{
	// make more room
	if (el->progs_size <= el->progs_count) {
		size_t bytes;

		el->progs_size += LEL_PROGS_ARRAY_GROWS_BY;
		bytes = el->progs_size * sizeof(struct lel_program*);
		
		el->progs = realloc (el->progs, bytes);
		if (!el->progs) {
			// TODO: we could handle this better then blowing away
			// all of our data if we run out of room.  For now exit.
			perror ("malloc");
			exit (1);
		}
	}

	el->progs[el->progs_count++] = prog;

	qsort (el->progs, el->progs_count, sizeof (struct lel_program*),
			progs_compare);
}

static struct lel_program * progs_remove (struct lel_eventloop *el, int fd)
{
	struct lel_program key = {.fd = fd};
	struct lel_program *pkey = &key;
	struct lel_program *found;
	struct lel_program **pfound;
	size_t end_bytes;

	// find the program
	pfound = bsearch (&pkey, el->progs, el->progs_count,
			sizeof (struct lel_program*), progs_compare);
	if (!pfound)
		return NULL;

	found = *pfound;
	if (!found)
		return NULL;

	// adjust remaining entries
	el->progs_count --;
	end_bytes = (char*)(el->progs + el->progs_count) - (char*)pfound;
	memmove (pfound, pfound+1, end_bytes);

	return found;
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

	// create a new program entry
	prog = (struct lel_program*) malloc (sizeof (struct lel_program) 
			+ LEL_PROGRAM_IO_BUF_SIZE);
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

	// add to the list
	progs_add (el, prog);

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
	int fd, status;

	el = lel_checkeventloop (L, 1);
	fd = luaL_checknumber (L, 2);

	DBGF("** eventloop:kill_exec (%d) **\n", fd);

	prog = progs_remove (el, fd);
	if (! prog)
		return 0;

	if (el->max_fd == prog->fd) {
		if (el->progs_count)
			// last entry is the new max
			el->max_fd = el->progs[el->progs_count-1]->fd;
		else
			// there are no more entries
			el->max_fd = 0;
	}

	FD_CLR (prog->fd, &el->all_fds);

	kill (prog->pid, SIGTERM);
	close (prog->fd);
	free (prog);

	// catchup on programs that quit
	while (waitpid (-1, &status, WNOHANG) > 0);

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

	el = lel_checkeventloop (L, 1);
	timeout = luaL_optnumber (L, 2, 0);

	DBGF("** eventloop:run_loop (%d) **\n", timeout);

	// init for select

	rfds = el->all_fds;
	tv.tv_sec = timeout;
	tv.tv_usec = 0;

	// run the loop

	for (;;) {
		int i, status, rc;

		// catchup on programs that quit
		while (waitpid (-1, &status, WNOHANG) > 0);

		// wait for the next event
		rc = select (el->max_fd+1, &rfds, NULL, &xfds, &tv);
		if (rc<0)
			return lel_pusherror (L, "select failed");

		if (!rc)
			continue;

		for (i=0; i < el->progs_count; i++) {
			struct lel_program *prog;

			prog = el->progs[i];


#if 1		// TODO hack hack hack
			if (FD_ISSET (prog->fd, &xfds)) {
				fprintf (stderr, "XXX: exception\n");
				exit(1);
			}
#endif

			if (FD_ISSET (prog->fd, &rfds)) {
				(void)loop_handle_event (L, prog);
			}
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
	rc = read (prog->fd, prog->buf, LEL_PROGRAM_IO_BUF_SIZE);
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

