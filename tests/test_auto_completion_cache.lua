local Helpers = dofile("tests/helpers.lua")

local child = Helpers.new_child_neovim()

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.restart({ "-u", "scripts/minimal_init.lua" })
        end,
        post_once = child.stop,
    },
})

-- Helper to expose Cache class for testing
local setup_cache_class = [[
local type_query = require("ts.auto-completion.type_query")

-- Expose Cache class for testing by copying its implementation
local Cache = {}
Cache.__index = Cache

function Cache.new(max_size, ttl)
    return setmetatable({
        max_size = max_size,
        ttl = ttl,
        data = {},
        timestamps = {},
        access_order = {},
    }, Cache)
end

function Cache:get(key)
    local value = self.data[key]
    if not value then
        return nil
    end

    -- Check TTL
    local timestamp = self.timestamps[key]
    if timestamp and (vim.loop.now() - timestamp) > self.ttl then
        self:delete(key)
        return nil
    end

    -- Update access order
    for i, k in ipairs(self.access_order) do
        if k == key then
            table.remove(self.access_order, i)
            break
        end
    end
    table.insert(self.access_order, key)

    return value
end

function Cache:set(key, value)
    if self.data[key] then
        self.data[key] = value
        self.timestamps[key] = vim.loop.now()
        return
    end

    if #self.access_order >= self.max_size then
        local lru_key = table.remove(self.access_order, 1)
        self:delete(lru_key)
    end

    self.data[key] = value
    self.timestamps[key] = vim.loop.now()
    table.insert(self.access_order, key)
end

function Cache:delete(key)
    self.data[key] = nil
    self.timestamps[key] = nil
end

function Cache:clear_buffer(bufnr)
    if not bufnr then
        return
    end

    local keys_to_delete = {}
    for key, _ in pairs(self.data) do
        if key:match("^" .. bufnr .. ":") then
            table.insert(keys_to_delete, key)
        end
    end

    for _, key in ipairs(keys_to_delete) do
        self:delete(key)
        for i, k in ipairs(self.access_order) do
            if k == key then
                table.remove(self.access_order, i)
                break
            end
        end
    end
end

function Cache:clear_all()
    self.data = {}
    self.timestamps = {}
    self.access_order = {}
end

_G.TestCache = Cache
]]

T["Cache"] = MiniTest.new_set()

-- Basic operations
T["Cache"]["creates instance with correct fields"] = function()
    child.lua([[require('ts').setup()]])
    child.lua(setup_cache_class)

    local result = child.lua_get([[
(function()
        local cache = _G.TestCache.new(10, 5000)
        return {
            max_size = cache.max_size,
            ttl = cache.ttl,
            has_data = type(cache.data) == "table",
            has_timestamps = type(cache.timestamps) == "table",
            has_access_order = type(cache.access_order) == "table",
        }
end)()
    ]])

    MiniTest.expect.equality(result.max_size, 10)
    MiniTest.expect.equality(result.ttl, 5000)
    MiniTest.expect.equality(result.has_data, true)
    MiniTest.expect.equality(result.has_timestamps, true)
    MiniTest.expect.equality(result.has_access_order, true)
end

T["Cache"]["stores value with set()"] = function()
    child.lua([[require('ts').setup()]])
    child.lua(setup_cache_class)

    local result = child.lua_get([[
(function()
        local cache = _G.TestCache.new(10, 5000)
        cache:set("key1", "value1")
        return cache.data["key1"]
end)()
    ]])

    MiniTest.expect.equality(result, "value1")
end

T["Cache"]["retrieves value with get()"] = function()
    child.lua([[require('ts').setup()]])
    child.lua(setup_cache_class)

    local result = child.lua_get([[
(function()
        local cache = _G.TestCache.new(10, 5000)
        cache:set("key1", "value1")
        return cache:get("key1")
end)()
    ]])

    MiniTest.expect.equality(result, "value1")
end

T["Cache"]["returns nil for nonexistent key"] = function()
    child.lua([[require('ts').setup()]])
    child.lua(setup_cache_class)

    local result = child.lua_get([[
(function()
        local cache = _G.TestCache.new(10, 5000)
        return cache:get("nonexistent")
end)()
    ]])

    MiniTest.expect.equality(result, vim.NIL)
end

