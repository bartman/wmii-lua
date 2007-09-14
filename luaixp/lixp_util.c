#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <time.h>

#include <ixp.h>
#include <lua.h>
#include <lauxlib.h>

#include "lixp_util.h"


/* ------------------------------------------------------------------------
 * error helper
 */
int lixp_pusherror(lua_State *L, const char *info)
{
	lua_pushnil(L);
	if (info==NULL) {
		lua_pushstring(L, strerror(errno));
		lua_pushnumber(L, errno);
		return 3;
	} else if (errno) {
		lua_pushfstring(L, "%s: %s", info, strerror(errno));
		lua_pushnumber(L, errno);
		return 3;
	} else {
		lua_pushfstring(L, "%s", info);
		return 2;
	}
}

/* ------------------------------------------------------------------------
 * write a buffer to an IXP file
 */
int lixp_write_data (IxpCFid *fid, const char *data, size_t data_len)
{
	size_t left;
	off_t ofs = 0;

	left = data_len;
	while (left) {
		int rc = ixp_write(fid, (char*)data + ofs, left);
		if (rc < 0)
			return rc;

		else if (rc > left)
			return -ENXIO;

		left -= rc;
		ofs += rc;
	}

	return data_len;
}

/* ------------------------------------------------------------------------
 * dump IXP status structure to lua table
 */
static void setrwx(long m, char *s)
{
	static char *modes[] = {
		"---", "--x", "-w-",
		"-wx", "r--", "r-x",
		"rw-", "rwx",
	};
	strncpy(s, modes[m], 3);
}

static void build_modestr(char *buf, const struct IxpStat *stat)
{
	buf[0]='-';
	if(stat->mode & P9_DMDIR)
		buf[0]='d';
	buf[1]='-';
	setrwx((stat->mode >> 6) & 7, &buf[2]);
	setrwx((stat->mode >> 3) & 7, &buf[5]);
	setrwx((stat->mode >> 0) & 7, &buf[8]);
	buf[11] = 0;
}

static void build_timestr(char *buf, const struct IxpStat *stat)
{
	ctime_r((time_t*)&stat->mtime, buf);
	buf[strlen(buf) - 1] = '\0';
}


#define setfield(type,name,value) \
	lua_pushstring (L, name); \
	lua_push##type (L, value); \
	lua_settable (L, -3);
int lixp_pushstat (lua_State *L, const struct IxpStat *stat)
{
	static char buf[32];
	lua_newtable (L);

	setfield(number, "type", stat->type);
	setfield(number, "dev", stat->dev);
	//setfield(Qid,    "qid", stat->qid);	// TODO: what is this?
	setfield(number, "mode", stat->mode);
	setfield(number, "atime", stat->atime);
	setfield(number, "mtime", stat->mtime);
	setfield(number, "length", stat->length);
	setfield(string, "name", stat->name);
	setfield(string, "uid", stat->uid);
	setfield(string, "gid", stat->gid);
	setfield(string, "muid", stat->muid);

	build_modestr(buf, stat);
	setfield(string, "modestr", buf);

	build_timestr(buf, stat);
	setfield(string, "timestr", buf);

	return 1;
}


