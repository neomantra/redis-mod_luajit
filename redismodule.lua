-- redismodule.lua
-- Copyright (c) 2016 Evan Wies
--
-- extracted from:
--    https://github.com/antirez/redis/blob/unstable/src/redismodule.h
--
-- NOTE: the API is currently unstable

local ffi = require 'ffi'

ffi.cdef([[
typedef long long mstime_t;

typedef struct RedisModuleCtx RedisModuleCtx;
typedef struct RedisModuleKey RedisModuleKey;
typedef struct RedisModuleString RedisModuleString;
typedef struct RedisModuleCallReply RedisModuleCallReply;

typedef int (*RedisModuleCmdFunc) (RedisModuleCtx *ctx, RedisModuleString **argv, int argc);

int RM_CreateCommand(RedisModuleCtx *ctx, const char *name, RedisModuleCmdFunc cmdfunc, const char *strflags, int firstkey, int lastkey, int keystep);
int RM_SetModuleAttribs(RedisModuleCtx *ctx, const char *name, int ver, int apiver);
int RM_WrongArity(RedisModuleCtx *ctx);
int RM_ReplyWithLongLong(RedisModuleCtx *ctx, long long ll);
int RM_GetSelectedDb(RedisModuleCtx *ctx);
int RM_SelectDb(RedisModuleCtx *ctx, int newid);
void *RM_OpenKey(RedisModuleCtx *ctx, RedisModuleString *keyname, int mode);
void RM_CloseKey(RedisModuleKey *kp);
int RM_KeyType(RedisModuleKey *kp);
size_t RM_ValueLength(RedisModuleKey *kp);
int RM_ListPush(RedisModuleKey *kp, int where, RedisModuleString *ele);
RedisModuleString *RM_ListPop(RedisModuleKey *key, int where);
RedisModuleCallReply *RM_Call(RedisModuleCtx *ctx, const char *cmdname, const char *fmt, ...);
const char *RM_CallReplyProto(RedisModuleCallReply *reply, size_t *len);
void RM_FreeCallReply(RedisModuleCallReply *reply);
int RM_CallReplyType(RedisModuleCallReply *reply);
long long RM_CallReplyInteger(RedisModuleCallReply *reply);
size_t RM_CallReplyLength(RedisModuleCallReply *reply);
RedisModuleCallReply *RM_CallReplyArrayElement(RedisModuleCallReply *reply, size_t idx);
RedisModuleString *RM_CreateString(RedisModuleCtx *ctx, const char *ptr, size_t len);
RedisModuleString *RM_CreateStringFromLongLong(RedisModuleCtx *ctx, long long ll);
void RM_FreeString(RedisModuleCtx *ctx, RedisModuleString *str);
const char *RM_StringPtrLen(RedisModuleString *str, size_t *len);
int RM_ReplyWithError(RedisModuleCtx *ctx, const char *err);
int RM_ReplyWithSimpleString(RedisModuleCtx *ctx, const char *msg);
int RM_ReplyWithArray(RedisModuleCtx *ctx, long len);
void RM_ReplySetArrayLength(RedisModuleCtx *ctx, long len);
int RM_ReplyWithStringBuffer(RedisModuleCtx *ctx, const char *buf, size_t len);
int RM_ReplyWithString(RedisModuleCtx *ctx, RedisModuleString *str);
int RM_ReplyWithNull(RedisModuleCtx *ctx);
int RM_ReplyWithDouble(RedisModuleCtx *ctx, double d);
int RM_ReplyWithCallReply(RedisModuleCtx *ctx, RedisModuleCallReply *reply);
int RM_StringToLongLong(RedisModuleString *str, long long *ll);
int RM_StringToDouble(RedisModuleString *str, double *d);
void RM_AutoMemory(RedisModuleCtx *ctx);
int RM_Replicate(RedisModuleCtx *ctx, const char *cmdname, const char *fmt, ...);
int RM_ReplicateVerbatim(RedisModuleCtx *ctx);
const char *RM_CallReplyStringPtr(RedisModuleCallReply *reply, size_t *len);
RedisModuleString *RM_CreateStringFromCallReply(RedisModuleCallReply *reply);
int RM_DeleteKey(RedisModuleKey *key);
int RM_StringSet(RedisModuleKey *key, RedisModuleString *str);
char *RM_StringDMA(RedisModuleKey *key, size_t *len, int mode);
int RM_StringTruncate(RedisModuleKey *key, size_t newlen);
mstime_t RM_GetExpire(RedisModuleKey *key);
int RM_SetExpire(RedisModuleKey *key, mstime_t expire);
int RM_ZsetAdd(RedisModuleKey *key, double score, RedisModuleString *ele, int *flagsptr);
int RM_ZsetIncrby(RedisModuleKey *key, double score, RedisModuleString *ele, int *flagsptr, double *newscore);
int RM_ZsetScore(RedisModuleKey *key, RedisModuleString *ele, double *score);
int RM_ZsetRem(RedisModuleKey *key, RedisModuleString *ele, int *deleted);
void RM_ZsetRangeStop(RedisModuleKey *key);
int RM_ZsetFirstInScoreRange(RedisModuleKey *key, double min, double max, int minex, int maxex);
int RM_ZsetLastInScoreRange(RedisModuleKey *key, double min, double max, int minex, int maxex);
int RM_ZsetFirstInLexRange(RedisModuleKey *key, RedisModuleString *min, RedisModuleString *max);
int RM_ZsetLastInLexRange(RedisModuleKey *key, RedisModuleString *min, RedisModuleString *max);
RedisModuleString *RM_ZsetRangeCurrentElement(RedisModuleKey *key, double *score);
int RM_ZsetRangeNext(RedisModuleKey *key);
int RM_ZsetRangePrev(RedisModuleKey *key);
int RM_ZsetRangeEndReached(RedisModuleKey *key);
int RM_HashSet(RedisModuleKey *key, int flags, ...);
int RM_HashGet(RedisModuleKey *key, int flags, ...);
int RM_IsKeysPositionRequest(RedisModuleCtx *ctx);
void RM_KeyAtPos(RedisModuleCtx *ctx, int pos);
unsigned long long RM_GetClientId(RedisModuleCtx *ctx);

RedisModuleCtx* RM_LJ_GetEvalContext(void);
]])

