#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <time.h>

#include <ixp.h>

#define MYNAME		"ixp"
#define MYVERSION	MYNAME " library for " LUA_VERSION " / Nov 2003"

#include "lua.h"
#include "lauxlib.h"

static IxpClient *client;

static int pusherror(lua_State *L, const char *info)
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
 * lua: ixptest() */
static int l_test (lua_State *L)
{
	fprintf (stderr, "** ixp.test **\n");
	return pusherror (L, "some error occurred");
}

/* ------------------------------------------------------------------------
 * lua: write(file, data) -- writes data to a file */
static int l_write (lua_State *L)
{
	IxpCFid *fid;
	const char *file;
	const char *data;
	size_t data_len, left;
	off_t ofs = 0;

	file = luaL_checkstring (L, 1);
	data = luaL_checklstring (L, 2, &data_len);

	fid = ixp_open(client, (char*)file, P9_OWRITE);
	if(fid == NULL)
		return pusherror (L, "count not open p9 file");

	fprintf (stderr, "** ixp.write (%s,%s) **\n", file, data);
	
	left = data_len;
	while (left) {
		int rc = ixp_write(fid, (char*)data + ofs, left);
		if (rc < 0) {
			ixp_close(fid);
			return pusherror (L, "failed to write to p9 file");

		} else if (rc > data_len) {
			ixp_close(fid);
			return pusherror (L, "failed to write to p9 file");
		}

		left -= rc;
		ofs += rc;
	}

	ixp_close(fid);
	return 0;
}

/* ------------------------------------------------------------------------
 * lua: data = read(file) -- returns all contents (upto 4k) */
static int l_read (lua_State *L)
{
	IxpCFid *fid;
	const char *file;
	char *buf;
	size_t buf_ofs, buf_size, buf_left;

	file = luaL_checkstring (L, 1);

	fid = ixp_open(client, (char*)file, P9_OREAD);
	if(fid == NULL)
		return pusherror (L, "count not open p9 file");

	buf = malloc (fid->iounit);
	if (!buf) {
		ixp_close(fid);
		return pusherror (L, "count not allocate memory");
	}
	buf_ofs = 0;
	buf_size = buf_left = fid->iounit;

	fprintf (stderr, "** ixp.read (%s) **\n", file);
	
	for (;;) {
		int rc = ixp_read (fid, buf+buf_ofs, buf_left);
		if (rc==0)
			break;
		else if (rc<0) {
			ixp_close(fid);
			return pusherror (L, "failed to read from p9 file");
		}

		buf_ofs += rc;
		buf_left -= rc;

		if (buf_ofs >= buf_size)
			return pusherror (L, "internal error while reading");

		if (buf_size >= 4096)
			break;

		buf = realloc (buf, 4096);
		if (!buf) {
			ixp_close(fid);
			return pusherror (L, "count not allocate memory");
		}
		buf_size = 4096;
	}

	ixp_close(fid);

	lua_pushstring (L, buf);
	return 1;
}

/* ------------------------------------------------------------------------
 * lua: itr = iread(file) -- returns a line iterator */

struct l_iread_s {
	IxpCFid *fid;
};

static int l_iread_iter (lua_State *L);

static int l_iread (lua_State *L)
{
	const char *file;
	struct l_iread_s *ctx;

	file = luaL_checkstring (L, 1);

	ctx = (struct l_iread_s*)lua_newuserdata (L, sizeof(*ctx));
	if (!ctx)
		return pusherror (L, "count not allocate context");

	// set the metatable for the new userdata
	luaL_getmetatable (L, "ixp.iread");
	lua_setmetatable (L, -2);

	ctx->fid = ixp_open(client, (char*)file, P9_OREAD);
	if(ctx->fid == NULL) {
		return pusherror (L, "count not open p9 file");
	}

	fprintf (stderr, "** ixp.iread (%s) **\n", file);

	// create and return the iterator function
	// the only argument is the userdata
	lua_pushcclosure (L, l_iread_iter, 1);
	return 1;
}

static int l_iread_iter (lua_State *L)
{
	struct l_iread_s *ctx;
	char *buf;
	int rc, len;

	ctx = (struct l_iread_s*)lua_touserdata (L, lua_upvalueindex(1));

	fprintf (stderr, "** ixp.iread - iter **\n");

	buf = malloc (ctx->fid->iounit);
	if (!buf)
		return pusherror (L, "count not allocate memory");

	rc = ixp_read (ctx->fid, buf, ctx->fid->iounit);
	if (rc <= 0) {
		free (buf);
		return 0;
	}

	len = strlen (buf);
	if (buf[len-1] == '\n')
		buf[len-1] = 0;

	lua_pushstring (L, buf);
	return 1;
}

