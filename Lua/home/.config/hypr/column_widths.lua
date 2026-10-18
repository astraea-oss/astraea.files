-- Super+W column-width cycling, using relative widths by default.
-- EDIT ME: set REFERENCE_WIDTH to a calibration width in pixels if you want
-- consistent pixel-sized columns across differently sized displays.

local M = {}

local REFERENCE_WIDTH = nil -- EDIT ME: optional numeric pixel width
-- Keep in sync with scrolling.explicit_column_widths in hyprland.lua.
local STEPS = { 0.1536458333, 0.4817708333, 0.6796875 }
local EPSILON = 0.01

function M.cycle()
    local window = hl.get_active_window()
    local layout = window and window.layout
    local monitor = window and window.monitor

    if not layout or layout.name ~= "scrolling" or not layout.column or not monitor then
        hl.dispatch(hl.dsp.layout("colresize +conf"))
        return
    end

    local scale = REFERENCE_WIDTH and REFERENCE_WIDTH / monitor.width or 1
    local current = layout.column.width
    local largest = math.min(STEPS[#STEPS] * scale, 1)
    -- Wider than every step: snap
    -- down to the largest step first rather than wrapping to the tiny one.
    local target = current > largest + EPSILON and largest or math.min(STEPS[1] * scale, 1)

    for _, step in ipairs(STEPS) do
        local width = math.min(step * scale, 1)
        if width > current + EPSILON then
            target = width
            break
        end
    end

    hl.dispatch(hl.dsp.layout(string.format("colresize %.6f", target)))
end

return M
