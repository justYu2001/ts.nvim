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

-- ============================================================================
-- Unit Tests: count_type_params()
-- ============================================================================
T["count_type_params()"] = MiniTest.new_set()

T["count_type_params()"]["counts single param"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    return gs.count_type_params("T")
end)()
    ]])

    MiniTest.expect.equality(result, 1)
end

T["count_type_params()"]["counts two params"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    return gs.count_type_params("K, V")
end)()
    ]])

    MiniTest.expect.equality(result, 2)
end

T["count_type_params()"]["counts three params"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    return gs.count_type_params("T, K, V")
end)()
    ]])

    MiniTest.expect.equality(result, 3)
end

T["count_type_params()"]["handles nested generics with depth tracking"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    return gs.count_type_params("T, Array<K>")
end)()
    ]])

    MiniTest.expect.equality(result, 2)
end

T["count_type_params()"]["handles deeply nested generics"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    return gs.count_type_params("Promise<Array<T>>")
end)()
    ]])

    MiniTest.expect.equality(result, 1)
end

T["count_type_params()"]["handles params with spaces"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    return gs.count_type_params("K , V")
end)()
    ]])

    MiniTest.expect.equality(result, 2)
end

T["count_type_params()"]["handles empty string edge case"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    return gs.count_type_params("")
end)()
    ]])

    MiniTest.expect.equality(result, 1)
end

-- ============================================================================
-- Unit Tests: is_generic_type()
-- ============================================================================
T["is_generic_type()"] = MiniTest.new_set()

T["is_generic_type()"]["detects interface Array<T>"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("interface Array<T>")
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, true)
    MiniTest.expect.equality(result.count, 1)
end

T["is_generic_type()"]["detects class Promise<T>"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("class Promise<T>")
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, true)
    MiniTest.expect.equality(result.count, 1)
end

T["is_generic_type()"]["detects interface Map<K, V>"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("interface Map<K, V>")
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, true)
    MiniTest.expect.equality(result.count, 2)
end

T["is_generic_type()"]["detects type Record<K, V>"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("type Record<K, V>")
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, true)
    MiniTest.expect.equality(result.count, 2)
end

T["is_generic_type()"]["detects type Omit<T, K>"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("type Omit<T, K>")
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, true)
    MiniTest.expect.equality(result.count, 2)
end

T["is_generic_type()"]["detects type Partial<T>"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("type Partial<T>")
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, true)
    MiniTest.expect.equality(result.count, 1)
end

T["is_generic_type()"]["returns false for non-generic type string"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("type string")
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, false)
    MiniTest.expect.equality(result.count, 0)
end

T["is_generic_type()"]["returns false for keyword type"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("keyword type")
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, false)
    MiniTest.expect.equality(result.count, 0)
end

T["is_generic_type()"]["returns false for non-generic class Date"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("class Date")
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, false)
    MiniTest.expect.equality(result.count, 0)
end

T["is_generic_type()"]["returns false for nil"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type(nil)
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, false)
    MiniTest.expect.equality(result.count, 0)
end

T["is_generic_type()"]["returns false for empty string"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("")
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, false)
    MiniTest.expect.equality(result.count, 0)
end

T["is_generic_type()"]["returns false for non-string (number)"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type(123)
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, false)
    MiniTest.expect.equality(result.count, 0)
end

T["is_generic_type()"]["returns false for import context with generics"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local detail = "(alias) interface QueryFunctionContext<TQueryKey extends QueryKey = QueryKey, TPageParam = any>\nimport QueryFunctionContext"
    local is_generic, count = gs.is_generic_type(detail)
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, false)
    MiniTest.expect.equality(result.count, 0)
end

T["is_generic_type()"]["returns false for direct import statement"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local detail = "import Array"
    local is_generic, count = gs.is_generic_type(detail)
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, false)
    MiniTest.expect.equality(result.count, 0)
end