local C = ffi.C
local ffi_new = ffi.new
local RM_LJ = ffi.load('redis-mod_luajit', true)


-- RedisModule Lua API
local RM = {
    -- Error status return values.
    OK = 0,
    ERR = 1,

    -- API versions.
    APIVER_1 = 1,

    -- API flags and constants
    READ = 1,
    WRITE = 2,

    LIST_HEAD = 0,
    LIST_TAIL = 1,

    -- Key types.
    KEYTYPE_EMPTY = 0,
    KEYTYPE_STRING = 1,
    KEYTYPE_LIST = 2,
    KEYTYPE_HASH = 3,
    KEYTYPE_SET = 4,
    KEYTYPE_ZSET = 5,

    -- Reply types.
    REPLY_UNKNOWN = -1,
    REPLY_STRING = 0,
    REPLY_ERROR = 1,
    REPLY_INTEGER = 2,
    REPLY_ARRAY = 3,
    REPLY_NULL = 4,

    -- Postponed array length.
    POSTPONED_ARRAY_LEN = -1,

    -- Expire
    NO_EXPIRE = -1,

    -- Sorted set API flags.
    ZADD_XX      = 1,
    ZADD_NX      = 2,
    ZADD_ADDED   = 4,
    ZADD_UPDATED = 8,
    ZADD_NOP     = 16,

    -- Hash API flags.
    HASH_NONE       = 0,
    HASH_NX         = 2,
    HASH_XX         = 4,
    HASH_CFIELDS    = 8,
    HASH_EXISTS     = 16,

    -- A special pointer that we can use between the core and the module to signal
    -- field deletion, and that is impossible to be a valid pointer.
    HASH_DELETE = 1, -- ((RedisModuleString*)(long)1)

    -- Error messages.
    ERRORMSG_WRONGTYPE = "WRONGTYPE Operation against a key holding the wrong kind of value",

    POSITIVE_INFINITE = (1.0/0.0),
    NEGATIVE_INFINITE = (-1.0/0.0),
}


