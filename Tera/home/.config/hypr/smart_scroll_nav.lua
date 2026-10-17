-- Keyboard and pointer navigation for Hyprland's scrolling layout.
--
-- Hyprland can either centre every focused column or move the viewport only
-- enough to reveal it. This keeps centred navigation unless doing so would
-- expose empty space before column zero; in that case, the tape is aligned
-- with the left edge of the usable monitor area.

local M = {}
local FOCUS_REASON_CLICK = 5

local function scrolling_column_index()
    local window = hl.get_active_window()
    local layout = window and window.layout

    if not layout or layout.name ~= "scrolling" or not layout.column then
        return nil
    end

    return layout.column.index
end

local function align_focused_column()
    local column_index = scrolling_column_index()

    if column_index == nil then
        return
    end

    if column_index ~= 0 then
        hl.dispatch(hl.dsp.layout("center"))
    end

    -- Centering any narrow early column can make the tape offset negative,
    -- leaving a gap before column zero. A fit-mode recalculation clamps that
    -- offset to zero when the tape is wider than the viewport, while leaving
    -- an already-valid centered position unchanged. Restore center mode
    -- immediately so later navigation retains the intended behaviour.
    hl.config({ scrolling = { focus_fit_method = 1 } })
    hl.exec_scheduled_prop_refresh_immediately()
    local ok, err = pcall(function()
        hl.dispatch(hl.dsp.layout("fit_into_view"))
    end)
    hl.config({ scrolling = { focus_fit_method = 0 } })
    hl.exec_scheduled_prop_refresh_immediately()

    if not ok then
        error(err)
    end
end

-- Keep pointer focus consistent with Super+Left/Right: centre the selected
-- column unless that would expose empty space before the first column.
-- Restrict this to direct clicks so workspace changes and other focus events
-- retain ordinary Hyprland behaviour.
function M.handle_pointer_focus(_, reason)
    if reason == FOCUS_REASON_CLICK then
        align_focused_column()
    end
end

local function navigate(direction)
    hl.dispatch(hl.dsp.focus({ direction = direction }))
    align_focused_column()
end

local function navigate_stack(direction)
    local window = hl.get_active_window()
    local layout = window and window.layout

    if not layout or layout.name ~= "scrolling" then
        hl.dispatch(hl.dsp.focus({ direction = direction == "u" and "up" or "down" }))
        return
    end

    -- The scrolling layout's own vertical focus command stays inside the
    -- current column. Reapply the edge alignment afterwards because changing
    -- the focused member of a stack can otherwise recenter column zero.
    hl.dispatch(hl.dsp.layout("focus " .. direction))
    align_focused_column()
end

local function move_window(direction)
    local window = hl.get_active_window()
    local layout = window and window.layout

    if layout and layout.name == "scrolling" then
        hl.dispatch(hl.dsp.layout("consume_or_expel " .. direction))
        align_focused_column()
        return
    end

    -- Retain the conventional window-move action if another layout is used.
    hl.dispatch(hl.dsp.window.move({ direction = direction == "prev" and "left" or "right" }))
end

function M.focus_left()
    navigate("left")
end

function M.focus_right()
    navigate("right")
end

function M.focus_up()
    navigate_stack("u")
end

function M.focus_down()
    navigate_stack("d")
end

function M.move_window_left()
    move_window("prev")
end

function M.move_window_right()
    move_window("next")
end

return M
