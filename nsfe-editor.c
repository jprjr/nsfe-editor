#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <iup.h>
#include <iuplua.h>

void main(void)
{
  lua_State *L = luaL_newstate();
  luaL_openlibs(L);

  iuplua_open(L);

#ifdef _DEBUG
  iuplua_dofile(L,"nsfe-editor.lua");
#else
#include "nsfe-editor.lh"
#endif

  lua_close(L);
}
