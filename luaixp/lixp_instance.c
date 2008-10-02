#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <signal.h>

#include <ixp.h>
#include <lua.h>
#include <lauxlib.h>

#include "lixp_debug.h"
#include "lixp_util.h"
#include "lixp_instance.h"


/* ------------------------------------------------------------------------
 * utility functions
 */

struct ixp *lixp_checkixp (lua_State *L, int narg)
{
	void *ud = luaL_checkudata (L, narg, L_IXP_MT);
	luaL_argcheck (L, ud != NULL, 1, "`ixp' expected");
	return (struct ixp*)ud;
}

int l_ixp_tostring (lua_State *L)
{
	struct ixp *ixp = lixp_checkixp (L, 1);
	lua_pushfstring (L, "ixp instance %p", ixp);
	return 1;
}

/* ------------------------------------------------------------------------
 * lua: write(file, data) -- writes data to a file 
 */

int l_ixp_write (lua_State *L)
{
	struct ixp *ixp;
	IxpCFid *fid;
	const char *file;
	const char *data;
	size_t data_len;
	int rc;

	ixp = lixp_checkixp (L, 1);
	file = luaL_checkstring (L, 2);
	data = luaL_checklstring (L, 3, &data_len);

	fid = ixp_open(ixp->client, file, P9_OWRITE);
	if(fid == NULL)
		return lixp_pusherror (L, "count not open p9 file");

	DBGF("** ixp.write (%s,%s) **\n", file, data);
	
	rc = lixp_write_data (fid, data, data_len);
	if (rc < 0) {
		ixp_close(fid);
		return lixp_pusherror (L, "failed to write to p9 file");
	}

	ixp_close(fid);
	return 0;
}

/* ------------------------------------------------------------------------
 * lua: data = read(file) -- returns all contents (upto 4k) 
 */
int l_ixp_read (lua_State *L)
{
	struct ixp *ixp;
	IxpCFid *fid;
	const char *file;
	char *buf, *_buf;
	size_t buf_ofs, buf_size;

	ixp = lixp_checkixp (L, 1);
	file = luaL_checkstring (L, 2);

	fid = ixp_open(ixp->client, file, P9_OREAD);
	if(fid == NULL)
		return lixp_pusherror (L, "count not open p9 file");

	buf = malloc (fid->iounit);
	if (!buf) {
		ixp_close(fid);
		return lixp_pusherror (L, "count not allocate memory");
	}
	buf_ofs = 0;
	buf_size = fid->iounit;

	DBGF("** ixp.read (%s) **\n", file);
	
	for (;;) {
		int rc = ixp_read (fid, buf+buf_ofs, buf_size-buf_ofs);
		if (rc==0)
			break;
		else if (rc<0) {
			ixp_close(fid);
			return lixp_pusherror (L, "failed to read from p9 file");
		}

		buf_ofs += rc;

		if (buf_ofs >= buf_size)
			return lixp_pusherror (L, "internal error while reading");

		if (buf_size >= 4096)
			break;

		_buf = realloc (buf, 4096);
		if (!_buf) {
			ixp_close(fid);
			free(buf);
			return lixp_pusherror (L, "count not allocate memory");
		}
		buf = _buf;
		buf_size = 4096;
	}

	ixp_close(fid);

	if (memchr(buf, '\0', buf_ofs))
		fprintf(stderr, "** WARNING: ixp.read (%s): result contains null characters **\n", file);

	lua_pushlstring (L, buf, buf_ofs);
	return 1;
}

/* ------------------------------------------------------------------------
 * lua: create(file, [data]) -- create a file, optionally write data to it 
 */
