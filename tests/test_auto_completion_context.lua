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

T["get_context()"] = MiniTest.new_set()

-- Omit tests
T["get_context()"]["detects Omit second parameter"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ 'type T = Omit<User, "">' })
    child.set_cursor(1, 22)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local ctx = child.lua_get("require('ts.auto-completion.context').get_context(0)")

    MiniTest.expect.no_equality(ctx, vim.NIL)
    MiniTest.expect.equality(ctx.parameter_index, 2)
    MiniTest.expect.equality(ctx.utility_type_name, "Omit")
    MiniTest.expect.equality(ctx.first_param_type, "User")
    MiniTest.expect.equality(ctx.is_utility_type, true)
end

T["get_context()"]["detects Omit first parameter"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ "type T = Omit<User, ''>" })
    child.set_cursor(1, 15)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local ctx = child.lua_get("require('ts.auto-completion.context').get_context(0)")

    MiniTest.expect.no_equality(ctx, vim.NIL)
    MiniTest.expect.equality(ctx.parameter_index, 1)
    MiniTest.expect.equality(ctx.utility_type_name, "Omit")
end

T["get_context()"]["detects Omit empty second param after comma"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ "type T = Omit<User, >" })
    child.set_cursor(1, 22)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local ctx = child.lua_get("require('ts.auto-completion.context').get_context(0)")

    MiniTest.expect.no_equality(ctx, vim.NIL)
    MiniTest.expect.equality(ctx.parameter_index, 2)
    MiniTest.expect.equality(ctx.utility_type_name, "Omit")
    MiniTest.expect.equality(ctx.first_param_type, "User")
end

-- Exclude tests
T["get_context()"]["detects Exclude second parameter"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ 'type T = Exclude<Status, "">' })
    child.set_cursor(1, 27)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local ctx = child.lua_get("require('ts.auto-completion.context').get_context(0)")

    MiniTest.expect.no_equality(ctx, vim.NIL)
    MiniTest.expect.equality(ctx.parameter_index, 2)
    MiniTest.expect.equality(ctx.utility_type_name, "Exclude")
    MiniTest.expect.equality(ctx.first_param_type, "Status")
end

T["get_context()"]["detects Exclude first parameter"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ "type T = Exclude<Status, ''>" })
    child.set_cursor(1, 18)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local ctx = child.lua_get("require('ts.auto-completion.context').get_context(0)")

    MiniTest.expect.no_equality(ctx, vim.NIL)
    MiniTest.expect.equality(ctx.parameter_index, 1)
    MiniTest.expect.equality(ctx.utility_type_name, "Exclude")
end

-- Extract tests
T["get_context()"]["detects Extract second parameter"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ 'type T = Extract<Status, "">' })
    child.set_cursor(1, 27)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local ctx = child.lua_get("require('ts.auto-completion.context').get_context(0)")

    MiniTest.expect.no_equality(ctx, vim.NIL)
    MiniTest.expect.equality(ctx.parameter_index, 2)
    MiniTest.expect.equality(ctx.utility_type_name, "Extract")
    MiniTest.expect.equality(ctx.first_param_type, "Status")
end

T["get_context()"]["detects Extract first parameter"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ "type T = Extract<Status, ''>" })
    child.set_cursor(1, 18)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local ctx = child.lua_get("require('ts.auto-completion.context').get_context(0)")

    MiniTest.expect.no_equality(ctx, vim.NIL)
    MiniTest.expect.equality(ctx.parameter_index, 1)
    MiniTest.expect.equality(ctx.utility_type_name, "Extract")
end

-- Negative cases
T["get_context()"]["returns nil outside utility type"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ "type T = string" })
    child.set_cursor(1, 10)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local ctx = child.lua_get("require('ts.auto-completion.context').get_context(0)")

    MiniTest.expect.equality(ctx, vim.NIL)
end

T["get_context()"]["returns nil for unsupported utility type Pick"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ 'type T = Pick<User, "name">' })
    child.set_cursor(1, 20)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local ctx = child.lua_get("require('ts.auto-completion.context').get_context(0)")

    MiniTest.expect.equality(ctx, vim.NIL)
end

T["get_context()"]["returns nil for unsupported utility type Record"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ "type T = Record<string, number>" })
    child.set_cursor(1, 20)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local ctx = child.lua_get("require('ts.auto-completion.context').get_context(0)")

    MiniTest.expect.equality(ctx, vim.NIL)
end

T["get_context()"]["returns nil before opening bracket"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ 'type T = Omit<User, "">' })
    child.set_cursor(1, 8) -- Position 8 is before "Omit" starts
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local ctx = child.lua_get("require('ts.auto-completion.context').get_context(0)")

    MiniTest.expect.equality(ctx, vim.NIL)
end

T["get_context()"]["returns nil after closing bracket"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ 'type T = Omit<User, "">  ' }) -- Added spaces after >
    child.set_cursor(1, 24) -- Position 24 is after >
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local ctx = child.lua_get("require('ts.auto-completion.context').get_context(0)")

    MiniTest.expect.equality(ctx, vim.NIL)
end

-- Helper function tests
T["is_in_second_param()"] = MiniTest.new_set()

T["is_in_second_param()"]["returns true for second parameter"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ 'type T = Omit<User, "">' })
    child.set_cursor(1, 22)

    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local result = child.lua_get("require('ts.auto-completion.context').is_in_second_param(0)")

    MiniTest.expect.equality(result, true)
end

T["is_in_second_param()"]["returns false for first parameter"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ 'type T = Omit<User, "">' })
    child.set_cursor(1, 15)

    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local result = child.lua_get("require('ts.auto-completion.context').is_in_second_param(0)")

    MiniTest.expect.equality(result, false)
end

T["is_in_second_param()"]["returns false outside utility type"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ "type T = string" })
    child.set_cursor(1, 10)

    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local result = child.lua_get("require('ts.auto-completion.context').is_in_second_param(0)")

    MiniTest.expect.equality(result, false)
end

T["get_first_param_type()"] = MiniTest.new_set()

T["get_first_param_type()"]["returns type name from Omit"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ 'type T = Omit<User, "">' })
    child.set_cursor(1, 22)

    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local result = child.lua_get("require('ts.auto-completion.context').get_first_param_type(0)")

    MiniTest.expect.equality(result, "User")
end

T["get_first_param_type()"]["returns type name from Exclude"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ 'type T = Exclude<Status, "">' })
    child.set_cursor(1, 27)

    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local result = child.lua_get("require('ts.auto-completion.context').get_first_param_type(0)")

    MiniTest.expect.equality(result, "Status")
end

T["get_first_param_type()"]["returns nil outside utility type"] = function()
    child.lua([[require('ts').setup()]])
    child.bo.filetype = "typescript"
    child.set_lines({ "type T = string" })
    child.set_cursor(1, 10)

    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    local result = child.lua_get("require('ts.auto-completion.context').get_first_param_type(0)")

    MiniTest.expect.equality(result, vim.NIL)
end

return T
