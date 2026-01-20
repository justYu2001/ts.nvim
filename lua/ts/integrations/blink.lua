-- Helper to integrate ts.nvim with blink.cmp via lazy.nvim opts
local M = {}

local function add_to_sources(ft_sources)
    if not ft_sources then
        return { "lsp", "ts_utility_types", "path", "snippets", "buffer" }
    end

    -- Check if already present
    for _, src in ipairs(ft_sources) do
        if src == "ts_utility_types" then
            return ft_sources
        end
    end

    -- Add to list
    table.insert(ft_sources, "ts_utility_types")
    return ft_sources
end

--- Merge ts.nvim source into existing blink.cmp opts
--- Use this as an opts function in lazy.nvim
---@param opts table Existing blink.cmp opts
---@return table Merged opts
function M.merge_opts(opts)
    opts = opts or {}
    opts.sources = opts.sources or {}
    opts.sources.providers = opts.sources.providers or {}
    opts.sources.per_filetype = opts.sources.per_filetype or {}

    if not opts.sources.providers.ts_utility_types then
        opts.sources.providers.ts_utility_types = {
            name = "TypeScript Utility Types",
            module = "ts.auto-completion.blink_source",
            enabled = true,
        }
    end

    for _, ft in ipairs({ "typescript", "typescriptreact" }) do
        if type(opts.sources.per_filetype[ft]) == "function" then
            -- If it's already a function, wrap it
            local original_fn = opts.sources.per_filetype[ft]

            opts.sources.per_filetype[ft] = function(enabled_sources)
                enabled_sources = original_fn(enabled_sources)
                return add_to_sources(enabled_sources)
            end
        else
            -- If it's a table or nil, create a function
            local original_sources = opts.sources.per_filetype[ft]
            opts.sources.per_filetype[ft] = function(enabled_sources)
                -- Prefer original_sources if defined, otherwise use enabled_sources
                local sources = original_sources or enabled_sources

                return add_to_sources(sources)
            end
        end
    end

    return opts
end

return M
