local M = {}

---@param generic_str string The content inside <...>
---@return number
function M.count_type_params(generic_str)
    local depth = 0
    local count = 1

    for char in generic_str:gmatch(".") do
        if char == "<" then
            depth = depth + 1
        elseif char == ">" then
            depth = depth - 1
        elseif char == "," and depth == 0 then
            count = count + 1
        end
    end

    return count
end

---@param detail string|nil The detail field from LSP completion item
---@param kind number|nil LSP CompletionItemKind
---@return boolean is_generic Whether this is a generic type
---@return number param_count Number of type parameters
function M.is_generic_type(detail, kind)
    if not detail or type(detail) ~= "string" then
        return false, 0
    end

    -- Strip markdown code fences from LSP hover responses
    -- Pattern: extract content between ```lang and ```
    local stripped = detail:match("```%w*\n(.-)```")
    if stripped then
        detail = stripped
    end

    -- Skip import contexts - LSP hover for imports contains "import" keyword
    if detail:match("%simport%s") or detail:match("^import%s") or detail:match("%simport$") then
        return false, 0
    end

    -- If kind available, filter by type-related kinds only
    if kind then
        -- LSP CompletionItemKind enum values:
        -- Class = 7, Interface = 8, Enum = 13, TypeParameter = 25
        -- Struct = 22 (for TS namespaces/modules)
        -- Reject: Function = 3, Field = 5, Variable = 6, Constant = 21
        local allowed_kinds = {
            [7] = true, -- Class
            [8] = true, -- Interface
            [13] = true, -- Enum
            [22] = true, -- Struct
            [25] = true, -- TypeParameter
        }

        if not allowed_kinds[kind] then
            return false, 0
        end
    end

    -- Exclude function type signatures: "const f: (x: T) => U"
    if detail:match(":%s*%(.*%)%s*=>") then
        return false, 0
    end

    -- Exclude variable declarations: "const arr: Array<T>"
    if detail:match("^const%s") or detail:match("^let%s") or detail:match("^var%s") then
        return false, 0
    end

    -- Fallback: exclude function/variable patterns if no kind available
    if not kind then
        -- Exclude function declarations: "function foo<T>(...)"
        if detail:match("^function%s") or detail:match("%sfunction%s") then
            return false, 0
        end

        -- Exclude method/property declarations: "(method) map<T>(...)", "(property) foo: Bar<T>"
        if
            detail:match("^%(method%)")
            or detail:match("^%(property%)")
            or detail:match("%(method%)")
            or detail:match("%(property%)")
        then
            return false, 0
        end

        -- Exclude arrow functions with generics: "const f: <T>() => T"
        if detail:match(":%s*<.*>%s*%(") or detail:match("=%s*<.*>%s*%(") then
            return false, 0
        end
    end

    -- Match patterns like "interface Array<T>", "class Promise<T>", "type Map<K, V>"
    local generic_match = detail:match("<(.*)>")

    if not generic_match then
        return false, 0
    end

    local param_count = M.count_type_params(generic_match)

    return true, param_count
end

---@param param_count number Number of type parameters
function M.insert_snippet(param_count)
    -- Check if next character is already '<', skip if exists
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_get_current_line()
    local col = cursor[2]

    if col < #line and line:sub(col + 1, col + 1) == "<" then
        return
    end

    local ok, luasnip = pcall(require, "luasnip")

    if not ok then
        return
    end

    local s = luasnip.snippet
    local t = luasnip.text_node
    local i = luasnip.insert_node

    local nodes = { t("<") }

    for idx = 1, param_count do
        table.insert(nodes, i(idx))

        if idx < param_count then
            table.insert(nodes, t(", "))
        end
    end

    table.insert(nodes, t(">"))

    local snip = s("", nodes)
    local pos = vim.api.nvim_win_get_cursor(0)
    luasnip.snip_expand(snip, { pos = { pos[1] - 1, pos[2] } })
end

---@param _word string The completed word
---@param bufnr number Buffer number
---@param callback function Callback with detail string
function M.query_lsp_hover(_word, bufnr, callback)
    local clients = vim.lsp.get_active_clients({ bufnr = bufnr })

    if #clients == 0 then
        callback(nil)
        return
    end

    local client = clients[1]
    local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
    local responded = false

    vim.defer_fn(function()
        if not responded then
            responded = true

            callback(nil)
        end
    end, 500)

    vim.lsp.buf_request(bufnr, "textDocument/hover", params, function(err, result)
        if responded or err or not result then
            return
        end

        responded = true

        -- Extract detail from hover contents
        if result.contents then
            local contents = result.contents
            local detail = nil

            if type(contents) == "string" then
                detail = contents
            elseif type(contents) == "table" then
                if contents.value then
                    detail = contents.value
                elseif contents[1] then
                    detail = type(contents[1]) == "string" and contents[1] or contents[1].value
                end
            end

            callback(detail)
        else
            callback(nil)
        end
    end)
end

---@param word string The completed word
---@return table|nil
function M.get_blink_item(word)
    local ok, blink = pcall(require, "blink.cmp")

    if not ok then
        return nil
    end

    if blink.completion and blink.completion.list and blink.completion.list.items then
        for _, item in ipairs(blink.completion.list.items) do
            if item.label == word or item.label == word:gsub("^_", "") then
                return item
            end
        end
    end

    return nil
end

--- Handle completion done event
---@param completed_item table The vim.v.completed_item
function M.handle_completion(completed_item)
    if not completed_item or not completed_item.word then
        return
    end

    local word = completed_item.word

    -- Skip primitive types that should never have generics
    local primitives = {
        string = true,
        number = true,
        boolean = true,
        null = true,
        undefined = true,
        void = true,
        any = true,
        unknown = true,
        never = true,
        object = true,
        _string = true,
        _number = true,
        _boolean = true,
    }

    if primitives[word] then
        return
    end

    -- Try to get full item from blink.cmp
    local blink_item = M.get_blink_item(word)

    -- Extract detail and kind from various sources
    local detail = nil
    local kind = nil

    -- 1. Try blink.cmp item
    if blink_item and blink_item.detail then
        detail = blink_item.detail
    end

    -- Extract kind from blink_item (LSP CompletionItemKind)
    if blink_item and blink_item.kind then
        kind = blink_item.kind
    end

    -- 2. Try user_data
    if not detail and completed_item.user_data then
        local user_data = completed_item.user_data

        if type(user_data) == "string" and user_data ~= "" then
            local ok, decoded = pcall(vim.fn.json_decode, user_data)

            if ok and decoded and decoded.nvim and decoded.nvim.lsp then
                local lsp_item = decoded.nvim.lsp.completion_item
                if lsp_item then
                    detail = lsp_item.detail
                    kind = kind or lsp_item.kind
                end
            end
        elseif type(user_data) == "table" then
            if user_data.nvim and user_data.nvim.lsp then
                local lsp_item = user_data.nvim.lsp.completion_item
                if lsp_item then
                    detail = lsp_item.detail
                    kind = kind or lsp_item.kind
                end
            end
        end
    end

    -- If no detail, try LSP hover (async)
    if not detail then
        local bufnr = vim.api.nvim_get_current_buf()

        M.query_lsp_hover(word, bufnr, function(hover_detail)
            local is_generic, param_count = M.is_generic_type(hover_detail, nil)

            if is_generic and param_count > 0 then
                M.insert_snippet(param_count)
            end
        end)
        return
    end

    -- We have detail, check if it's a generic type
    local is_generic, param_count = M.is_generic_type(detail, kind)

    if is_generic and param_count > 0 then
        M.insert_snippet(param_count)
    end
end

return M
