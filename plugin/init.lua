vim.api.nvim_create_user_command("TypstPreviewStart", function()
    require("typst-preview").start()
end, {})

vim.api.nvim_create_user_command("TypstPreviewStop", function()
    require("typst-preview").stop()
end, {})

vim.api.nvim_create_user_command("TypstPreviewLogs", function()
    require('typst-preview.logger').show_logs()
end, {})

vim.api.nvim_create_user_command("TypstPreviewGoTo", function(opts)
    local n = tonumber(opts.args)
    if n then require("typst-preview").goto_page(n) end
end, { nargs = 1 })

vim.api.nvim_create_user_command("TypstPreviewFollowCursor", function()
    require("typst-preview").set_cursor_follow(true)
end, {})

vim.api.nvim_create_user_command("TypstPreviewNoFollowCursor", function()
    require("typst-preview").set_cursor_follow(false)
end, {})

vim.api.nvim_create_user_command("TypstPreviewFollowCursorToggle", function()
    local tp = require("typst-preview")
    tp.set_cursor_follow(not tp.get_cursor_follow())
end, {})

vim.api.nvim_create_user_command("TypstPreviewSyncCursor", function()
    require("typst-preview").sync_with_cursor()
end, {})