int l_ixp_create (lua_State *L)
{
	struct ixp *ixp;
	IxpCFid *fid;
	const char *file;
	const char *data;
	size_t data_len = 0;

	ixp = lixp_checkixp (L, 1);
	file = luaL_checkstring (L, 2);
	data = luaL_optlstring (L, 3, NULL, &data_len);

	DBGF("** ixp.create (%s) **\n", file);
	
	fid = ixp_create (ixp->client, file, 0777, P9_OWRITE);
	if (!fid)
		return lixp_pusherror (L, "count not create file");

	if (data && data_len
			&& !(fid->qid.type & P9_DMDIR)) {
		int rc = lixp_write_data (fid, data, data_len);
		if (rc < 0) {
			ixp_close(fid);
			return lixp_pusherror (L, "failed to write to p9 file");
		}
	}

	ixp_close(fid);
	return 0;
}

/* ------------------------------------------------------------------------
 * lua: remove(file) -- remove a file 
 */
int l_ixp_remove (lua_State *L)
{
	struct ixp *ixp;
	int rc;
	const char *file;

	ixp = lixp_checkixp (L, 1);
	file = luaL_checkstring (L, 2);

	DBGF("** ixp.remove (%s) **\n", file);
	
	rc = ixp_remove (ixp->client, file);
	if (!rc)
		return lixp_pusherror (L, "failed to remove p9 file");

	return 0;
}

/* ------------------------------------------------------------------------
 * lua: itr = iread(file) -- returns a line iterator 
 */

struct l_ixp_iread_s {
	IxpCFid *fid;
	char *buf;
	size_t buf_pos;
	size_t buf_len;
	size_t buf_size;
};

static int iread_iter (lua_State *L);

int l_ixp_iread (lua_State *L)
{
	struct ixp *ixp;
	const char *file;
	struct l_ixp_iread_s *ctx;

	ixp = lixp_checkixp (L, 1);
	file = luaL_checkstring (L, 2);

	ctx = (struct l_ixp_iread_s*)lua_newuserdata (L, sizeof(*ctx));
	if (!ctx)
		return lixp_pusherror (L, "count not allocate context");
	memset (ctx, 0, sizeof (*ctx));

	// set the metatable for the new userdata
	luaL_getmetatable (L, L_IXP_IREAD_MT);
	lua_setmetatable (L, -2);

	ctx->fid = ixp_open(ixp->client, file, P9_OREAD);
	if(ctx->fid == NULL) {
		return lixp_pusherror (L, "count not open p9 file");
	}

	DBGF("** ixp.iread (%s) **\n", file);

	// create and return the iterator function
	// the only argument is the userdata
	lua_pushcclosure (L, iread_iter, 1);
	return 1;
}

static int iread_iter (lua_State *L)
{
	struct l_ixp_iread_s *ctx;
	char *s, *cr;

	ctx = (struct l_ixp_iread_s*)lua_touserdata (L, lua_upvalueindex(1));

	DBGF("** ixp.iread - iter **\n");

	if (!ctx->buf) {
		ctx->buf = malloc (ctx->fid->iounit);
		if (!ctx->buf)
			return lixp_pusherror (L, "count not allocate memory");
		ctx->buf_size = ctx->fid->iounit;
		ctx->buf_len = 0;
	}

	if (!ctx->buf_len) {
		int rc;
		ctx->buf_pos = 0;
		rc = ixp_read (ctx->fid, ctx->buf, ctx->buf_size);
		if (rc <= 0) {
			return 0; // we are done
		}
		ctx->buf_len = rc;
	}

	s = ctx->buf + ctx->buf_pos;

	cr = strchr (s, '\n');
	if (!cr) {
		// no match, just return the whole thing
		// TODO: should read more upto a cr or some limit
		if (memchr(s, '\0', ctx->buf_len))
			fprintf(stderr, "** WARNING: ixp.iread - iter: result contains null characters **\n");
		lua_pushlstring (L, s, ctx->buf_len);
		ctx->buf_len = 0;
		return 1;

	} else {
		// we have a match s..cr is our sub string
		int len = cr-s;
		if (memchr(s, '\0', len))
			fprintf(stderr, "** WARNING: ixp.iread - iter: result contains null characters **\n");
		lua_pushlstring (L, s, len);
		len++;
		ctx->buf_pos += len;
		ctx->buf_len -= len;
		return 1;
	}
}

