-- Preset widths for the scrolling layout.
--
-- Hyprland stores scrolling column widths as fractions of the usable monitor
-- width (monitor width minus reserved space and outer gaps). Keep these fixed:
-- nothing should reserve space beyond the bar, so the fractions always map to
-- the same pixel sizes. The pinned notification centre is an overlay for this
-- reason; rescaling presets per reserved area made columns sized while pinned
-- grow when unpinned.

local M = {}

-- Tuned for a 3440px-wide display with the 40px Ember bar and 4px outer gaps
-- (3392px usable): column widths ≈ 291px, 887px, 1262px. Adjust to taste.
M.column_width = 0.261627907
M.explicit_column_widths = { 0.0857558140, 0.261627907, 0.372093023 }

function M.scrolling_config()
    local explicit = {}
    for i, fraction in ipairs(M.explicit_column_widths) do
        explicit[i] = string.format("%.9f", fraction)
    end
    return {
        column_width = M.column_width,
        explicit_column_widths = table.concat(explicit, ", "),
    }
end

return M