-- ============================================================================
-- Unit Tests: is_generic_type() with kind filtering
-- ============================================================================
T["is_generic_type() with kind"] = MiniTest.new_set()

T["is_generic_type() with kind"]["accepts interface kind (8) with generics"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("interface Array<T>", 8)
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, true)
    MiniTest.expect.equality(result.count, 1)
end

T["is_generic_type() with kind"]["accepts class kind (5) with generics"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("class Promise<T>", 5)
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, true)
    MiniTest.expect.equality(result.count, 1)
end

T["is_generic_type() with kind"]["rejects function kind (3) even with generics"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("function map<T>(arr: T[]): T[]", 3)
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, false)
    MiniTest.expect.equality(result.count, 0)
end

T["is_generic_type() with kind"]["rejects variable kind (6) even with generics"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("const arr: Array<string>", 6)
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, false)
    MiniTest.expect.equality(result.count, 0)
end

T["is_generic_type() with kind"]["rejects constant kind (21) even with generics"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("const map: Map<K, V>", 21)
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, false)
    MiniTest.expect.equality(result.count, 0)
end

T["is_generic_type() with kind"]["accepts TypeParameter kind (25) with generics"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("type T<U>", 25)
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, true)
    MiniTest.expect.equality(result.count, 1)
end

T["is_generic_type() with kind"]["accepts enum kind (13) with generics"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("enum Status<T>", 13)
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, true)
    MiniTest.expect.equality(result.count, 1)
end

-- ============================================================================
-- Unit Tests: is_generic_type() fallback pattern matching
-- ============================================================================
T["is_generic_type() fallback patterns"] = MiniTest.new_set()

T["is_generic_type() fallback patterns"]["rejects function declaration without kind"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("function map<T>(arr: T[]): T[]", nil)
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, false)
    MiniTest.expect.equality(result.count, 0)
end

T["is_generic_type() fallback patterns"]["rejects method with function keyword"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("(method) map<T>(fn: T): T", nil)
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, false)
    MiniTest.expect.equality(result.count, 0)
end

T["is_generic_type() fallback patterns"]["rejects const declaration without kind"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("const arr: Array<string>", nil)
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, false)
    MiniTest.expect.equality(result.count, 0)
end

T["is_generic_type() fallback patterns"]["rejects let declaration without kind"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("let map: Map<K, V>", nil)
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, false)
    MiniTest.expect.equality(result.count, 0)
end

T["is_generic_type() fallback patterns"]["rejects arrow function type without kind"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("const f: <T>() => T", nil)
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, false)
    MiniTest.expect.equality(result.count, 0)
end

T["is_generic_type() fallback patterns"]["rejects inline generic function without kind"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("type Factory = <T>() => T", nil)
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, false)
    MiniTest.expect.equality(result.count, 0)
end

T["is_generic_type() fallback patterns"]["accepts type definition without kind"] = function()
    child.lua([[require('ts').setup()]])

    local result = child.lua_get([[
(function()
    local gs = require("ts.auto-completion.generic_snippet")
    local is_generic, count = gs.is_generic_type("type Omit<T, K>", nil)
    return {is_generic = is_generic, count = count}
end)()
    ]])

    MiniTest.expect.equality(result.is_generic, true)
    MiniTest.expect.equality(result.count, 2)
end

-- ============================================================================
-- Integration Tests: handle_completion()
-- ============================================================================
T["handle_completion()"] = MiniTest.new_set()

-- ----------------------------------------------------------------------------
-- Non-generics should NOT trigger snippet (THE FIX)
-- ----------------------------------------------------------------------------
T["handle_completion()"]["skips non-generics"] = MiniTest.new_set()

