local M = {}

---@class TSNode
---@field type fun(self: TSNode): string
---@field parent fun(self: TSNode): TSNode|nil
---@field child fun(self: TSNode, index: number): TSNode|nil
---@field field fun(self: TSNode, name: string): TSNode[]
---@field iter_children fun(self: TSNode): fun(): TSNode
---@field range fun(self: TSNode): number, number, number, number

M.UTILITY_TYPES = { "Omit", "Exclude", "Extract" }

---@param node TSNode
---@param bufnr number
---@return string
local function get_node_text(node, bufnr)
    if not node then
        return ""
    end

    return vim.treesitter.get_node_text(node, bufnr)
end

---@param table table
---@param value any
---@return boolean
local function has_value(table, value)
    for _, v in ipairs(table) do
        if v == value then
            return true
        end
    end

    return false
end

--- Find the generic_type node by walking up the tree
---@param node TSNode|nil
---@return TSNode|nil
local function find_generic_type_node(node)
    while node do
        if node:type() == "generic_type" then
            return node
        end

        node = node:parent()
    end

    return nil
end

---@param generic_node TSNode
---@param bufnr number
---@return string|nil
local function get_utility_type_name(generic_node, bufnr)
    -- The name is typically the first child or via 'name' field
    local name_node = generic_node:field("name")[1] or generic_node:child(0)

    if not name_node then
        return nil
    end

    local name = get_node_text(name_node, bufnr)

    return has_value(M.UTILITY_TYPES, name) and name or nil
end

---@param generic_node TSNode
---@return TSNode|nil
local function get_type_arguments(generic_node)
    local type_args = generic_node:field("type_arguments")[1]

    return type_args
end

---@param type_args_node TSNode
---@param cursor_row number (0-indexed)
---@param cursor_col number (0-indexed)
---@param bufnr number
---@return number|nil # parameter index (1 or 2)
---@return string|nil # first_param_type
local function get_parameter_info(type_args_node, cursor_row, cursor_col, bufnr)
    if not type_args_node then
        return nil, nil
    end

    -- type_arguments contains: < param1 , param2 >
    -- We need to find which parameter contains the cursor
    local param_index = 0
    local first_param_text = nil
    local last_comma_col = nil

    for child in type_args_node:iter_children() do
        local child_type = child:type()
        local start_row, start_col, end_row, end_col = child:range()

        -- Skip the < and > tokens
        if child_type ~= "<" and child_type ~= ">" then
            -- This is a parameter or a comma
            if child_type == "," then
                -- Comma separates parameters
                last_comma_col = end_col
                param_index = param_index + 1
            else
                -- This is a parameter node
                if param_index == 0 then
                    first_param_text = get_node_text(child, bufnr)
                end

                -- Check if cursor is within this parameter
                if
                    (
                        cursor_row > start_row
                        or (cursor_row == start_row and cursor_col >= start_col)
                    )
                    and (cursor_row < end_row or (cursor_row == end_row and cursor_col <= end_col))
                then
                    -- Cursor is in this parameter
                    -- param_index 0 = first param, param_index 1 = second param
                    return param_index + 1, first_param_text
                end
            end
        end
    end

    -- Special case: If we found a comma and cursor is after it, we're in the second parameter
    -- This handles cases where the second parameter node doesn't exist yet (e.g., empty string being typed)
    if last_comma_col and cursor_col > last_comma_col then
        return 2, first_param_text
    end

    return nil, first_param_text
end

--- Get the current completion context
---@param bufnr number|nil Buffer number (default: current buffer)
---@return table|nil Context information or nil if not in a valid context
---  {
---    is_utility_type: boolean,
---    utility_type_name: string|nil,
---    parameter_index: number|nil,
---    first_param_type: string|nil,
---  }
function M.get_context(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    -- Check if TypeScript parser is available
    if not pcall(vim.treesitter.get_parser, bufnr, "typescript") then
        return nil
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local cursor_row = cursor[1] - 1
    local cursor_col = cursor[2]

    local node = vim.treesitter.get_node({ bufnr = bufnr, pos = { cursor_row, cursor_col } })

    if not node then
        return nil
    end

    -- Walk up to find generic_type node
    local generic_node = find_generic_type_node(node)

    if not generic_node then
        return nil
    end

    local utility_type_name = get_utility_type_name(generic_node, bufnr)

    if not utility_type_name then
        return nil
    end

    local type_args = get_type_arguments(generic_node)

    if not type_args then
        return nil
    end

    local param_index, first_param_type =
        get_parameter_info(type_args, cursor_row, cursor_col, bufnr)

    return {
        is_utility_type = true,
        utility_type_name = utility_type_name,
        parameter_index = param_index,
        first_param_type = first_param_type,
    }
end

---@param bufnr number|nil Buffer number (default: current buffer)
---@return boolean
function M.is_in_second_param(bufnr)
    local context = M.get_context(bufnr)

    return context and context.parameter_index == 2 or false
end

---@param bufnr number|nil Buffer number (default: current buffer)
---@return string|nil
function M.get_first_param_type(bufnr)
    local context = M.get_context(bufnr)

    return context and context.first_param_type or nil
end

return M
