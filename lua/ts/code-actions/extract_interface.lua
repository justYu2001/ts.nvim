local M = {}

--- Find target class or object_type at cursor position
---@param bufnr number
---@param row number
---@param col number
---@return table|nil node
---@return string|nil node_type
local function find_target_node(bufnr, row, col)
    local parser = vim.treesitter.get_parser(bufnr, "typescript")
    if not parser then
        return nil, nil
    end

    local tree = parser:parse()[1]
    if not tree then
        return nil, nil
    end

    local node = tree:root():named_descendant_for_range(row, col, row, col)

    while node do
        local node_type = node:type()

        -- Support 1: Class declarations
        if node_type == "class_declaration" then
            return node, "class"
        end

        -- Support 2: Inline object types (but NOT in type aliases)
        if node_type == "object_type" then
            -- Check if inside type_alias_declaration - skip if so
            local parent = node:parent()
            while parent do
                if parent:type() == "type_alias_declaration" then
                    -- Skip - don't support type aliases
                    goto continue
                end
                parent = parent:parent()
            end

            return node, "object_type"
        end

        ::continue::
        node = node:parent()
    end

    return nil, nil
end

--- Get text content of a node
---@param node table
---@param bufnr number
---@return string
---@tag extract_interface.get_node_text()
local function get_node_text(node, bufnr)
    return vim.treesitter.get_node_text(node, bufnr)
end

--- Extract members from class or object_type
---@param node table
---@param node_type string
---@param bufnr number
---@return table member_list
local function extract_members(node, node_type, bufnr)
    local members = {}

    -- For classes: find class_body, filter by accessibility
    if node_type == "class" then
        local body
        for child in node:iter_children() do
            if child:type() == "class_body" then
                body = child
                break
            end
        end

        if not body then
            return members
        end

        for child in body:iter_children() do
            local child_type = child:type()

            -- Skip non-member nodes
            if child_type == "{" or child_type == "}" or child_type == "," or child_type == ";" then
                goto continue
            end

            -- Handle class member types
            if child_type == "public_field_definition" or child_type == "method_definition" then
                local skip = false

                -- Check accessibility
                local is_accessible = true
                for member_child in child:iter_children() do
                    if member_child:type() == "accessibility_modifier" then
                        local modifier = get_node_text(member_child, bufnr)
                        if modifier == "private" or modifier == "protected" then
                            is_accessible = false
                            break
                        end
                    end
                end

                if not is_accessible then
                    skip = true
                end

                -- Skip constructors
                if not skip then
                    local name_node
                    for member_child in child:iter_children() do
                        if member_child:type() == "property_identifier" then
                            name_node = member_child
                            break
                        end
                    end

                    if name_node and get_node_text(name_node, bufnr) == "constructor" then
                        skip = true
                    end
                end

                -- Check if member has explicit type annotation
                if not skip then
                    local has_type = false
                    for member_child in child:iter_children() do
                        if member_child:type() == "type_annotation" then
                            has_type = true
                            break
                        end
                    end

                    if not has_type and child_type ~= "method_definition" then
                        skip = true
                    end
                end

                if not skip then
                    table.insert(members, get_node_text(child, bufnr))
                end
            end

            ::continue::
        end
    end

    -- For object_type: extract all members directly
    if node_type == "object_type" then
        for child in node:iter_children() do
            if
                child:type() == "property_signature"
                or child:type() == "method_signature"
                or child:type() == "index_signature"
            then
                table.insert(members, get_node_text(child, bufnr))
            end
        end
    end

    return members
end

--- Extract generic type parameters from node
---@param node table
---@param bufnr number
---@return string|nil
local function extract_generics(node, bufnr)
    local type_params = node:field("type_parameters")[1]
    if type_params then
        return get_node_text(type_params, bufnr)
    end
    return nil
end

--- Detect indentation of target node
---@param node table
---@param bufnr number
---@return string
local function detect_indent(node, bufnr)
    local start_row = node:range()
    local line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]
    if line then
        local indent = line:match("^%s*")
        return indent or ""
    end
    return ""
end

