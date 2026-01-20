local M = {}

--- LRU Cache implementation
---@class Cache
---@field max_size number
---@field ttl number Time-to-live in milliseconds
---@field data table
---@field timestamps table
---@field access_order table
local Cache = {}
Cache.__index = Cache

---@param max_size number
---@param ttl number
---@return Cache
function Cache.new(max_size, ttl)
    return setmetatable({
        max_size = max_size,
        ttl = ttl,
        data = {},
        timestamps = {},
        access_order = {},
    }, Cache)
end

---@param key string
---@return any|nil
function Cache:get(key)
    local value = self.data[key]
    if not value then
        return nil
    end

    -- Check TTL
    local timestamp = self.timestamps[key]
    if timestamp and (vim.loop.now() - timestamp) > self.ttl then
        -- Expired
        self:delete(key)
        return nil
    end

    -- Update access order (move to end = most recently used)
    for i, k in ipairs(self.access_order) do
        if k == key then
            table.remove(self.access_order, i)
            break
        end
    end
    table.insert(self.access_order, key)

    return value
end

---@param key string
---@param value any
function Cache:set(key, value)
    -- If key exists, update it
    if self.data[key] then
        self.data[key] = value
        self.timestamps[key] = vim.loop.now()
        return
    end

    -- Check if we need to evict
    if #self.access_order >= self.max_size then
        -- Remove least recently used (first in list)
        local lru_key = table.remove(self.access_order, 1)
        self:delete(lru_key)
    end

    -- Add new entry
    self.data[key] = value
    self.timestamps[key] = vim.loop.now()
    table.insert(self.access_order, key)
end

---@param key string
function Cache:delete(key)
    self.data[key] = nil
    self.timestamps[key] = nil
end

---@param bufnr number|nil
function Cache:clear_buffer(bufnr)
    if not bufnr then
        return
    end

    -- Clear all entries for this buffer
    local keys_to_delete = {}
    for key, _ in pairs(self.data) do
        if key:match("^" .. bufnr .. ":") then
            table.insert(keys_to_delete, key)
        end
    end

    for _, key in ipairs(keys_to_delete) do
        self:delete(key)
        -- Remove from access order
        for i, k in ipairs(self.access_order) do
            if k == key then
                table.remove(self.access_order, i)
                break
            end
        end
    end
end

function Cache:clear_all()
    self.data = {}
    self.timestamps = {}
    self.access_order = {}
end

--- Global cache instance
M.cache = nil

--- Initialize the cache
---@param config table
function M.init_cache(config)
    local max_size = 100 -- Fixed max size
    local ttl = config and config.cache_ttl or 5000
    M.cache = Cache.new(max_size, ttl)
end

--- Get LSP clients for a buffer
---@param bufnr number
---@return table
local function get_ts_lsp_clients(bufnr)
    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    local ts_clients = {}

    for _, client in ipairs(clients) do
        -- Check if it's a TypeScript LSP
        if
            client.name:match("typescript")
            or client.name:match("tsserver")
            or client.name:match("vtsls")
        then
            table.insert(ts_clients, client)
        end
    end

    return ts_clients
end

---@param hover_result table|nil
---@return string[]|nil
local function parse_union_from_hover(hover_result)
    if not hover_result or not hover_result.contents then
        return nil
    end

    local content = hover_result.contents
    local text = ""

    if type(content) == "string" then
        text = content
    elseif type(content) == "table" then
        if content.value then
            text = content.value
        elseif content.kind == "markdown" then
            text = content.value or ""
        end
    end

    -- Look for union types in the format: "type X = 'a' | 'b' | 'c'"
    -- or just "'a' | 'b' | 'c'"
    local unions = {}

    -- Try to find type definition line
    for line in text:gmatch("[^\r\n]+") do
        -- Match patterns like: type X = 'a' | 'b' | 'c'
        -- or: const x: 'a' | 'b' | 'c'
        if line:match("|") then
            -- Extract all quoted strings
            for match in line:gmatch("'([^']+)'") do
                table.insert(unions, match)
            end

            for match in line:gmatch('"([^"]+)"') do
                table.insert(unions, match)
            end

            if #unions > 0 then
                return unions
            end
        end
    end

    return nil
end

---@param symbols table|nil
---@param max_items number
---@return table[] Array of {name, type, documentation}
local function parse_properties_from_symbols(symbols, max_items)
    if not symbols then
        return {}
    end

    local properties = {}
    local count = 0

    local function extract_properties(symbol_list)
        for _, symbol in ipairs(symbol_list or {}) do
            if count >= max_items then
                break
            end

            -- Check if it's a property or field
            local kind = symbol.kind

            if
                kind == vim.lsp.protocol.SymbolKind.Property
                or kind == vim.lsp.protocol.SymbolKind.Field
                or kind == vim.lsp.protocol.SymbolKind.EnumMember
            then
                table.insert(properties, {
                    name = symbol.name,
                    type = symbol.detail or "",
                    documentation = symbol.documentation or "",
                })

                count = count + 1
            end

            -- Recursively check children
            if symbol.children then
                extract_properties(symbol.children)
            end
        end
    end

    extract_properties(symbols)

    return properties
end

