-- You can use this loaded variable to enable conditional parts of your plugin.
if _G.TsLoaded then
    return
end

_G.TsLoaded = true

vim.api.nvim_create_user_command("Ts", function()
    require("ts").toggle()
end, {})
