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
};

extern struct eventloop *lel_checkeventloop (lua_State *L, int narg);
extern int l_eventloop_tostring (lua_State *L);

/* exported api */
extern int l_eventloop_add_exec (lua_State *L);
extern int l_eventloop_kill_exec (lua_State *L);
extern int l_eventloop_run_loop (lua_State *L);

#endif // __LUAIXP_INSTANCE_H__
