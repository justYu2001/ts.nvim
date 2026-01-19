local log = require("ts.util.log")

local Ts = {}

--- Ts configuration with its default values.
---
---@type table
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
Ts.options = {
    -- Prints useful logs about what event are triggered, and reasons actions are executed.
    debug = false,

    -- Auto-completion settings for TypeScript utility types
    auto_completion = {
        -- Cache time-to-live in milliseconds
        cache_ttl = 5000,

        -- Maximum number of completion items to show (for large types)
        max_items = 100,
    },
}

---@private
local defaults = vim.deepcopy(Ts.options)

--- Defaults Ts options by merging user provided options with the default plugin values.
---
---@param options table Module config table. See |Ts.options|.
---
---@private
function Ts.defaults(options)
    Ts.options = vim.deepcopy(vim.tbl_deep_extend("keep", options or {}, defaults or {}))

    -- let your user know that they provided a wrong value, this is reported when your plugin is executed.
    assert(type(Ts.options.debug) == "boolean", "`debug` must be a boolean (`true` or `false`).")

    assert(type(Ts.options.auto_completion) == "table", "`auto_completion` must be a table.")

    assert(
        type(Ts.options.auto_completion.cache_ttl) == "number",
        "`auto_completion.cache_ttl` must be a number (milliseconds)."
    )

    assert(
        type(Ts.options.auto_completion.max_items) == "number",
        "`auto_completion.max_items` must be a number."
    )

    return Ts.options
end

--- Define your ts setup.
---
---@param options table Module config table. See |Ts.options|.
---
---@usage `require("ts").setup()` (add `{}` with your |Ts.options| table)
function Ts.setup(options)
    Ts.options = Ts.defaults(options or {})

    log.warn_deprecation(Ts.options)

    return Ts.options
end

return Ts
