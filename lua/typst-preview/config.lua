---@class PreviewOpts
---@field ppi? number
---@field position? 'left' | 'right'
---@field cursor_follow? boolean

---@class StatusLineOpts
---@field enabled? boolean
---@field compile? { ok?: { icon?: string, color?: string }, ko?: { icon?: string, color?: string }}
---@field page_count? { color?: string }

---@class ConfigOpts
---@field preview? PreviewOpts
---@field statusline? StatusLineOpts
local default_opts = {
    preview = {
        ppi = 144,
        position = "right",
        cursor_follow = true,
    },
    statusline = {
        enabled = true,
        compile = {
            ok = { icon = "", color = "#b8bb26" },
            ko = { icon = "", color = "#fb4943" },
        },
        page_count = {
            color = "#d5c4e1",
        },
    },
}

local M = {
    opts = default_opts,
}

---@param opts? ConfigOpts
function M.setup(opts)
    M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})
end

---@param enabled boolean
function M.set_cursor_follow(enabled)
    M.opts.preview.cursor_follow = enabled
end

---@return boolean
function M.get_cursor_follow()
    return M.opts.preview.cursor_follow
end

return M
