-- Pixel-stable preset widths for the scrolling layout on the selected output.
--
-- Hyprland stores scrolling column widths as fractions of the usable monitor
-- width. When a layer surface reserves space (the pinned Ember notification
-- centre), the usable width shrinks, so Super+W presets and new columns would
-- come out narrower. sync() rescales those fractions so their pixel sizes
-- match the unpinned layout. Quickshell calls it after pinning or unpinning.

local M = {}

-- EDIT ME: Set this to the output name from `hyprctl monitors`.
local OUTPUT = "EDIT-ME"
-- The base widths below assume only the 40px Ember bar reserves space.
local BASE_RESERVED = 40

-- Approximate column widths: 270px, 850px, 1280px.
M.base_column_width = 0.261627907
M.base_explicit_column_widths = { 0.0857558140, 0.261627907, 0.372093023 }

local function usable_width(monitor, reserved_left, reserved_right)
    local gaps = hl.get_config("general.gaps_out")
    local gap_left = type(gaps) == "table" and gaps.left or gaps or 0
    local gap_right = type(gaps) == "table" and gaps.right or gaps or 0
    return monitor.width - reserved_left - reserved_right - gap_left - gap_right
end

local function current_scale()
    local monitor = hl.get_monitor(OUTPUT)
    if not monitor or not monitor.reserved then
        return 1
    end
    local base = usable_width(monitor, BASE_RESERVED, 0)
    local now = usable_width(monitor, monitor.reserved.left, monitor.reserved.right)
    return now > 0 and base / now or 1
end

-- Scrolling options for hl.config(), scaled to the current reserved area.
function M.scrolling_config()
    local scale = current_scale()
    local explicit = {}
    for i, fraction in ipairs(M.base_explicit_column_widths) do
        explicit[i] = string.format("%.9f", math.min(1, fraction * scale))
    end
    return {
        column_width = math.min(1, M.base_column_width * scale),
        explicit_column_widths = table.concat(explicit, ", "),
    }
end

function M.sync()
    hl.config({ scrolling = M.scrolling_config() })
end

return M
