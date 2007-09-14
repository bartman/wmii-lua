#ifndef __LUAIXP_INSTANCE_H__
#define __LUAIXP_INSTANCE_H__

#include <lua.h>

#define L_EVENTLOOP_MT "lel.lel_mt"

/* the C representation of a eventloop instance object */
struct program;
struct eventloop {
	// TODO fill in with table that tracks executables
	struct program *prog;	// support only one right now

	fd_set all_fds;
	int max_fd;
};

struct program {
	char *cmd;
	int fd;
	int pid;
	size_t buf_pos;
	size_t buf_len;
	char buf[0];		// this has to be last in the structure
};
#define PROGRAM_IO_BUF_SIZE 4096

extern struct eventloop *lel_checkeventloop (lua_State *L, int narg);
extern int l_eventloop_tostring (lua_State *L);

/* exported api */
extern int l_eventloop_add_exec (lua_State *L);
extern int l_eventloop_kill_exec (lua_State *L);
extern int l_eventloop_run_loop (lua_State *L);

#endif // __LUAIXP_INSTANCE_H__
