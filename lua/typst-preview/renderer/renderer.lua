local codes = require("typst-preview.renderer.codes")
local log = require('typst-preview.logger')

local M = {}

local uv = vim.uv
if not uv then uv = vim.loop end

local is_tmux = vim.env.TMUX ~= nil

local stdout = vim.loop.new_tty(1, false)
if not stdout then
    log.error("(renderer) could not open stdout")
    return
end

---@param sequence string
---@return string
local function escape_tmux(sequence)
    return "\27Ptmux;" .. sequence:gsub("\27", "\27\27") .. "\27\\"
end

---@param data string
---@param escape? boolean
local function write(data, escape)
    if data == "" then return end

    local payload = data
    if escape and is_tmux then payload = escape_tmux(data) end
    stdout:write(payload)
end

---@param str string
local get_chunked = function(str)
    local chunks = {}
    for i = 1, #str, 4096 do
        local chunk = str:sub(i, i + 4096 - 1):gsub("%s", "")
        if #chunk > 0 then table.insert(chunks, chunk) end
    end
    return chunks
end

---@param config {}
---@param data? string
local function write_graphics(config, data)
    local control_payload = ""

    for k, v in pairs(config) do
        if v ~= nil then
            local key = codes.keys[k]
            if key then
                if type(v) == "number" then v = string.format("%d", v) end
                control_payload = control_payload .. key .. "=" .. v .. ","
            end
        end
    end
    control_payload = control_payload:sub(0, -2)

    if data then
        data = vim.base64.encode(data):gsub("%-", "/")
        local chunks = get_chunked(data)
        local m = #chunks > 1 and 1 or 0
        control_payload = control_payload .. ",m=" .. m
        for i = 1, #chunks do
            write("\27_G" .. control_payload .. ";" .. chunks[i] .. "\27\\", true)
            if i == #chunks - 1 then
                control_payload = "m=0"
            else
                control_payload = "m=1"
            end
            uv.sleep(1)
        end
    else
        write("\27_G" .. control_payload .. "\27\\", true)
    end
end

---Pure Lua UTF-8 encoder (no vim API dependency)
---@param cp number Unicode codepoint
---@return string UTF-8 byte sequence
local function utf8_char(cp)
    if cp < 0x80 then
        return string.char(cp)
    elseif cp < 0x800 then
        return string.char(0xC0 + math.floor(cp/64), 0x80 + cp%64)
    elseif cp < 0x10000 then
        return string.char(0xE0 + math.floor(cp/4096), 0x80 + math.floor(cp/64)%64, 0x80 + cp%64)
    else
        return string.char(0xF0 + math.floor(cp/262144), 0x80 + math.floor(cp/4096)%64, 0x80 + math.floor(cp/64)%64, 0x80 + cp%64)
    end
end