T["handle_completion()"]["skips non-generics"]["keyword 'type' with detail 'keyword type'"] = function()
    child.lua([[require('ts').setup()]])

    -- Mock insert_snippet to track calls
    child.lua([[
        _G.snippet_calls = {}
        local gs = require("ts.auto-completion.generic_snippet")
        local original = gs.insert_snippet
        gs.insert_snippet = function(param_count)
            table.insert(_G.snippet_calls, param_count)
        end
    ]])

    -- Test completion with keyword detail
    child.lua([[
        local gs = require("ts.auto-completion.generic_snippet")
        gs.handle_completion({
            word = "type",
            user_data = {
                nvim = { lsp = { completion_item = {
                    detail = "keyword type"
                }}}
            }
        })
    ]])

    local calls = child.lua_get("_G.snippet_calls")
    MiniTest.expect.equality(#calls, 0)
end

T["handle_completion()"]["skips non-generics"]["keyword 'package' with detail 'keyword package'"] = function()
    child.lua([[require('ts').setup()]])

    child.lua([[
        _G.snippet_calls = {}
        local gs = require("ts.auto-completion.generic_snippet")
        local original = gs.insert_snippet
        gs.insert_snippet = function(param_count)
            table.insert(_G.snippet_calls, param_count)
        end
    ]])

    child.lua([[
        local gs = require("ts.auto-completion.generic_snippet")
        gs.handle_completion({
            word = "package",
            user_data = {
                nvim = { lsp = { completion_item = {
                    detail = "keyword package"
                }}}
            }
        })
    ]])

    local calls = child.lua_get("_G.snippet_calls")
    MiniTest.expect.equality(#calls, 0)
end

T["handle_completion()"]["skips non-generics"]["type 'Status' with detail 'type Status' (no generics)"] = function()
    child.lua([[require('ts').setup()]])

    child.lua([[
        _G.snippet_calls = {}
        local gs = require("ts.auto-completion.generic_snippet")
        local original = gs.insert_snippet
        gs.insert_snippet = function(param_count)
            table.insert(_G.snippet_calls, param_count)
        end
    ]])

    child.lua([[
        local gs = require("ts.auto-completion.generic_snippet")
        gs.handle_completion({
            word = "Status",
            user_data = {
                nvim = { lsp = { completion_item = {
                    detail = "type Status"
                }}}
            }
        })
    ]])

    local calls = child.lua_get("_G.snippet_calls")
    MiniTest.expect.equality(#calls, 0)
end

T["handle_completion()"]["skips non-generics"]["primitive type 'string' (existing filter)"] = function()
    child.lua([[require('ts').setup()]])

    child.lua([[
        _G.snippet_calls = {}
        local gs = require("ts.auto-completion.generic_snippet")
        local original = gs.insert_snippet
        gs.insert_snippet = function(param_count)
            table.insert(_G.snippet_calls, param_count)
        end
    ]])

    child.lua([[
        local gs = require("ts.auto-completion.generic_snippet")
        gs.handle_completion({
            word = "string",
            user_data = {
                nvim = { lsp = { completion_item = {
                    detail = "type string"
                }}}
            }
        })
    ]])

    local calls = child.lua_get("_G.snippet_calls")
    MiniTest.expect.equality(#calls, 0)
end

T["handle_completion()"]["skips non-generics"]["import context with generic type (THE FIX)"] = function()
    child.lua([[require('ts').setup()]])

    child.lua([[
        _G.snippet_calls = {}
        local gs = require("ts.auto-completion.generic_snippet")
        local original = gs.insert_snippet
        gs.insert_snippet = function(param_count)
            table.insert(_G.snippet_calls, param_count)
        end
    ]])

    -- Simulate LSP hover for import completion
    child.lua([[
        local gs = require("ts.auto-completion.generic_snippet")

        -- Mock query_lsp_hover to return import context detail
        local original_query = gs.query_lsp_hover
        gs.query_lsp_hover = function(word, bufnr, callback)
            local detail = "(alias) interface QueryFunctionContext<TQueryKey extends QueryKey = QueryKey, TPageParam = any>\nimport QueryFunctionContext"
            callback(detail)
        end

        gs.handle_completion({
            word = "QueryFunctionContext",
            user_data = {}
        })
    ]])

    -- Give async call time to complete
    vim.loop.sleep(100)

    local calls = child.lua_get("_G.snippet_calls")
    MiniTest.expect.equality(#calls, 0)
end

-- ----------------------------------------------------------------------------
-- Generics SHOULD trigger snippet
-- ----------------------------------------------------------------------------
T["handle_completion()"]["inserts for generics"] = MiniTest.new_set()

T["handle_completion()"]["inserts for generics"]["Array with detail 'interface Array<T>'"] = function()
    child.lua([[require('ts').setup()]])

    child.lua([[
        _G.snippet_calls = {}
        local gs = require("ts.auto-completion.generic_snippet")
        local original = gs.insert_snippet
        gs.insert_snippet = function(param_count)
            table.insert(_G.snippet_calls, param_count)
        end
    ]])

    child.lua([[
        local gs = require("ts.auto-completion.generic_snippet")
        gs.handle_completion({
            word = "Array",
            user_data = {
                nvim = { lsp = { completion_item = {
                    detail = "interface Array<T>"
                }}}
            }
        })
    ]])

    local calls = child.lua_get("_G.snippet_calls")
    MiniTest.expect.equality(#calls, 1)
    MiniTest.expect.equality(calls[1], 1)
end

T["handle_completion()"]["inserts for generics"]["Promise with detail 'class Promise<T>'"] = function()
    child.lua([[require('ts').setup()]])

    child.lua([[
        _G.snippet_calls = {}
        local gs = require("ts.auto-completion.generic_snippet")
        local original = gs.insert_snippet
        gs.insert_snippet = function(param_count)
            table.insert(_G.snippet_calls, param_count)
        end
    ]])

    child.lua([[
        local gs = require("ts.auto-completion.generic_snippet")
        gs.handle_completion({
            word = "Promise",
            user_data = {
                nvim = { lsp = { completion_item = {
                    detail = "class Promise<T>"
                }}}
            }
        })
    ]])

    local calls = child.lua_get("_G.snippet_calls")
    MiniTest.expect.equality(#calls, 1)
    MiniTest.expect.equality(calls[1], 1)
end

T["handle_completion()"]["inserts for generics"]["Map with detail 'interface Map<K, V>'"] = function()
    child.lua([[require('ts').setup()]])

    child.lua([[
        _G.snippet_calls = {}
        local gs = require("ts.auto-completion.generic_snippet")
        local original = gs.insert_snippet
        gs.insert_snippet = function(param_count)
            table.insert(_G.snippet_calls, param_count)
        end
    ]])

    child.lua([[
        local gs = require("ts.auto-completion.generic_snippet")
        gs.handle_completion({
            word = "Map",
            user_data = {
                nvim = { lsp = { completion_item = {
                    detail = "interface Map<K, V>"
                }}}
            }
        })
    ]])

    local calls = child.lua_get("_G.snippet_calls")
    MiniTest.expect.equality(#calls, 1)
    MiniTest.expect.equality(calls[1], 2)
end

T["handle_completion()"]["inserts for generics"]["Record with detail 'type Record<K, V>'"] = function()
    child.lua([[require('ts').setup()]])

    child.lua([[
        _G.snippet_calls = {}
        local gs = require("ts.auto-completion.generic_snippet")
        local original = gs.insert_snippet
        gs.insert_snippet = function(param_count)
            table.insert(_G.snippet_calls, param_count)
        end
    ]])

    child.lua([[
        local gs = require("ts.auto-completion.generic_snippet")
        gs.handle_completion({
            word = "Record",
            user_data = {
                nvim = { lsp = { completion_item = {
                    detail = "type Record<K, V>"
                }}}
            }
        })
    ]])

    local calls = child.lua_get("_G.snippet_calls")
    MiniTest.expect.equality(#calls, 1)
    MiniTest.expect.equality(calls[1], 2)
end

T["handle_completion()"]["inserts for generics"]["Omit with detail 'type Omit<T, K>'"] = function()
    child.lua([[require('ts').setup()]])

    child.lua([[
        _G.snippet_calls = {}
        local gs = require("ts.auto-completion.generic_snippet")
        local original = gs.insert_snippet
        gs.insert_snippet = function(param_count)
            table.insert(_G.snippet_calls, param_count)
        end
    ]])

    child.lua([[
        local gs = require("ts.auto-completion.generic_snippet")
        gs.handle_completion({
            word = "Omit",
            user_data = {
                nvim = { lsp = { completion_item = {
                    detail = "type Omit<T, K>"
                }}}
            }
        })
    ]])

    local calls = child.lua_get("_G.snippet_calls")
    MiniTest.expect.equality(#calls, 1)
    MiniTest.expect.equality(calls[1], 2)
end

-- ----------------------------------------------------------------------------
-- Edge Cases
-- ----------------------------------------------------------------------------
T["handle_completion()"]["edge cases"] = MiniTest.new_set()

T["handle_completion()"]["edge cases"]["skips when completed_item is nil"] = function()
    child.lua([[require('ts').setup()]])

    child.lua([[
        _G.snippet_calls = {}
        local gs = require("ts.auto-completion.generic_snippet")
        local original = gs.insert_snippet
        gs.insert_snippet = function(param_count)
            table.insert(_G.snippet_calls, param_count)
        end
    ]])

    child.lua([[
        local gs = require("ts.auto-completion.generic_snippet")
        gs.handle_completion(nil)
    ]])

    local calls = child.lua_get("_G.snippet_calls")
    MiniTest.expect.equality(#calls, 0)
end

T["handle_completion()"]["edge cases"]["skips when completed_item has no word"] = function()
    child.lua([[require('ts').setup()]])

    child.lua([[
        _G.snippet_calls = {}
        local gs = require("ts.auto-completion.generic_snippet")
        local original = gs.insert_snippet
        gs.insert_snippet = function(param_count)
            table.insert(_G.snippet_calls, param_count)
        end
    ]])

    child.lua([[
        local gs = require("ts.auto-completion.generic_snippet")
        gs.handle_completion({})
    ]])

    local calls = child.lua_get("_G.snippet_calls")
    MiniTest.expect.equality(#calls, 0)
end

T["handle_completion()"]["edge cases"]["skips when detail is nil (THE FIX)"] = function()
    child.lua([[require('ts').setup()]])

    child.lua([[
        _G.snippet_calls = {}
        local gs = require("ts.auto-completion.generic_snippet")
        local original = gs.insert_snippet
        gs.insert_snippet = function(param_count)
            table.insert(_G.snippet_calls, param_count)
        end
    ]])

    child.lua([[
        local gs = require("ts.auto-completion.generic_snippet")
        gs.handle_completion({
            word = "SomeType",
            user_data = {
                nvim = { lsp = { completion_item = {
                    -- No detail field
                }}}
            }
        })
    ]])

    -- Note: This will trigger LSP hover async call, but for this test
    -- we're just verifying the synchronous path doesn't call insert_snippet
    -- The async path is tested separately
    vim.wait(100) -- Give async call time if it happens

    local calls = child.lua_get("_G.snippet_calls")
    MiniTest.expect.equality(#calls, 0)
end

T["handle_completion()"]["edge cases"]["skips when detail is empty string (THE FIX)"] = function()
    child.lua([[require('ts').setup()]])

    child.lua([[
        _G.snippet_calls = {}
        local gs = require("ts.auto-completion.generic_snippet")
        local original = gs.insert_snippet
        gs.insert_snippet = function(param_count)
            table.insert(_G.snippet_calls, param_count)
        end
    ]])

    child.lua([[
        local gs = require("ts.auto-completion.generic_snippet")
        gs.handle_completion({
            word = "SomeType",
            user_data = {
                nvim = { lsp = { completion_item = {
                    detail = ""
                }}}
            }
        })
    ]])

    -- Give async call time if it happens
    vim.wait(100)

    local calls = child.lua_get("_G.snippet_calls")
    MiniTest.expect.equality(#calls, 0)
end

-- ----------------------------------------------------------------------------
-- Kind-based filtering integration tests
-- ----------------------------------------------------------------------------
T["handle_completion()"]["kind filtering"] = MiniTest.new_set()

T["handle_completion()"]["kind filtering"]["accepts interface kind with generic detail"] = function()
    child.lua([[require('ts').setup()]])

    child.lua([[
        _G.snippet_calls = {}
        local gs = require("ts.auto-completion.generic_snippet")
        local original = gs.insert_snippet
        gs.insert_snippet = function(param_count)
            table.insert(_G.snippet_calls, param_count)
        end
    ]])

    child.lua([[
        local gs = require("ts.auto-completion.generic_snippet")
        gs.handle_completion({
            word = "Array",
            user_data = {
                nvim = { lsp = { completion_item = {
                    detail = "interface Array<T>",
                    kind = 8
                }}}
            }
        })
    ]])

    local calls = child.lua_get("_G.snippet_calls")
    MiniTest.expect.equality(#calls, 1)
    MiniTest.expect.equality(calls[1], 1)
end

T["handle_completion()"]["kind filtering"]["rejects function kind even with generic detail"] = function()
    child.lua([[require('ts').setup()]])

    child.lua([[
        _G.snippet_calls = {}
        local gs = require("ts.auto-completion.generic_snippet")
        local original = gs.insert_snippet
        gs.insert_snippet = function(param_count)
            table.insert(_G.snippet_calls, param_count)
        end
    ]])

    child.lua([[
        local gs = require("ts.auto-completion.generic_snippet")
        gs.handle_completion({
            word = "map",
            user_data = {
                nvim = { lsp = { completion_item = {
                    detail = "function map<T>(arr: T[]): T[]",
                    kind = 3
                }}}
            }
        })
    ]])

    local calls = child.lua_get("_G.snippet_calls")
    MiniTest.expect.equality(#calls, 0)
end

T["handle_completion()"]["kind filtering"]["rejects variable kind even with generic detail"] = function()
    child.lua([[require('ts').setup()]])

    child.lua([[
        _G.snippet_calls = {}
        local gs = require("ts.auto-completion.generic_snippet")
        local original = gs.insert_snippet
        gs.insert_snippet = function(param_count)
            table.insert(_G.snippet_calls, param_count)
        end
    ]])

    child.lua([[
        local gs = require("ts.auto-completion.generic_snippet")
        gs.handle_completion({
            word = "arr",
            user_data = {
                nvim = { lsp = { completion_item = {
                    detail = "const arr: Array<string>",
                    kind = 6
                }}}
            }
        })
    ]])

    local calls = child.lua_get("_G.snippet_calls")
    MiniTest.expect.equality(#calls, 0)
end

T["handle_completion()"]["kind filtering"]["uses fallback pattern when no kind available"] = function()
    child.lua([[require('ts').setup()]])

    child.lua([[
        _G.snippet_calls = {}
        local gs = require("ts.auto-completion.generic_snippet")
        local original = gs.insert_snippet
        gs.insert_snippet = function(param_count)
            table.insert(_G.snippet_calls, param_count)
        end
    ]])

    child.lua([[
        local gs = require("ts.auto-completion.generic_snippet")
        gs.handle_completion({
            word = "map",
            user_data = {
                nvim = { lsp = { completion_item = {
                    detail = "function map<T>(arr: T[]): T[]"
                    -- No kind field
                }}}
            }
        })
    ]])

    local calls = child.lua_get("_G.snippet_calls")
    MiniTest.expect.equality(#calls, 0)
end

return T
