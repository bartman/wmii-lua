#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
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

// local hepers
static int loop_handle_event (lua_State *L, struct lel_program *prog);
static void kill_exec (lua_State *L, struct lel_eventloop *el, int fd);

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
			// we allocate the buffer and room for a terminator at the end
			+ LEL_PROGRAM_IO_BUF_SIZE + 1);
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

	lua_pushinteger (L, prog->fd);
	return 1;
}

/* ------------------------------------------------------------------------
 * checks if an executable is still running
 *
 * lua: running = el:check_exec(fd)
 *
 *    fd - file descriptor returned from el:add_exec()
 *    running - boolean indicating if it's still running
 */

int l_eventloop_check_exec (lua_State *L)
{
	struct lel_eventloop *el;
	int fd, i;
	bool found = false;

	el = lel_checkeventloop(L, 1);
	fd = luaL_checknumber(L, 2);

	DBGF("** eventloop:check_exec (%d) **\n", fd);

	for (i=(el->progs_count-1); i>=0; i--) {
		struct lel_program *prog;

		prog = el->progs[i];

		if (prog->fd != fd)
			continue;

		found = true;
		break;
	}

	lua_pushboolean(L, found);
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
	int fd;

	el = lel_checkeventloop (L, 1);
	fd = luaL_checknumber (L, 2);

	DBGF("** eventloop:kill_exec (%d) **\n", fd);

	kill_exec (L, el, fd);

	return 0;
}

static void kill_exec (lua_State *L, struct lel_eventloop *el, int fd)
{
	struct lel_program *prog;
	int status;

	prog = progs_remove (el, fd);
	if (! prog)
		return;

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
	lua_settable (L, -3);			// eventloop[fd] = nil

	// cleanup
	lua_gc (L, LUA_GCSTEP, 10);
}

/* ------------------------------------------------------------------------
 * runs the select loop over all registered execs with timeout
 *
 * lua: el.run_loop (timeout)
 */
int l_eventloop_run_loop (lua_State *L)
{
	struct lel_eventloop *el;
	int timeout, status;
	fd_set rfds, xfds;
	struct timeval tv;

	el = lel_checkeventloop (L, 1);
	timeout = luaL_optnumber (L, 2, 0);

	DBGF("** eventloop:run_loop (%d) **\n", timeout);

	// init for timeout
	tv.tv_sec = timeout;
	tv.tv_usec = 0;

	// run the loop
	while (el->progs_count) {
		int i, rc;

		// catchup on programs that quit
		while (waitpid (-1, &status, WNOHANG) > 0);

		// init for select
		rfds = el->all_fds;
		xfds = el->all_fds;

		// wait for the next event
		rc = select (el->max_fd+1, &rfds, NULL, &xfds, &tv);
		if (rc<0)
			return lel_pusherror (L, "select failed");

		if (!rc)
			// timeout
			break;

		for (i=(el->progs_count-1); i>=0; i--) {
			struct lel_program *prog;
			bool dead = false;

			prog = el->progs[i];

			if (FD_ISSET (prog->fd, &rfds)) {
				rc = loop_handle_event (L, prog);
				if (rc<=0)
					dead = true;

				// count could have changed in callback
				if (i >= el->progs_count)
					break;
			}

			if (dead /* || FD_ISSET (prog->fd, &xfds) */ ) {
				DBGF("** killing %d (fd=%d) **\n",
						prog->pid, prog->fd);
				kill_exec(L, el, prog->fd);
			}
		}
	}

	// catchup on programs that quit
	while (waitpid (-1, &status, WNOHANG) > 0);
	
	return 0;
}

/* ------------------------------------------------------------------------
 * terminates all executables
 */
int l_eventloop_kill_all (lua_State *L)
{
	struct lel_eventloop *el;
	int i;

	el = lel_checkeventloop (L, 1);

	for (i=(el->progs_count-1); i>=0; i--) {
		struct lel_program *prog;

		prog = el->progs[i];
		kill_exec (L, el, prog->fd);
	}

	return 0;
}

/* ------------------------------------------------------------------------
 * read more data and call callbacks
 */

static void prog_read_more (lua_State *L, struct lel_program *prog)
{
	int rc;
	char *buf;
	ssize_t len;

	if (!prog->buf_len) {
		// reset pos to beginning
		prog->buf_pos = 0;
	}

	buf = prog->buf + prog->buf_pos;
	len = LEL_PROGRAM_IO_BUF_SIZE - prog->buf_pos - prog->buf_len;

	if (len<=0) {
		// reached the end
		if (! prog->buf_pos) {
			// cannot shift data down
			prog->read_rc = -1;
			prog->read_errno = EBUSY;
			return;
		}

		// shift data down to make some more room
		memmove (prog->buf, buf, prog->buf_len);
		prog->buf_pos = 0;
		buf = prog->buf;
	}

	// get some data
	rc = read (prog->fd, buf, len);

	prog->read_rc = rc;
	prog->read_errno = errno;

	if (rc>0) {
		prog->buf_len = rc;
		buf[rc] = 0;
	}

}

static void lua_issue_callback (lua_State *L, struct lel_program *prog,
		char *string)
{
	int top;

	// backup top of stack
	top = lua_gettop (L);

	// find the call back function
	luaL_getmetatable (L, L_EVENTLOOP_MT);	// [-2] = get the table
	lua_pushinteger (L, prog->fd);		// [-1] = the key
	lua_gettable (L, -2);			// push (eventloop[fd])

	if (string) {
		// success
		lua_pushstring (L, string);
		lua_call (L, 1, 0);

	} else if (prog->read_rc == 0) {
		// stream ended
		lua_pushnil (L);
		lua_pushstring (L, "EOF");
		lua_call (L, 2, 0);

	} else if (prog->read_rc < 0) {
		// error reading
		lua_pushnil (L);
		lua_pushstring (L, strerror(prog->read_errno));
		lua_call (L, 2, 0);
	}

	// restore top of stack
	lua_settop (L, top);
}

static int loop_handle_event (lua_State *L, struct lel_program *prog)
{
	char *s, *e, *cr;

	prog_read_more (L, prog);

	while (prog->buf_len) {
		// as long as we have some data we try to find a full line 
		s = prog->buf + prog->buf_pos;
		e = s + prog->buf_len;

		cr = strchr (s, '\n');
		if (cr) {
			// we have a match: s..cr is our substring
			int len = (cr-s) + 1;
			*cr = 0;

			lua_issue_callback (L, prog, s);

			prog->buf_pos += len;
			prog->buf_len -= len;

		} else if (!prog->buf_pos) {
			// no match and we cannot even read more out of 
			// the buffer; we have to return the partial buffer
			lua_issue_callback (L, prog, s);

			prog->buf_len = 0;

		} else {
			// no match, we will try to read more on next select()
			// read event
			break;
		}
	}

	return prog->read_rc;
}

