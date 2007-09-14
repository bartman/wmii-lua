#ifndef __LUAIXP_DEBUG_H__
#define __LUAIXP_DEBUG_H__

#include <lua.h>

#ifdef DBG
#define DBGF(fmt,args...) fprintf(stderr,fmt,##args)
#else
#define DBGF(fmt,args...) ({})
#endif

extern void l_stack_dump (lua_State *l);

#endif // __LUAIXP_DEBUG_H__
