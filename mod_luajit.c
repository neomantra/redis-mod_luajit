#include <stdio.h>
#include <luajit-2.0/lua.h>
#include <luajit-2.0/lualib.h>
#include <luajit-2.0/lauxlib.h>
#include "redismodule.h"

/// LuaJIT state shared by module
lua_State* RM_LJ_state = NULL;

/// The RedisModuleContext in active use by EVAL
RedisModuleCtx* RM_LJ_evalCtx = NULL;

/// Index of the pcall handler (which creates a traceback)
int RM_LJ_pcallHandlerIndex;

/// Buffer we use for formatting error messages
char RM_LJ_errorBuffer[2048];


// http://stackoverflow.com/questions/12256455/print-stacktrace-from-c-code-with-embedded-lua
static int traceback(lua_State *L) {
  if (!lua_isstring(L, 1))  /* 'message' not a string? */
    return 1;  /* keep it intact */
  lua_getfield(L, LUA_GLOBALSINDEX, "debug");
  if (!lua_istable(L, -1)) {
    lua_pop(L, 1);
    return 1;
  }
  lua_getfield(L, -1, "traceback");
  if (!lua_isfunction(L, -1)) {
    lua_pop(L, 2);
    return 1;
  }
  lua_pushvalue(L, 1);  /* pass error message */
  lua_pushinteger(L, 2);  /* skip this function and traceback */
  lua_call(L, 2, 1);  /* call debug.traceback */
  return 1;
}


// hook for the lua_State to extract the current context
extern RedisModuleCtx* RM_LJ_GetEvalContext(void) {
    return RM_LJ_evalCtx;
}


/* LUAJIT.EVAL script
 * 
 */
int LuajitEval_RedisCommand(RedisModuleCtx *ctx, RedisModuleString **argv, int argc)
{
    if (argc != 2)
        return RedisModule_WrongArity(ctx);

    size_t len;
    const char* script = RedisModule_StringPtrLen(argv[1], &len);
    if (!script) 
        return RedisModule_ReplyWithError(ctx, "LUAJIT.EVAL: script was null");

    int res = luaL_loadstring(RM_LJ_state, script);
    if (res != 0) {
        snprintf(RM_LJ_errorBuffer, sizeof(RM_LJ_errorBuffer)-1,
                 "LUAJIT.EVAL luaL_loadstring failed: %d %s\n", res, lua_tostring(RM_LJ_state, -1));
        lua_pop(RM_LJ_state, 1);
        return RedisModule_ReplyWithError(ctx, RM_LJ_errorBuffer);
    }

    // store the context for the LuaJIT world
    RM_LJ_evalCtx = ctx;

    res = lua_pcall(RM_LJ_state, 0, LUA_MULTRET, RM_LJ_pcallHandlerIndex);
    if (res != 0) {
        snprintf(RM_LJ_errorBuffer, sizeof(RM_LJ_errorBuffer)-1,
                 "LUAJIT.EVAL lua_pcall failed: %d %s\n", res, lua_tostring(RM_LJ_state, -1));
        lua_pop(RM_LJ_state, 1);
        return RedisModule_ReplyWithError(ctx, RM_LJ_errorBuffer);
    }

    // TODO see if the EVAL script made a reply?  is that possible?
    return REDISMODULE_OK;
}


extern int RedisModule_OnLoad(RedisModuleCtx *ctx) {
    // register our module
    if (RedisModule_Init(ctx,"luajit",1,REDISMODULE_APIVER_1) == REDISMODULE_ERR)
        return REDISMODULE_ERR;

    // create the shared lua_State
    if (!RM_LJ_state) {
        RM_LJ_state = luaL_newstate();
        if (!RM_LJ_state) {
            printf("mod_luajit: failed to load Lua state\n");
            return REDISMODULE_ERR;
        }

        // load the libraries
        // TODO: make this configurable for better sandboxing
        lua_pushcfunction(RM_LJ_state, luaopen_base);
        lua_call(RM_LJ_state,0,0);
        lua_pushcfunction(RM_LJ_state,luaopen_os);
        lua_call(RM_LJ_state,0,0);
        lua_pushcfunction(RM_LJ_state,luaopen_table);
        lua_call(RM_LJ_state,0,0);
        lua_pushcfunction(RM_LJ_state,luaopen_string);
        lua_call(RM_LJ_state,0,0);
        lua_pushcfunction(RM_LJ_state,luaopen_math);
        lua_call(RM_LJ_state,0,0);
        lua_pushcfunction(RM_LJ_state,luaopen_debug);
        lua_call(RM_LJ_state,0,0);
        lua_pushcfunction(RM_LJ_state, luaopen_package);
        lua_call(RM_LJ_state,0,0);
        lua_pushcfunction(RM_LJ_state, luaopen_ffi);
        lua_call(RM_LJ_state,0,0);
        lua_pushcfunction(RM_LJ_state, luaopen_jit);
        lua_call(RM_LJ_state,0,0);
        lua_pushcfunction(RM_LJ_state, luaopen_bit);
        lua_call(RM_LJ_state,0,0);

        // install error pcall handler
        lua_pushcfunction(RM_LJ_state, traceback);
        RM_LJ_pcallHandlerIndex = lua_gettop(RM_LJ_state);

        // load the redismodule library
        lua_getfield(RM_LJ_state, LUA_GLOBALSINDEX, "require");
        lua_pushstring(RM_LJ_state, "redismodule");
        int res = lua_pcall(RM_LJ_state, 1, 1, RM_LJ_pcallHandlerIndex);
        if (res != 0) {
            printf("redis-mod_luajit require 'redismodule' failed: %d %s\n", res, lua_tostring(RM_LJ_state, -1));
            lua_pop(RM_LJ_state, 1);
            return REDISMODULE_ERR;
        }
        lua_setfield(RM_LJ_state, LUA_GLOBALSINDEX, "RM");
    }

    // register commands
    if (RedisModule_CreateCommand(ctx,"luajit.eval",LuajitEval_RedisCommand,"",1,1,1) == REDISMODULE_ERR)
        return REDISMODULE_ERR;

    return REDISMODULE_OK;
}


// TODO RedisModule_UnLoad(RedisModuleCtx *ctx)
