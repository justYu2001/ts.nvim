local Helpers = dofile("tests/helpers.lua")

local child = Helpers.new_child_neovim()

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.restart({ "-u", "scripts/minimal_init.lua" })
            child.lua([[require('ts').setup()]])
            -- Mock null-ls
            child.lua([[
                package.loaded['null-ls'] = {
                    methods = {
                        CODE_ACTION = 'code_action'
                    }
                }
            ]])
        end,
        post_once = child.stop,
    },
})

--- Helper to stub rename-related functions for synchronous testing
local function stub_rename()
    child.lua([[
        vim.lsp.buf.rename = function() end
        vim.schedule = function(fn) fn() end
        if vim.fn.exists(":IncRename") > 0 then
            vim.api.nvim_del_user_command("IncRename")
        end
    ]])
end

--- Helper to execute first action
local function execute_action(row, col)
    child.lua(string.format(
        [[
        local extract = require("ts.code-actions.extract_interface")
        local null_ls = require("null-ls")
        local source = extract.get_source(null_ls)
        local actions = source.generator.fn({bufnr = 0, row = %d, col = %d})
        if actions and actions[1] then
            actions[1].action()
        end
    ]],
        row,
        col
    ))
end

-- Code Action Availability
T["availability"] = MiniTest.new_set()

T["availability"]["available on class body"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "class User { id: string }" })
    child.set_cursor(1, 15)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    child.lua(
        'local extract = require("ts.code-actions.extract_interface"); local null_ls = require("null-ls"); local source = extract.get_source(null_ls); local actions = source.generator.fn({bufnr = 0, row = 1, col = 15}); if actions and #actions > 0 then _G.test_result = {count = #actions} else _G.test_result = nil end'
    )
    local result = child.lua_get("_G.test_result")
    MiniTest.expect.no_equality(result, vim.NIL)
    MiniTest.expect.equality(result.count, 1)
end

T["availability"]["not available on type alias object_type"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "type T = { id: string }" })
    child.set_cursor(1, 12)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    child.lua([[
        local extract = require("ts.code-actions.extract_interface")
        local null_ls = require("null-ls")
        local source = extract.get_source(null_ls)
        _G.test_actions = source.generator.fn({bufnr = 0, row = 1, col = 12})
    ]])
    local actions = child.lua_get("_G.test_actions")
    MiniTest.expect.equality(actions, vim.NIL)
end

T["availability"]["not available outside targets"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "const x = 5" })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])

    child.lua([[
        local extract = require("ts.code-actions.extract_interface")
        local null_ls = require("null-ls")
        local source = extract.get_source(null_ls)
        _G.test_actions = source.generator.fn({bufnr = 0, row = 1, col = 7})
    ]])
    local actions = child.lua_get("_G.test_actions")
    MiniTest.expect.equality(actions, vim.NIL)
end

-- Extract from Class
T["extract from class"] = MiniTest.new_set()

