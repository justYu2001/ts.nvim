local type_query = require("ts.auto-completion.type_query")

local M = {}

--- Module state
M.enabled = false
M.augroup = nil
M.source_instance = nil

--- Cached blink.cmp detection
local has_blink_cmp = nil

local function check_blink_cmp()
    if has_blink_cmp ~= nil then
        return has_blink_cmp
    end

    has_blink_cmp = pcall(require, "blink.cmp")

    return has_blink_cmp
end

---@param config table|nil Plugin configuration
function M.setup(config)
    -- Initialize cache with config
    type_query.init_cache(config and config.auto_completion or {})

    if check_blink_cmp() then
        local blink_source = require("ts.auto-completion.blink_source")

        M.source_instance = blink_source.new()
    end

    -- Create autocommand group
    if not M.augroup then
        M.augroup = vim.api.nvim_create_augroup("TsAutoCompletion", { clear = true })
    end
end

function M.enable()
    if not check_blink_cmp() then
        return
    end

    if M.enabled then
        return
    end

    M.enabled = true

    -- Set up autocommands for cache invalidation
    if M.augroup then
        -- Clear cache on buffer write
        vim.api.nvim_create_autocmd("BufWritePost", {
            group = M.augroup,
            pattern = { "*.ts", "*.tsx" },
            callback = function(args)
                type_query.clear_cache(args.buf)
            end,
        })

        -- Clear cache when LSP detaches
        vim.api.nvim_create_autocmd("LspDetach", {
            group = M.augroup,
            callback = function(args)
                type_query.clear_cache(args.buf)
            end,
        })

        vim.api.nvim_create_autocmd("CompleteDone", {
            group = M.augroup,
            pattern = { "*.ts", "*.tsx" },
            callback = function()
                local item = vim.v.completed_item

                if not item or not item.word then
                    return
                end

                vim.schedule(function()
                    local generic_snippet = require("ts.auto-completion.generic_snippet")

                    generic_snippet.handle_completion(item)
                end)
            end,
        })
    end
end

function M.disable()
    if not M.enabled then
        return
    end

    M.enabled = false

    -- Clear autocommands
    if M.augroup then
        vim.api.nvim_clear_autocmds({ group = M.augroup })
    end

    -- Clear all cache
    type_query.clear_all_cache()
end

---@return table|nil
function M.get_source()
    if not check_blink_cmp() then
        return nil
    end

    return M.source_instance
end

return M
