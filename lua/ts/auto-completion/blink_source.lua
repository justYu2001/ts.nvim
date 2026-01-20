local context = require("ts.auto-completion.context")
local type_query = require("ts.auto-completion.type_query")

local M = {}

--- Create a new blink.cmp source instance
---@return table Source instance
function M.new()
    local source = {}

    --- Get trigger characters that should show completions
    ---@return string[]
    function source.get_trigger_characters(_self)
        return { "'", '"' }
    end

    --- Check if the source should show items in this context
    ---@param ctx table blink.cmp context
    ---@return boolean
    function source.should_show_items(_self, ctx)
        -- Wrap in pcall to prevent crashes
        local ok, result = pcall(function()
            -- Only show for TypeScript files
            local ft = vim.api.nvim_buf_get_option(ctx.bufnr or 0, "filetype")

            if ft ~= "typescript" and ft ~= "typescriptreact" then
                return false
            end

            -- Check if we're in a valid context
            local completion_context = context.get_context(ctx.bufnr)

            if not completion_context then
                return false
            end

            -- Only show if in second parameter
            return completion_context.parameter_index == 2
        end)

        return ok and result or false
    end

    --- Get completions for the current context
    ---@param ctx table blink.cmp context
    ---@param cb function Callback to call with completion items
    function source.get_completions(_self, ctx, cb)
        -- Wrap in pcall to prevent crashes
        local ok = pcall(function()
            local bufnr = ctx.bufnr or vim.api.nvim_get_current_buf()

            local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")

            if ft ~= "typescript" and ft ~= "typescriptreact" then
                cb({ items = {} })
                return
            end

            -- Get context
            local completion_context = context.get_context(bufnr)
            if
                not completion_context
                or not completion_context.is_utility_type
                or completion_context.parameter_index ~= 2
            then
                cb({ items = {} })
                return
            end

            local utility_type = completion_context.utility_type_name
            local first_param = completion_context.first_param_type

            if not first_param then
                cb({ items = {} })
                return
            end

            -- Get config for max_items
            local max_items = 100

            if _G.Ts and _G.Ts.config and _G.Ts.config.auto_completion then
                max_items = _G.Ts.config.auto_completion.max_items or 100
            end

            -- For Omit: extract properties
            if utility_type == "Omit" then
                type_query.extract_properties(first_param, bufnr, function(properties)
                    if not properties or #properties == 0 then
                        cb({ items = {} })
                        return
                    end

                    local items = {}

                    for _, prop in ipairs(properties) do
                        table.insert(items, {
                            label = prop.name,
                            kind = vim.lsp.protocol.CompletionItemKind.Property,
                            detail = prop.type,
                            documentation = prop.documentation,
                            insertText = prop.name,
                        })
                    end

                    cb({ items = items })
                end, max_items)
                return
            end

            -- For Exclude/Extract: extract union members
            if utility_type == "Exclude" or utility_type == "Extract" then
                type_query.extract_union_members(first_param, bufnr, function(members)
                    if not members or #members == 0 then
                        cb({ items = {} })

                        return
                    end

                    local items = {}

                    for _, member in ipairs(members) do
                        table.insert(items, {
                            label = member,
                            kind = vim.lsp.protocol.CompletionItemKind.EnumMember,
                            detail = "union member",
                            insertText = member,
                        })
                    end

                    cb({ items = items })
                end)

                return
            end

            -- Fallback: no items
            cb({ items = {} })
        end)

        if not ok then
            cb({ items = {} })
        end
    end

    --- Resolve additional information for a completion item (optional)
    ---@param item table Completion item
    ---@param callback function Callback to call with resolved item
    function source.resolve(_self, item, callback)
        -- No additional resolution needed for now
        callback(item)
    end

    return source
end

return M
