local main = require("ts.main")
local config = require("ts.config")

local Ts = {}

--- Toggle the plugin by calling the `enable`/`disable` methods respectively.
function Ts.toggle()
    if _G.Ts.config == nil then
        _G.Ts.config = config.options
    end

    main.toggle("public_api_toggle")
end

--- Initializes the plugin, sets event listeners and internal state.
function Ts.enable(scope)
    if _G.Ts.config == nil then
        _G.Ts.config = config.options
    end

    main.toggle(scope or "public_api_enable")
end

--- Disables the plugin, clear highlight groups and autocmds, closes side buffers and resets the internal state.
function Ts.disable()
    main.toggle("public_api_disable")
end

-- setup Ts options and merge them with user provided ones.
function Ts.setup(opts)
    _G.Ts.config = config.setup(opts)
end

_G.Ts = Ts

return _G.Ts
