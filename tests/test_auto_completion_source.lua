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

T["source:should_show_items()"] = MiniTest.new_set()

T["source:should_show_items()"]["returns true for Omit second param"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ 'type T = Omit<User, "">' })
    child.set_cursor(1, 22)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local result = child.lua_get([[
(function()
        local source = require("ts.auto-completion.blink_source").new()
        return source:should_show_items({bufnr = 0})
end)()
    ]])

    MiniTest.expect.equality(result, true)
end

T["source:should_show_items()"]["returns true for Exclude second param"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ 'type T = Exclude<Status, "">' })
    child.set_cursor(1, 27)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local result = child.lua_get([[
(function()
        local source = require("ts.auto-completion.blink_source").new()
        return source:should_show_items({bufnr = 0})
end)()
    ]])

    MiniTest.expect.equality(result, true)
end

T["source:should_show_items()"]["returns true for Extract second param"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ 'type T = Extract<Status, "">' })
    child.set_cursor(1, 27)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local result = child.lua_get([[
(function()
        local source = require("ts.auto-completion.blink_source").new()
        return source:should_show_items({bufnr = 0})
end)()
    ]])

    MiniTest.expect.equality(result, true)
end

T["source:should_show_items()"]["returns false outside utility type"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ "type T = string" })
    child.set_cursor(1, 10)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local result = child.lua_get([[
(function()
        local source = require("ts.auto-completion.blink_source").new()
        return source:should_show_items({bufnr = 0})
end)()
    ]])

    MiniTest.expect.equality(result, false)
end

T["source:should_show_items()"]["returns false in first param"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ 'type T = Omit<User, "">' })
    child.set_cursor(1, 15)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local result = child.lua_get([[
(function()
        local source = require("ts.auto-completion.blink_source").new()
        return source:should_show_items({bufnr = 0})
end)()
    ]])

    MiniTest.expect.equality(result, false)
end

T["source:should_show_items()"]["returns false for non-TypeScript files"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "javascript"
    child.set_lines({ 'type T = Omit<User, "">' })
    child.set_cursor(1, 22)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local result = child.lua_get([[
(function()
        local source = require("ts.auto-completion.blink_source").new()
        return source:should_show_items({bufnr = 0})
end)()
    ]])

    MiniTest.expect.equality(result, false)
end

T["source:should_show_items()"]["returns false for Pick (unsupported)"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ 'type T = Pick<User, "name">' })
    child.set_cursor(1, 20)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local result = child.lua_get([[
(function()
        local source = require("ts.auto-completion.blink_source").new()
        return source:should_show_items({bufnr = 0})
end)()
    ]])

    MiniTest.expect.equality(result, false)
end

T["source:should_show_items()"]["handles errors gracefully"] = function()
    child.lua([[require('ts').setup()]])

    -- Invalid buffer
    local result = child.lua_get([[
(function()
        local source = require("ts.auto-completion.blink_source").new()
        return source:should_show_items({bufnr = 999})
end)()
    ]])

    MiniTest.expect.equality(result, false)
end

-- Note: Skipping get_completions() tests as they require LSP mocking
-- which is too complex for unit tests. These are covered by manual testing.

return T