---@param type_name string
---@param bufnr number
---@param callback function(string[]|nil)
function M.extract_union_members(type_name, bufnr, callback)
    if not M.cache then
        M.init_cache({})
    end

    -- Check cache
    local cache_key = bufnr .. ":union:" .. type_name
    local cached = M.cache:get(cache_key)

    if cached then
        callback(cached)
        return
    end

    local clients = get_ts_lsp_clients(bufnr)

    if #clients == 0 then
        callback(nil)
        return
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local context_module = require("ts.auto-completion.context")
    local context = context_module.get_context(bufnr)

    if not context or not context.first_param_type then
        callback(nil)
        return
    end

    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "typescript")

    if not ok or not parser then
        callback(nil)
        return
    end

    local tree = parser:parse()[1]
    local root = tree:root()

    -- Find the node at cursor position
    local node = root:named_descendant_for_range(cursor[1] - 1, cursor[2], cursor[1] - 1, cursor[2])

    if not node then
        callback(nil)
        return
    end

    -- Walk up to find generic_type node
    while node and node:type() ~= "generic_type" do
        node = node:parent()
    end

    if not node then
        callback(nil)
        return
    end

    -- Get type_arguments
    local type_args = node:field("type_arguments")[1]

    if not type_args then
        callback(nil)
        return
    end

    -- Find the first parameter node (skip < and >)
    local first_param_node = nil

    for child in type_args:iter_children() do
        if child:type() ~= "<" and child:type() ~= ">" and child:type() ~= "," then
            first_param_node = child
            break
        end
    end

    if not first_param_node then
        callback(nil)
        return
    end

    local start_row, start_col, _, _ = first_param_node:range()

    local params = {
        textDocument = vim.lsp.util.make_text_document_params(bufnr),
        position = {
            line = start_row,
            character = start_col,
        },
    }

    clients[1].request("textDocument/hover", params, function(err, result)
        if err or not result then
            callback(nil)
            return
        end

        local unions = parse_union_from_hover(result)

        if unions then
            M.cache:set(cache_key, unions)
        end

        callback(unions)
    end, bufnr)
end

--- Extract properties from an interface/type using definition + documentSymbol
---@param type_name string
---@param bufnr number
---@param callback function(table[]|nil)
---@param max_items number
function M.extract_properties(type_name, bufnr, callback, max_items)
    max_items = max_items or 100

    if not M.cache then
        M.init_cache({})
    end

    -- Check cache
    local cache_key = bufnr .. ":props:" .. type_name
    local cached = M.cache:get(cache_key)

    if cached then
        callback(cached)
        return
    end

    -- Get TypeScript LSP client
    local clients = get_ts_lsp_clients(bufnr)
    if #clients == 0 then
        callback(nil)
        return
    end

    -- Use tree-sitter to find the exact position of the first parameter (same as extract_union_members)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local context_module = require("ts.auto-completion.context")
    local context = context_module.get_context(bufnr)

    if not context or not context.first_param_type then
        callback(nil)
        return
    end

    -- Get tree-sitter parser
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "typescript")
    if not ok or not parser then
        callback(nil)
        return
    end

    local tree = parser:parse()[1]
    local root = tree:root()

    -- Find the node at cursor position
    local node = root:named_descendant_for_range(cursor[1] - 1, cursor[2], cursor[1] - 1, cursor[2])
    if not node then
        callback(nil)
        return
    end

    -- Walk up to find generic_type node
    while node and node:type() ~= "generic_type" do
        node = node:parent()
    end

    if not node then
        callback(nil)
        return
    end

    -- Get type_arguments
    local type_args = node:field("type_arguments")[1]
    if not type_args then
        callback(nil)
        return
    end

    -- Find the first parameter node (skip < and >)
    local first_param_node = nil
    for child in type_args:iter_children() do
        if child:type() ~= "<" and child:type() ~= ">" and child:type() ~= "," then
            first_param_node = child
            break
        end
    end

    if not first_param_node then
        callback(nil)
        return
    end

    -- Get the position of the first parameter
    local start_row, start_col, _, _ = first_param_node:range()

    -- Request definition
    local params = {
        textDocument = vim.lsp.util.make_text_document_params(bufnr),
        position = {
            line = start_row,
            character = start_col,
        },
    }

    clients[1].request("textDocument/definition", params, function(err, result)
        if err or not result then
            callback(nil)
            return
        end

        -- Get the location of the type definition
        local location = result[1] or result
        if not location then
            callback(nil)
            return
        end

        local uri = location.uri or location.targetUri

        -- Now request document symbols for that location
        local symbol_params = {
            textDocument = { uri = uri },
        }

        clients[1].request("textDocument/documentSymbol", symbol_params, function(err2, symbols)
            if err2 or not symbols then
                callback(nil)
                return
            end

            local properties = parse_properties_from_symbols(symbols, max_items)
            if #properties > 0 then
                M.cache:set(cache_key, properties)
            end
            callback(properties)
        end, bufnr)
    end, bufnr)
end

--- Clear cache for a specific buffer
---@param bufnr number
function M.clear_cache(bufnr)
    if M.cache then
        M.cache:clear_buffer(bufnr)
    end
end

--- Clear all cache
function M.clear_all_cache()
    if M.cache then
        M.cache:clear_all()
    end
end

return M
