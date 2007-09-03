#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

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

#if 0
	// set the metatable for the new userdata
	luaL_getmetatable (L, "ixp.iread");
	lua_setmetatable (L, -2);
#endif

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
	int rc;

	ctx = (struct l_iread_s*)lua_touserdata (L, lua_upvalueindex(1));

	fprintf (stderr, "** ixp.iread - iter **\n");

	buf = malloc (ctx->fid->iounit);
	if (!buf) {
		ixp_close(ctx->fid);
		ctx->fid = NULL;
		return pusherror (L, "count not allocate memory");
	}

	rc = ixp_read (ctx->fid, buf, ctx->fid->iounit);
	if (rc <= 0) {
		free (buf);
		ixp_close(ctx->fid);
		ctx->fid = NULL;
		return 0;
	}

	lua_pushstring (L, buf);
	return 1;
}


/* ------------------------------------------------------------------------
 * the table */
static const luaL_reg R[] =
{
	{ "test",		l_test },

	{ "write",		l_write },
	{ "read",		l_read },
	{ "iread",		l_iread },
	
	{ NULL,			NULL },
};

LUALIB_API int luaopen_ixp (lua_State *L)
{
	const char *address = "unix!/tmp/ns.bart.:0/wmii";
	client = ixp_mount((char*)address);

	luaL_register (L, MYNAME, R);
	lua_pushliteral (L, "version");
	lua_pushliteral (L, MYVERSION);
	lua_settable (L, -3);
	return 1;
}