--- Find containing statement for object_type node
---@param object_type_node table
---@return table|nil
local function find_containing_statement(object_type_node)
    local node = object_type_node:parent()

    while node do
        local type = node:type()

        -- Variable declaration: const/let/var p: { ... }
        if type == "lexical_declaration" or type == "variable_declaration" then
            return node
        end

        -- Type alias: type T = { ... }
        if type == "type_alias_declaration" then
            return node
        end

        -- Function declaration (param or return type)
        if type == "function_declaration" or type == "arrow_function" then
            return node
        end

        node = node:parent()
    end

    return nil
end

--- Capitalize first letter, preserving camelCase structure
---@param str string
---@return string
local function capitalize_first(str)
    if not str or str == "" then
        return str
    end
    return str:sub(1, 1):upper() .. str:sub(2)
end

--- Extract identifier from statement node
---@param statement table TreeSitter node
---@param bufnr number
---@return string|nil
local function extract_identifier_from_statement(statement, bufnr)
    local stmt_type = statement:type()

    -- Variable: const/let/var name
    if stmt_type == "lexical_declaration" or stmt_type == "variable_declaration" then
        for child in statement:iter_children() do
            if child:type() == "variable_declarator" then
                for declarator_child in child:iter_children() do
                    if declarator_child:type() == "identifier" then
                        return get_node_text(declarator_child, bufnr)
                    end
                end
            end
        end
    end

    -- Function: function name
    if stmt_type == "function_declaration" then
        local name_node = statement:field("name")[1]
        if name_node then
            return get_node_text(name_node, bufnr)
        end
    end

    -- Arrow function: traverse to variable_declarator
    if stmt_type == "arrow_function" then
        local parent = statement:parent()
        while parent do
            if parent:type() == "variable_declarator" then
                for child in parent:iter_children() do
                    if child:type() == "identifier" then
                        return get_node_text(child, bufnr)
                    end
                end
            end
            parent = parent:parent()
        end
    end

    return nil
end

--- Check if object_type is in function parameter position
---@param object_type_node table
---@return boolean
local function is_function_parameter(object_type_node)
    local node = object_type_node:parent()
    while node do
        local node_type = node:type()
        if node_type == "required_parameter" or node_type == "optional_parameter" then
            return true
        end
        -- Stop at statement boundaries
        if node_type == "lexical_declaration" or node_type == "variable_declaration" then
            return false
        end
        node = node:parent()
    end
    return false
end

--- Generate context-aware placeholder
---@param node table Target node (class or object_type)
---@param node_type string "class" or "object_type"
---@param bufnr number
---@return string
local function generate_placeholder(node, node_type, bufnr)
    -- Class: "I" prefix + class name
    if node_type == "class" then
        local name_node = node:field("name")[1]
        if name_node then
            local class_name = get_node_text(name_node, bufnr)
            if class_name and class_name ~= "" then
                return "I" .. class_name
            end
        end
    end

    -- Object type: extract from containing statement
    if node_type == "object_type" then
        local statement = find_containing_statement(node)
        if not statement then
            return "Obj"
        end

        local identifier = extract_identifier_from_statement(statement, bufnr)
        if not identifier or identifier == "" then
            return "Obj"
        end

        -- Remove leading _ or $
        local clean_name = identifier:gsub("^[_$]+", "")
        if clean_name == "" then
            return "Obj"
        end

        -- Function parameter: capitalize + "Params"
        if is_function_parameter(node) then
            return capitalize_first(clean_name) .. "Params"
        else
            -- Variable: capitalize (camelCase preserved)
            return capitalize_first(clean_name)
        end
    end

    return "Obj"
end

--- Generate interface text from members
---@param members table
---@param indent string
---@param generics string|nil
---@param placeholder string
---@return string
local function generate_interface_text(members, indent, generics, placeholder)
    local lines = {}
    local generics_str = generics or ""

    table.insert(lines, indent .. "interface " .. placeholder .. generics_str .. " {")

    for _, member in ipairs(members) do
        -- Clean up member text (remove accessibility modifiers, static keyword)
        local clean_member = member
        clean_member = clean_member:gsub("^%s*public%s+", "")
        clean_member = clean_member:gsub("^%s*static%s+", "")

        table.insert(lines, indent .. "  " .. clean_member)
    end

    table.insert(lines, indent .. "}")

    return table.concat(lines, "\n")
end

