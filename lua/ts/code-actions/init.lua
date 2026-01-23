local M = {}
local registered = false

--- Setup and register code action sources with null-ls
---@param null_ls table
---@tag code_actions.setup()
function M.setup(null_ls)
    if registered then
        return
    end
    registered = true

    local sources = M.get_sources(null_ls)
    for _, source in ipairs(sources) do
        null_ls.register(source)
    end
end

--- Get all code action sources
---@param null_ls table
---@return table
function M.get_sources(null_ls)
    return {
        require("ts.code-actions.extract_interface").get_source(null_ls),
    }
end

return M
