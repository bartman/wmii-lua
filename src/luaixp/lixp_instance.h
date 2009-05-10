#ifndef __LUAIXP_INSTANCE_H__
#define __LUAIXP_INSTANCE_H__

#include <lua.h>

struct IxpClient;

#define L_IXP_MT "ixp.ixp_mt"
#define L_IXP_IDIR_MT "ixp.idir_mt"
#define L_IXP_IREAD_MT "ixp.iread_mt"

#define IXP_READ_MAX_BUFFER_SIZE 65536   // max returned by l_ixp_read

/* the C representation of a ixp instance object */
struct ixp {
	const char *address;;
	struct IxpClient *client;
};

extern struct ixp *lixp_checkixp (lua_State *L, int narg);
extern int l_ixp_tostring (lua_State *L);

/* some additional metatables */
extern void lixp_init_iread_mt (lua_State *L);
extern void lixp_init_idir_mt (lua_State *L);

/* exported api */
extern int l_ixp_write (lua_State *L);
extern int l_ixp_read (lua_State *L);
extern int l_ixp_create (lua_State *L);
extern int l_ixp_remove (lua_State *L);
extern int l_ixp_iread (lua_State *L);
extern int l_ixp_stat (lua_State *L);
extern int l_ixp_idir (lua_State *L);

#endif // __LUAIXP_INSTANCE_H__