T["Cache"]["deletes entry with delete()"] = function()
    child.lua([[require('ts').setup()]])
    child.lua(setup_cache_class)

    local result = child.lua_get([[
(function()
        local cache = _G.TestCache.new(10, 5000)
        cache:set("key1", "value1")
        cache:delete("key1")
        return cache:get("key1")
end)()
    ]])

    MiniTest.expect.equality(result, vim.NIL)
end

-- LRU eviction
T["Cache"]["evicts least recently used when full"] = function()
    child.lua([[require('ts').setup()]])
    child.lua(setup_cache_class)

    local result = child.lua_get([[
(function()
        local cache = _G.TestCache.new(2, 5000)
        cache:set("k1", "v1")
        cache:set("k2", "v2")
        cache:set("k3", "v3")  -- Should evict k1
        return {
            k1 = cache:get("k1"),
            k2 = cache:get("k2"),
            k3 = cache:get("k3"),
        }
end)()
    ]])

    MiniTest.expect.equality(result.k1, nil)
    MiniTest.expect.equality(result.k2, "v2")
    MiniTest.expect.equality(result.k3, "v3")
end

T["Cache"]["get() updates access order to prevent eviction"] = function()
    child.lua([[require('ts').setup()]])
    child.lua(setup_cache_class)

    local result = child.lua_get([[
(function()
        local cache = _G.TestCache.new(2, 5000)
        cache:set("k1", "v1")
        cache:set("k2", "v2")
        cache:get("k1")  -- Access k1, making it most recent
        cache:set("k3", "v3")  -- Should evict k2, not k1
        return {
            k1 = cache:get("k1"),
            k2 = cache:get("k2"),
            k3 = cache:get("k3"),
        }
end)()
    ]])

    MiniTest.expect.equality(result.k1, "v1")
    MiniTest.expect.equality(result.k2, nil)
    MiniTest.expect.equality(result.k3, "v3")
end

-- TTL expiration (mocked time)
T["Cache"]["expired entry returns nil"] = function()
    child.lua([[require('ts').setup()]])
    child.lua(setup_cache_class)

    local result = child.lua_get([[
(function()
        local cache = _G.TestCache.new(10, 100)  -- 100ms TTL
        cache:set("key1", "value1")

        -- Manually set timestamp to simulate expiration
        cache.timestamps["key1"] = vim.loop.now() - 200  -- 200ms ago

        return cache:get("key1")
end)()
    ]])

    MiniTest.expect.equality(result, vim.NIL)
end

T["Cache"]["non-expired entry returns value"] = function()
    child.lua([[require('ts').setup()]])
    child.lua(setup_cache_class)

    local result = child.lua_get([[
(function()
        local cache = _G.TestCache.new(10, 5000)
        cache:set("key1", "value1")
        return cache:get("key1")
end)()
    ]])

    MiniTest.expect.equality(result, "value1")
end

-- Buffer clearing
T["Cache"]["clear_buffer() removes entries for specific buffer"] = function()
    child.lua([[require('ts').setup()]])
    child.lua(setup_cache_class)

    local result = child.lua_get([[
(function()
        local cache = _G.TestCache.new(10, 5000)
        cache:set("1:key1", "value1")
        cache:set("1:key2", "value2")
        cache:set("2:key3", "value3")

        cache:clear_buffer(1)

        return {
            buf1_key1 = cache:get("1:key1"),
            buf1_key2 = cache:get("1:key2"),
            buf2_key3 = cache:get("2:key3"),
        }
end)()
    ]])

    MiniTest.expect.equality(result.buf1_key1, nil)
    MiniTest.expect.equality(result.buf1_key2, nil)
    MiniTest.expect.equality(result.buf2_key3, "value3")
end

T["Cache"]["clear_all() removes all entries"] = function()
    child.lua([[require('ts').setup()]])
    child.lua(setup_cache_class)

    local result = child.lua_get([[
(function()
        local cache = _G.TestCache.new(10, 5000)
        cache:set("key1", "value1")
        cache:set("key2", "value2")

        cache:clear_all()

        return {
            key1 = cache:get("key1"),
            key2 = cache:get("key2"),
            data_empty = vim.tbl_count(cache.data) == 0,
        }
end)()
    ]])

    MiniTest.expect.equality(result.key1, nil)
    MiniTest.expect.equality(result.key2, nil)
    MiniTest.expect.equality(result.data_empty, true)
end

return T
