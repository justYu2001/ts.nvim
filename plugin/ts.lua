-- You can use this loaded variable to enable conditional parts of your plugin.
if _G.TsLoaded then
    return
end

_G.TsLoaded = true

if vim.fn.has("nvim-0.11.5") == 0 then
    vim.notify("ts.nvim requires Neovim >= 0.11.5", vim.log.levels.ERROR)
    return
end

if not _G.Ts or not _G.Ts.config then
    require("ts").setup()
end

vim.api.nvim_create_autocmd("FileType", {
    pattern = { "typescript", "typescriptreact" },
    once = true,
    callback = function()
        require("ts").enable()
    end,
})

vim.api.nvim_create_user_command("Ts", function()
    require("ts").toggle()
end, {})
