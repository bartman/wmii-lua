#ifndef __LUAIXP_UTIL_H__
#define __LUAIXP_UTIL_H__

#include <lua.h>

struct IxpCFid;
struct IxpStat;

extern int lixp_pusherror(lua_State *L, const char *info);

extern int lixp_write_data (struct IxpCFid *fid, const char *data, size_t data_len);

extern int lixp_pushstat (lua_State *L, const struct IxpStat *stat);

#endif // __LUAIXP_UTIL_H__
