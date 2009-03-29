#ifndef __LUAIXP_INSTANCE_H__
#define __LUAIXP_INSTANCE_H__

#include <lua.h>

#define L_EVENTLOOP_MT "eventloop.eventloop_mt"

/* the C representation of a eventloop instance object */
struct lel_program;
struct lel_eventloop {
	struct lel_program **progs;	// array of programs, sorted by fd
	size_t progs_size;		// number allocated entries
	size_t progs_count;		// first unused entry

	fd_set all_fds;
	int max_fd;
};
#define LEL_PROGS_ARRAY_GROWS_BY 32

struct lel_program {
	char *cmd;
	int fd;
	int pid;
	int read_rc;
	int read_errno;
	size_t buf_pos;
	size_t buf_len;
	char buf[0];		// this has to be last in the structure
};
#define LEL_PROGRAM_IO_BUF_SIZE 4096

extern struct lel_eventloop *lel_checkeventloop (lua_State *L, int narg);
extern int l_eventloop_tostring (lua_State *L);

/* exported api */
extern int l_eventloop_add_exec (lua_State *L);
extern int l_eventloop_check_exec (lua_State *L);
extern int l_eventloop_kill_exec (lua_State *L);
extern int l_eventloop_run_loop (lua_State *L);
extern int l_eventloop_kill_all (lua_State *L);

#endif // __LUAIXP_INSTANCE_H__