static int iread_gc (lua_State *L)
{
	struct l_ixp_iread_s *ctx;

	ctx = (struct l_ixp_iread_s*)lua_touserdata (L, 1);

	DBGF("** ixp.iread - gc **\n");

	ixp_close (ctx->fid);

	if (ctx->buf)
		free (ctx->buf);

	return 0;
}

void lixp_init_iread_mt (lua_State *L)
{
	luaL_newmetatable(L, L_IXP_IREAD_MT);

	// setup the __gc field
	lua_pushstring (L, "__gc");
	lua_pushcfunction (L, iread_gc);
	lua_settable (L, -3);
}

/* ------------------------------------------------------------------------
 * lua: stat = stat(file) -- returns a status table 
 */

int l_ixp_stat (lua_State *L)
{
	struct ixp *ixp;
	struct IxpStat *stat;
	const char *file;
	int rc;

	ixp = lixp_checkixp (L, 1);
	file = luaL_checkstring (L, 2);

	DBGF("** ixp.stat (%s) **\n", file);

	stat = ixp_stat(ixp->client, file);
	if(!stat)
		return lixp_pusherror(L, "cannot stat file");

	rc = lixp_pushstat (L, stat);

	ixp_freestat (stat);

	return rc;
}

/* ------------------------------------------------------------------------
 * lua: itr = idir(dir) -- returns a file name iterator 
 */

struct l_ixp_idir_s {
	IxpCFid *fid;
	unsigned char *buf;
	IxpMsg m;
};

static int idir_iter (lua_State *L);

int l_ixp_idir (lua_State *L)
{
	struct ixp *ixp;
	const char *file;
	struct l_ixp_idir_s *ctx;

	ixp = lixp_checkixp (L, 1);
	file = luaL_checkstring (L, 2);

	ctx = (struct l_ixp_idir_s*)lua_newuserdata (L, sizeof(*ctx));
	if (!ctx)
		return lixp_pusherror (L, "count not allocate context");
	memset(ctx, 0, sizeof (*ctx));

	// set the metatable for the new userdata
	luaL_getmetatable (L, L_IXP_IDIR_MT);
	lua_setmetatable (L, -2);

	ctx->fid = ixp_open(ixp->client, file, P9_OREAD);
	if(ctx->fid == NULL) {
		return lixp_pusherror (L, "count not open p9 file");
	}

	ctx->buf = malloc (ctx->fid->iounit);
	if (!ctx->buf) {
		ixp_close (ctx->fid);
		ctx->fid = NULL;
		return lixp_pusherror (L, "count not allocate memory");
	}

	DBGF("** ixp.idir (%s) **\n", file);

	// create and return the iterator function
	// the only argument is the userdata
	lua_pushcclosure (L, idir_iter, 1);
	return 1;
}

static int idir_iter (lua_State *L)
{
	struct l_ixp_idir_s *ctx;
	IxpStat stat;

	ctx = (struct l_ixp_idir_s*)lua_touserdata (L, lua_upvalueindex(1));

	DBGF("** ixp.idir - iter **\n");

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

	return lixp_pushstat (L, &stat);
}

static int idir_gc (lua_State *L)
{
	struct l_ixp_idir_s *ctx;

	ctx = (struct l_ixp_idir_s*)lua_touserdata (L, 1);

	DBGF("** ixp.idir - gc **\n");

	free (ctx->buf);

	ixp_close (ctx->fid);

	return 0;
}

void lixp_init_idir_mt (lua_State *L)
{
	luaL_newmetatable(L, L_IXP_IDIR_MT);

	// setup the __gc field
	lua_pushstring (L, "__gc");
	lua_pushcfunction (L, idir_gc);
	lua_settable (L, -3);
}