T["extract from class"]["simple class with public field"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "class User { id: string }" })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface IUser {")
    Helpers.expect.match(lines[2], "  id: string")
    Helpers.expect.match(lines[3], "}")
    Helpers.expect.match(lines[5], "class User")
end

T["extract from class"]["class with single generic"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "class Box<T> { value: T }" })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface IBox<T> {")
    Helpers.expect.match(lines[2], "  value: T")
end

T["extract from class"]["class with multiple generics"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "class Map<K, V> { key: K; value: V }" })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface IMap<K, V> {")
    Helpers.expect.match(lines[2], "  key: K")
    Helpers.expect.match(lines[3], "  value: V")
end

T["extract from class"]["class with generic constraints"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "class Wrapper<T extends Base> { item: T }" })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface IWrapper<T extends Base> {")
    Helpers.expect.match(lines[2], "  item: T")
end

T["extract from class"]["mixed accessibility only extracts public"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({
        "class User {",
        "  public id: string",
        "  private secret: string",
        "  protected internal: number",
        "}",
    })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface IUser {")
    Helpers.expect.match(lines[2], "  id: string")
    Helpers.expect.match(lines[3], "}")
    -- Verify private/protected not included (interface:3 + blank:1 + class:5 = 9 lines total)
    MiniTest.expect.equality(#lines, 9)
end

T["extract from class"]["constructor excluded"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({
        "class User {",
        "  id: string",
        "  constructor(id: string) {}",
        "}",
    })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface IUser {")
    Helpers.expect.match(lines[2], "  id: string")
    Helpers.expect.match(lines[3], "}")
    -- Constructor should not be in interface (only 3 lines for interface)
    MiniTest.expect.equality(lines[4], "")
end

T["extract from class"]["fields without type annotation excluded"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({
        "class User {",
        "  id: string",
        "  count = 0",
        "}",
    })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface IUser {")
    Helpers.expect.match(lines[2], "  id: string")
    Helpers.expect.match(lines[3], "}")
    -- Only id should be extracted (interface has 3 lines)
    MiniTest.expect.equality(lines[4], "")
end

T["extract from class"]["static members modifier removed"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({
        "class Config {",
        "  static version: string",
        "}",
    })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface IConfig {")
    Helpers.expect.match(lines[2], "  version: string")
    Helpers.expect.no_match(lines[2], "static")
end

T["extract from class"]["readonly preserved"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({
        "class User {",
        "  readonly id: string",
        "}",
    })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    Helpers.expect.match(lines[2], "readonly id: string")
end

T["extract from class"]["optional preserved"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({
        "class User {",
        "  email?: string",
        "}",
    })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    Helpers.expect.match(lines[2], "email%?:")
end

T["extract from class"]["indented class preserves indentation"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({
        "function wrapper() {",
        "  class User {",
        "    id: string",
        "  }",
        "}",
    })
    child.set_cursor(2, 9)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(2, 9)

    local lines = child.get_lines()
    Helpers.expect.match(lines[2], "^  interface IUser")
    Helpers.expect.match(lines[3], "^    id: string")
    Helpers.expect.match(lines[4], "^  }")
end

T["extract from class"]["empty class creates empty interface"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "class Empty {}" })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface IEmpty {")
    Helpers.expect.match(lines[2], "}")
end

T["extract from class"]["class with only private members creates empty interface"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({
        "class User {",
        "  private secret: string",
        "}",
    })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface IUser {")
    Helpers.expect.match(lines[2], "}")
end

-- Extract from Object Type
T["extract from object_type"] = MiniTest.new_set()

T["extract from object_type"]["simple inline type"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "const p: { id: string } = {}" })
    child.set_cursor(1, 12)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 12)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface P {")
    Helpers.expect.match(lines[2], "  id: string")
    Helpers.expect.match(lines[3], "}")
    Helpers.expect.match(lines[5], "const p: P")
end

T["extract from object_type"]["object with method signature"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "const obj: { getName(): string } = {}" })
    child.set_cursor(1, 15)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 15)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface Obj {")
    Helpers.expect.match(lines[2], "  getName%(%):")
end

T["extract from object_type"]["object with index signature"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "const map: { [key: string]: number } = {}" })
    child.set_cursor(1, 15)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 15)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface Map {")
    Helpers.expect.match(lines[2], "  %[key: string%]:")
end

T["extract from object_type"]["multiple properties"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "const p: { id: string; name: string; age: number } = {}" })
    child.set_cursor(1, 12)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 12)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface P {")
    Helpers.expect.match(lines[2], "  id: string")
    Helpers.expect.match(lines[3], "  name: string")
    Helpers.expect.match(lines[4], "  age: number")
end

T["extract from object_type"]["nested object types preserved"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "const p: { meta: { created: Date } } = {}" })
    child.set_cursor(1, 12)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 12)

    local lines = child.get_lines()
    Helpers.expect.match(lines[2], "  meta: { created: Date }")
end

T["extract from object_type"]["indented variable preserves indentation"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({
        "function wrapper() {",
        "  const p: { id: string } = {}",
        "}",
    })
    child.set_cursor(2, 14)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(2, 14)

    local lines = child.get_lines()
    Helpers.expect.match(lines[2], "^  interface P")
    Helpers.expect.match(lines[3], "^    id: string")
    Helpers.expect.match(lines[4], "^  }")
end

T["extract from object_type"]["empty object type"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "const p: {} = {}" })
    child.set_cursor(1, 10)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 10)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface P {")
    Helpers.expect.match(lines[2], "}")
end

-- Dynamic Placeholder Generation
T["dynamic placeholders"] = MiniTest.new_set()

T["dynamic placeholders"]["variable simple name"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "const place: { id: string } = {}" })
    child.set_cursor(1, 15)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 15)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface Place {")
end

T["dynamic placeholders"]["variable camelCase"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "const myConfig: { opt: boolean } = {}" })
    child.set_cursor(1, 18)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 18)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface MyConfig {")
end

T["dynamic placeholders"]["variable with let"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "let userList: { items: string[] } = {}" })
    child.set_cursor(1, 16)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 16)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface UserList {")
end

T["dynamic placeholders"]["function parameter"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "function create(opts: { name: string }) {}" })
    child.set_cursor(1, 25)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 25)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface CreateParams {")
end

T["dynamic placeholders"]["arrow function parameter"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "const handleClick = (config: { active: boolean }) => {}" })
    child.set_cursor(1, 32)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 32)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface HandleClickParams {")
end

T["dynamic placeholders"]["camelCase function parameter"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "function getUserData(params: { id: string }) {}" })
    child.set_cursor(1, 30)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 30)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface GetUserDataParams {")
end

T["dynamic placeholders"]["class simple"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "class User { id: string }" })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface IUser {")
end

T["dynamic placeholders"]["class with generic"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "class Box<T> { value: T }" })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface IBox<T> {")
end

T["dynamic placeholders"]["class camelCase"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "class MyService { data: string }" })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface IMyService {")
end

T["dynamic placeholders"]["underscore prefix removal"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "const _data: { key: string } = {}" })
    child.set_cursor(1, 15)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 15)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface Data {")
end

T["dynamic placeholders"]["dollar prefix removal"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "const $elem: { tag: string } = {}" })
    child.set_cursor(1, 15)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 15)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface Elem {")
end

T["dynamic placeholders"]["multiple prefix removal"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "const $_test: { val: number } = {}" })
    child.set_cursor(1, 16)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 16)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface Test {")
end

T["dynamic placeholders"]["fallback when empty after prefix removal"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "const _: { val: string } = {}" })
    child.set_cursor(1, 11)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 11)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface Obj {")
end

-- Interface Generation
T["interface generation"] = MiniTest.new_set()

T["interface generation"]["removes public modifier"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({
        "class User {",
        "  public id: string",
        "}",
    })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    Helpers.expect.no_match(lines[2], "public")
    Helpers.expect.match(lines[2], "  id: string")
end

T["interface generation"]["4-space indentation"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({
        "class User {",
        "    id: string",
        "}",
    })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    -- Interface members should use 2-space indent relative to interface keyword
    Helpers.expect.match(lines[2], "^  id: string")
end

T["interface generation"]["tab indentation"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({
        "function wrapper() {",
        "\tclass User {",
        "\t\tid: string",
        "\t}",
        "}",
    })
    child.set_cursor(2, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(2, 7)

    local lines = child.get_lines()
    Helpers.expect.match(lines[2], "^\tinterface IUser")
end

-- Edge Cases
T["edge cases"] = MiniTest.new_set()

T["edge cases"]["unicode identifiers"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({ "class 用户 { id: string }" })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    Helpers.expect.match(lines[1], "interface I用户 {")
    Helpers.expect.match(lines[2], "  id: string")
end

T["edge cases"]["complex nested types"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({
        "class Store {",
        "  items: Array<{ id: string; meta: Record<string, unknown> }>",
        "}",
    })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    Helpers.expect.match(lines[2], "items: Array")
    Helpers.expect.match(lines[2], "Record<string, unknown>")
end

T["edge cases"]["optional properties with methods"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({
        "class Handler {",
        "  onEvent?: (data: string) => void",
        "}",
    })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    Helpers.expect.match(lines[2], "onEvent%?:")
    Helpers.expect.match(lines[2], "%(data: string%) => void")
end

T["edge cases"]["method definition in class"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({
        "class Service {",
        "  getData(): Promise<string> {}",
        "}",
    })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    Helpers.expect.match(lines[2], "getData%(%):")
    Helpers.expect.match(lines[2], "Promise<string>")
end

T["edge cases"]["readonly and optional combined"] = function()
    child.bo.filetype = "typescript"
    child.set_lines({
        "class User {",
        "  readonly id?: string",
        "}",
    })
    child.set_cursor(1, 7)
    child.lua([[vim.treesitter.get_parser(0, 'typescript'):parse()]])
    stub_rename()

    execute_action(1, 7)

    local lines = child.get_lines()
    Helpers.expect.match(lines[2], "readonly")
    Helpers.expect.match(lines[2], "id%?:")
end

return T