-- Pre-compute placeholder character and diacritics table at module load
-- Using all 297 entries from Kitty's rowcolumn-diacritics.txt
local PLACEHOLDER = utf8_char(0x10EEEE)
local DIACRITICS_CP = {
    0x0305, 0x030D, 0x030E, 0x0310, 0x0312, 0x033D, 0x033E, 0x033F,
    0x0346, 0x034A, 0x034B, 0x034C, 0x0350, 0x0351, 0x0352, 0x0357,
    0x035B, 0x0363, 0x0364, 0x0365, 0x0366, 0x0367, 0x0368, 0x0369,
    0x036A, 0x036B, 0x036C, 0x036D, 0x036E, 0x036F, 0x0483, 0x0484,
    0x0485, 0x0486, 0x0487, 0x0592, 0x0593, 0x0594, 0x0595, 0x0597,
    0x0598, 0x0599, 0x059C, 0x059D, 0x059E, 0x059F, 0x05A0, 0x05A1,
    0x05A8, 0x05A9, 0x05AB, 0x05AC, 0x05AF, 0x05C4, 0x0610, 0x0611,
    0x0612, 0x0613, 0x0614, 0x0615, 0x0616, 0x0617, 0x0657, 0x0658,
    0x0659, 0x065A, 0x065B, 0x065D, 0x065E, 0x06D6, 0x06D7, 0x06D8,
    0x06D9, 0x06DA, 0x06DB, 0x06DC, 0x06DF, 0x06E0, 0x06E1, 0x06E2,
    0x06E4, 0x06E7, 0x06E8, 0x06EB, 0x06EC, 0x0730, 0x0732, 0x0733,
    0x0735, 0x0736, 0x073A, 0x073D, 0x073F, 0x0740, 0x0741, 0x0743,
    0x0745, 0x0747, 0x0749, 0x074A, 0x07EB, 0x07EC, 0x07ED, 0x07EE,
    0x07EF, 0x07F0, 0x07F1, 0x07F3, 0x0816, 0x0817, 0x0818, 0x0819,
    0x081B, 0x081C, 0x081D, 0x081E, 0x081F, 0x0820, 0x0821, 0x0822,
    0x0823, 0x0825, 0x0826, 0x0827, 0x0829, 0x082A, 0x082B, 0x082C,
    0x082D, 0x0951, 0x0953, 0x0954, 0x0F82, 0x0F83, 0x0F86, 0x0F87,
    0x135D, 0x135E, 0x135F, 0x17DD, 0x193A, 0x1A17, 0x1A75, 0x1A76,
    0x1A77, 0x1A78, 0x1A79, 0x1A7A, 0x1A7B, 0x1A7C, 0x1B6B, 0x1B6D,
    0x1B6E, 0x1B6F, 0x1B70, 0x1B71, 0x1B72, 0x1B73, 0x1CD0, 0x1CD1,
    0x1CD2, 0x1CDA, 0x1CDB, 0x1CE0, 0x1DC0, 0x1DC1, 0x1DC3, 0x1DC4,
    0x1DC5, 0x1DC6, 0x1DC7, 0x1DC8, 0x1DC9, 0x1DCB, 0x1DCC, 0x1DD1,
    0x1DD2, 0x1DD3, 0x1DD4, 0x1DD5, 0x1DD6, 0x1DD7, 0x1DD8, 0x1DD9,
    0x1DDA, 0x1DDB, 0x1DDC, 0x1DDD, 0x1DDE, 0x1DDF, 0x1DE0, 0x1DE1,
    0x1DE2, 0x1DE3, 0x1DE4, 0x1DE5, 0x1DE6, 0x1DFE, 0x20D0, 0x20D1,
    0x20D4, 0x20D5, 0x20D6, 0x20D7, 0x20DB, 0x20DC, 0x20E1, 0x20E7,
    0x20E9, 0x20F0, 0x2CEF, 0x2CF0, 0x2CF1, 0x2DE0, 0x2DE1, 0x2DE2,
    0x2DE3, 0x2DE4, 0x2DE5, 0x2DE6, 0x2DE7, 0x2DE8, 0x2DE9, 0x2DEA,
    0x2DEB, 0x2DEC, 0x2DED, 0x2DEE, 0x2DEF, 0x2DF0, 0x2DF1, 0x2DF2,
    0x2DF3, 0x2DF4, 0x2DF5, 0x2DF6, 0x2DF7, 0x2DF8, 0x2DF9, 0x2DFA,
    0x2DFB, 0x2DFC, 0x2DFD, 0x2DFE, 0x2DFF, 0xA66F, 0xA67C, 0xA67D,
    0xA6F0, 0xA6F1, 0xA8E0, 0xA8E1, 0xA8E2, 0xA8E3, 0xA8E4, 0xA8E5,
    0xA8E6, 0xA8E7, 0xA8E8, 0xA8E9, 0xA8EA, 0xA8EB, 0xA8EC, 0xA8ED,
    0xA8EE, 0xA8EF, 0xA8F0, 0xA8F1, 0xAAB0, 0xAAB2, 0xAAB3, 0xAAB7,
    0xAAB8, 0xAABE, 0xAABF, 0xAAC1, 0xFE20, 0xFE21, 0xFE22, 0xFE23,
    0xFE24, 0xFE25, 0xFE26, 0x10A0F, 0x10A38, 0x1D185, 0x1D186, 0x1D187,
    0x1D188, 0x1D189, 0x1D1AA, 0x1D1AB, 0x1D1AC, 0x1D1AD, 0x1D242, 0x1D243,
    0x1D244,
}
local DIACRITICS = {}
for i, cp in ipairs(DIACRITICS_CP) do
    DIACRITICS[i - 1] = utf8_char(cp) -- 0-indexed
end

---Generate Unicode placeholder text for the image
---@param rows number
---@param cols number
---@return string[]
local function generate_placeholder_lines(rows, cols)
    local lines = {}

    for row = 0, rows - 1 do
        local line = ""
        local row_diacritic = DIACRITICS[row] or ""
        for col = 0, cols - 1 do
            local col_diacritic = DIACRITICS[col] or ""
            -- U+10EEEE followed by row and column diacritics
            line = line .. PLACEHOLDER .. row_diacritic .. col_diacritic
        end
        table.insert(lines, line)
    end

    return lines
end

---@param data string
---@param img_rows number
---@param img_cols number
---@return string[]
function M.render(data, img_rows, img_cols)
    -- Step 1: Transmit image data (transmit only, no display)
    write_graphics({
        action = codes.action.transmit,
        transmit_format = codes.transmit_format.png,
        transmit_medium = codes.transmit_medium.file,
        display_cursor_policy = codes.display_cursor_policy.do_not_move,
        quiet = 2,
        image_id = 1,
    }, data)

    -- Step 2: Create virtual placement with U=1
    write_graphics({
        action = codes.action.display,
        unicode_placeholder = 1,
        display_columns = img_cols,
        display_rows = img_rows,
        quiet = 2,
        image_id = 1,
    })

    -- Step 3: Return placeholder text lines
    return generate_placeholder_lines(img_rows, img_cols)
end

---@param image_id? number
function M.clear(image_id)
    if image_id then
        -- Delete both placements and image data
        write_graphics({
            action = codes.action.delete,
            display_delete = "i",
            image_id = image_id,
            quiet = 2,
        })
        return
    end

    -- Delete all placements and images
    write_graphics({
        action = codes.action.delete,
        display_delete = "a",
        quiet = 2,
    })
end

return M
