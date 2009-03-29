#include <stdio.h>
#include <lua.h>
#include <lauxlib.h>

#include "lixp_debug.h"

void 
l_stack_dump (lua_State *l) 
{
	int i, rc;
	int top = lua_gettop(l);
	char buf[1024], *p;
	char *e = buf+sizeof(buf);

	fflush (stdout);
	fprintf (stderr, "--- stack ---\n");

	p = buf;
	*buf = 0;
	for (i = 1; i <= top; i++) {  /* repeat for each level */
		int t = lua_type(l, i);
		switch (t) {

		case LUA_TNIL: /* nothing */
			p += rc = snprintf (p, e - p, "  NIL");
			if (rc<0) break;
			break;

		case LUA_TSTRING:  /* strings */
			p += rc = snprintf (p, e - p, "  `%s'",
					lua_tostring(l, i));
			if (rc<0) break;
			break;

		case LUA_TBOOLEAN:  /* booleans */
			p += rc = snprintf (p, e-p,
					lua_toboolean(l, i) ? "true" : "false");
			if (rc<0) break;
			break;

		case LUA_TNUMBER:  /* numbers */
			p += rc = snprintf (p, e-p, "  %g",
					lua_tonumber(l, i));
			if (rc<0) break;
			break;

		case LUA_TTABLE:   /* table */
			p += rc = snprintf (p, e-p, "  table");
			if (rc<0) break;
			break;

		default:  /* other values */
			p += rc = snprintf (p, e-p, "  %s",
					lua_typename(l, t));
			if (rc<0) break;
			break;

		}
	}
	fprintf (stderr, "%s\n", buf);  /* end the listing */

	fprintf (stderr, "-------------\n");
}