--- RedisModule Ctx class 
RM.Ctx = ffi.metatype( 'RedisModuleCtx', {
    -- methods
    __index = {
        CreateCommand = function(ctx, name, cmdfunc, strflags, firstkey, lastkey, keystep)
            return C.RM_CreateCommand(ctx, name, cmdfunc, strflags, firstkey, lastkey, keystep)
        end,
        SetModuleAttribs = function(ctx, name, ver, apiver)
            return C.RM_SetModuleAttribs(ctx, name, ver, apiver)
        end,
        WrongArity = function(ctx)
            return C.RM_WrongArity(ctx)
        end,
        ReplyWithLongLong = function(ctx, ll)
            return C.RM_ReplyWithLongLong(ctx, ll)
        end,
        GetSelectedDb = function(ctx)
            return C.RM_GetSelectedDb(ctx)
        end,
        SelectDb = function(ctx, newid)
            return C.RM_SelectDb(ctx, newid)
        end,
        ReplyWithError = function(ctx, err)
            return C.RM_ReplyWithError(ctx, err)
        end,
        ReplyWithSimpleString = function(ctx, msg)
            return C.RM_ReplyWithSimpleString(ctx, msg)
        end,
        ReplyWithArray = function(ctx, len)
            return C.RM_ReplyWithArray(ctx, len)
        end,
        ReplySetArrayLength = function(ctx, len)
            return C.RM_ReplySetArrayLength(ctx, len)
        end,
        ReplyWithStringBuffer = function(ctx, buf, len)
            -- TODO
        end,
        ReplyWithString = function(ctx, str)
            -- TODO
        end,
        ReplyWithNull = function(ctx)
            return C.RM_ReplyWithNull(ctx)
        end,
        ReplyWithDouble = function(ctx, d)
            return C.RM_ReplyWithNull(ctx, d)
        end,
        ReplyWithCallReply = function(ctx, reply)
            -- TODO
        end,
        AutoMemory = function(ctx)
            C.RM_AutoMemory(ctx)
        end,
        Replicate = function(ctx, cmdname, fmt) -- , ...)
            -- TODO
        end,
        ReplicateVerbatim = function(ctx)
            return C.RM_ReplicateVerbatim(ctx)
        end,
        IsKeysPositionRequest = function(ctx)
            return C.RM_IsKeysPositionRequest(ctx)
        end,
        KeyAtPos = function(ctx, pos)
            -- TODO
        end,
        GetClientId = function(ctx)
            return C.RM_GetClientId(ctx)
        end,
    }
})


--- RedisModule Key class 
RM.Key = ffi.metatype( 'struct RedisModuleKey', {

    -- garbage collection destructor, not invoked by user
    __gc = function(key)
        if key then
            C.RM_CloseKey(key)
        end
    end,

    -- methods
    __index = {
        KeyType = function(key)
            return C.RM_KeyType(key)
        end,
        ValueLength = function(key)
            return C.RM_ValueLength(key)
        end,
        ListPush = function(key, where, ele) -- TODO ele => string
            return C.RM_ListPush(key, where, ele)
        end,
        --RedisModuleString *RM_ListPop(key, int where);
        DeleteKey = function(key)
            return C.RM_DeleteKey(key)
        end,
        -- int RM_StringSet(key, RedisModuleString *str);
        -- char *RM_StringDMA(key, size_t *len, int mode);
        StringTruncate = function(key, newlen)
            return C.RM_StringTruncate(key, newlen)
        end,
        GetExpire = function(key)
            return C.RM_GetExpire(key)
        end,
        SetExpire = function(key, expire)
            return C.RM_SetExpire(expire)
        end,
        -- ZsetAdd = function(key, double score, RedisModuleString *ele, int *flagsptr)
        -- end,
        -- ZsetIncrby = function(key, double score, RedisModuleString *ele, int *flagsptr, double *newscore)
        -- end,
        -- ZsetScore = function(key, RedisModuleString *ele, double *score)
        -- end,
        -- ZsetRem = function(key, RedisModuleString *ele, int *deleted)
        -- end,
        ZsetRangeStop = function(key)
            return C.RM_ZsetRangeStop(key)
        end,
        ZsetFirstInScoreRange = function(key, min, max, minex, maxex)
            return C.RM_ZsetFirstInScoreRange(key, min, max, minex, maxex)
        end,
        ZsetLastInScoreRange = function(key, min, max, minex, maxex)
            return C.RM_ZsetLastInScoreRange(key, min, max, minex, maxex)
        end,
        ZsetFirstInLexRange = function(key, min, max)
            return C.RM_ZsetFirstInLexRange(key, min, max)
        end,
        ZsetLastInLexRange = function(key, min, max)
            return C.RM_ZsetLastInLexRange(key, min, max)
        end,
        -- RedisModuleString = function *RM_ZsetRangeCurrentElement(key, double *score)
        -- end,
        ZsetRangeNext = function(key)
            return C.RM_ZsetRangeNext(key)
        end,
        ZsetRangePrev = function(key)
            return C.RM_ZsetRangePrev(key)
        end,
        ZsetRangeEndReached = function(key)
            return C.RM_ZsetRangeEndReached(key)
        end,
        --HashSet = function(key, int flags, ...)
        --    return C.RM_HashSet(key)
        --end,
        --HashGet = function(key, int flags, ...)
        --    return C.RM_HashGet(key)
        --end,
    }
})