--- Trigger rename at specific position and move cursor to end after completion
---@param row number 0-indexed row
---@param col number 0-indexed column
---@param placeholder string
local function trigger_rename(row, col, placeholder)
    vim.schedule(function()
        -- Position cursor at end of placeholder
        vim.api.nvim_win_set_cursor(0, { row + 1, col + #placeholder - 1 })

        vim.schedule(function()
            local has_inc_rename = vim.fn.exists(":IncRename") > 0

            -- Move cursor to end after rename completes
            vim.api.nvim_create_autocmd("CmdlineLeave", {
                once = true,
                callback = function()
                    vim.defer_fn(function()
                        local cursor = vim.api.nvim_win_get_cursor(0)
                        local line = vim.api.nvim_get_current_line()
                        local curr_col = cursor[2]

                        -- Find identifier at current position
                        local text_from_pos = line:sub(curr_col + 1)
                        local identifier = text_from_pos:match("^[%w_$]+")

                        if identifier then
                            -- Move to end of identifier
                            local end_col = curr_col + #identifier - 1
                            vim.api.nvim_win_set_cursor(0, { cursor[1], end_col })
                        end
                    end, 200)
                end,
            })

            if has_inc_rename then
                local keys =
                    vim.api.nvim_replace_termcodes(":IncRename " .. placeholder, true, false, true)
                vim.api.nvim_feedkeys(keys, "n", false)
            else
                vim.lsp.buf.rename()
            end
        end)
    end)
end

--- Get null-ls code action source
---@param null_ls table
---@return table
---@tag extract_interface.get_source()
function M.get_source(null_ls)
    return {
        name = "ts-extract-interface",
        filetypes = { "typescript", "typescriptreact" },
        method = null_ls.methods.CODE_ACTION,
        generator = {
            fn = function(params)
                local node, node_type = find_target_node(params.bufnr, params.row - 1, params.col)

                if not node then
                    return nil
                end

                return {
                    {
                        title = "Extract interface",
                        action = function()
                            local bufnr = params.bufnr --[[@as number]]
                            local node_type_str = node_type --[[@as string]]
                            local placeholder = generate_placeholder(node, node_type_str, bufnr)

                            if node_type_str == "class" then
                                -- Existing class logic
                                local members = extract_members(node, "class", bufnr)

                                local generics = extract_generics(node, bufnr)
                                local indent = detect_indent(node, bufnr)
                                local interface_text =
                                    generate_interface_text(members, indent, generics, placeholder)

                                -- Insert before class
                                local start_row = node:range()
                                vim.api.nvim_buf_set_text(
                                    bufnr,
                                    start_row,
                                    0,
                                    start_row,
                                    0,
                                    vim.split(interface_text .. "\n\n", "\n")
                                )

                                -- Trigger rename at interface declaration
                                local rename_col = #indent + #"interface "
                                trigger_rename(start_row, rename_col, placeholder)
                            elseif node_type_str == "object_type" then
                                -- New object_type logic
                                local members = extract_members(node, "object_type", bufnr)

                                local statement = find_containing_statement(node)

                                if not statement then
                                    return
                                end

                                -- Capture object_type range BEFORE insertion
                                local obj_start_row, obj_start_col, obj_end_row, obj_end_col =
                                    node:range()

                                local indent = detect_indent(statement, bufnr)

                                local interface_text =
                                    generate_interface_text(members, indent, nil, placeholder)

                                -- Insert before containing statement
                                local stmt_row = statement:range()
                                local interface_lines = vim.split(interface_text .. "\n\n", "\n")

                                vim.api.nvim_buf_set_text(
                                    bufnr,
                                    stmt_row,
                                    0,
                                    stmt_row,
                                    0,
                                    interface_lines
                                )

                                -- When inserting N strings, we add N-1 newlines (line breaks between them)
                                local lines_added = #interface_lines - 1

                                -- Adjust object_type row numbers after insertion
                                obj_start_row = obj_start_row + lines_added
                                obj_end_row = obj_end_row + lines_added

                                -- Replace object_type with placeholder reference
                                vim.api.nvim_buf_set_text(
                                    bufnr,
                                    obj_start_row,
                                    obj_start_col,
                                    obj_end_row,
                                    obj_end_col,
                                    { placeholder }
                                )

                                -- Trigger rename at usage location
                                trigger_rename(obj_start_row, obj_start_col, placeholder)
                            end
                        end,
                    },
                }
            end,
        },
    }
end

return M