static int l_iread_gc (lua_State *L)
{
	struct l_iread_s *ctx;

	ctx = (struct l_iread_s*)lua_touserdata (L, 1);

	fprintf (stderr, "** ixp.iread - gc **\n");

	ixp_close (ctx->fid);

	return 0;
}

static void init_iread_mt (lua_State *L)
{
	luaL_newmetatable(L, "ixp.iread");

	// setup the __gc field
	lua_pushstring (L, "__gc");
	lua_pushcfunction (L, l_iread_gc);
	lua_settable (L, -3);
}

/* ------------------------------------------------------------------------
 * lua: stat = stat(file) -- returns a status table */

static int pushstat (lua_State *L, const struct IxpStat *stat);

static int l_stat (lua_State *L)
{
	struct IxpStat *stat;
	const char *file;
	int rc;

	file = luaL_checkstring (L, 1);

	stat = ixp_stat(client, (char*)file);
	if(!stat)
		return pusherror(L, "cannot stat file");

	rc = pushstat (L, stat);

	ixp_freestat (stat);

	return rc;
}

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
static int pushstat (lua_State *L, const struct IxpStat *stat)
{
	static char buf[32];
	lua_newtable (L);

	setfield(number, "type", stat->type);
	setfield(number, "dev", stat->dev);
	//setfield(Qid,    "qid", stat->qid);
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

/* ------------------------------------------------------------------------
 * lua: itr = idir(dir) -- returns a file name iterator */

struct l_idir_s {
	IxpCFid *fid;
	unsigned char *buf;
	IxpMsg m;
};

static int l_idir_iter (lua_State *L);

static int l_idir (lua_State *L)
{
	const char *file;
	struct l_idir_s *ctx;

	file = luaL_checkstring (L, 1);

	ctx = (struct l_idir_s*)lua_newuserdata (L, sizeof(*ctx));
	if (!ctx)
		return pusherror (L, "count not allocate context");
	memset(ctx, 0, sizeof (*ctx));

	// set the metatable for the new userdata
	luaL_getmetatable (L, "ixp.idir");
	lua_setmetatable (L, -2);

	ctx->fid = ixp_open(client, (char*)file, P9_OREAD);
	if(ctx->fid == NULL) {
		return pusherror (L, "count not open p9 file");
	}

	ctx->buf = malloc (ctx->fid->iounit);
	if (!ctx->buf) {
		ixp_close (ctx->fid);
		ctx->fid = NULL;
		return pusherror (L, "count not allocate memory");
	}

	fprintf (stderr, "** ixp.idir (%s) **\n", file);

	// create and return the iterator function
	// the only argument is the userdata
	lua_pushcclosure (L, l_idir_iter, 1);
	return 1;
}

static int l_idir_iter (lua_State *L)
{
	struct l_idir_s *ctx;
	IxpStat stat;

	ctx = (struct l_idir_s*)lua_touserdata (L, lua_upvalueindex(1));

	fprintf (stderr, "** ixp.idir - iter **\n");

	if (ctx->m.pos >= ctx->m.end) {
		int rc = ixp_read (ctx->fid, ctx->buf, ctx->fid->iounit);
		if (rc <= 0) {
			return 0;
		}

		ctx->m = ixp_message(ctx->buf, rc, MsgUnpack);
		if (ctx->m.pos >= ctx->m.end)
			return 0;
	}

	ixp_pstat(&ctx->m, &stat);

	return pushstat (L, &stat);
}

static int l_idir_gc (lua_State *L)
{
	struct l_idir_s *ctx;

	ctx = (struct l_idir_s*)lua_touserdata (L, 1);

	fprintf (stderr, "** ixp.idir - gc **\n");

	free (ctx->buf);

	ixp_close (ctx->fid);

	return 0;
}

static void init_idir_mt (lua_State *L)
{
	luaL_newmetatable(L, "ixp.idir");

	// setup the __gc field
	lua_pushstring (L, "__gc");
	lua_pushcfunction (L, l_idir_gc);
	lua_settable (L, -3);
}

/* ------------------------------------------------------------------------
 * the table */
static const luaL_reg R[] =
{
	{ "test",		l_test },

	{ "write",		l_write },
	{ "read",		l_read },
	{ "iread",		l_iread },
	{ "idir",		l_idir },

	{ "stat",		l_stat },

	
	{ NULL,			NULL },
};

LUALIB_API int luaopen_ixp (lua_State *L)
{
	const char *address = "unix!/tmp/ns.bart.:0/wmii";
	client = ixp_mount((char*)address);

	init_iread_mt (L);
	init_idir_mt (L);

	luaL_register (L, MYNAME, R);
	lua_pushliteral (L, "version");
	lua_pushliteral (L, MYVERSION);
	lua_settable (L, -3);
	return 1;
}