--- RedisModule String class 
RM.String = ffi.metatype( 'struct RedisModuleString', {

        --RedisModuleString *RM_CreateString(RedisModuleCtx *ctx, const char *ptr, size_t len);
        --RedisModuleString *RM_CreateStringFromLongLong(RedisModuleCtx *ctx, long long ll);
        --void RM_FreeString(RedisModuleCtx *ctx, RedisModuleString *str);
        --const char *RM_StringPtrLen(RedisModuleString *str, size_t *len);
        --const char *RM_StringPtrLen(RedisModuleString *str, size_t *len);

    --- Construct a new String object
    -- __new = function(str_ct, str_ptr)
    -- end,

    -- garbage collection destructor, not invoked by user
    -- __gc = function(str)
    --     if str then
    --         C.RM_FreeString()  -- TODO need context
    --     end
    -- end,

    -- methods
    __index = {
    --  Convert the string into a long long integer, storing it at *ll. Returns REDISMODULE_OK on success. If the string can't be parsed as a valid, strict long long (no spaces before/after), REDISMODULE_ERR is returned.
    --    ToLongLong = function(str)
    --        return C.RM_StringToLongLong()
    --    end,
    --    -- StringToDouble = function(str)
    --    -- end,
    }
})


--- RedisModule String class 
RM.CallReply = ffi.metatype( 'struct RedisModuleCallReply', {

-- const char *RM_CallReplyProto(RedisModuleCallReply *reply, size_t *len);
-- int RM_CallReplyType(RedisModuleCallReply *reply);
-- long long RM_CallReplyInteger(RedisModuleCallReply *reply);
-- RedisModuleCallReply *RM_CallReplyArrayElement(RedisModuleCallReply *reply, size_t idx);
-- const char *RM_CallReplyStringPtr(RedisModuleCallReply *reply, size_t *len);
-- RedisModuleString *RM_CreateStringFromCallReply(RedisModuleCallReply *reply);

    --- Construct a new CallReply object
    --__new = function(reply_ct, reply_ptr)
    --    -- TODO
    --end,

    -- garbage collection destructor, not invoked by user
    --__gc = function(reply)
    --    if reply then
    --        C.RM_FreeCallReply(reply)
    --    end
    --end,

    -- methods
    __index = {
--    Convert the string into a long long integer, storing it at *ll. Returns REDISMODULE_OK on success. If the string can't be parsed as a valid, strict long long (no spaces before/after), REDISMODULE_ERR is returned.
        -- ToLongLong = function(str)
        --     return C.RM_StringToLongLong()
        -- end,
        Length = function(reply)
            return C.RM_CallReplyLength(reply)
        end,
    }
})

-- Gets the current RM.Ctx
RM.EvalCtx = function()
    return RM_LJ.RM_LJ_GetEvalContext()
end


-- Return RedisModule Lua API
return RM
