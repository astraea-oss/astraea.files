-- Migrated from hyprland.conf for Hyprland 0.56.2.
-- The original hyprland.conf is deliberately retained as a rollback reference.

------------------
---- MONITORS ----
------------------

-- EDIT ME: run `hyprctl monitors` and add one block per display if you need
-- fixed modes or positioning. Uncomment this example and replace EDIT-ME.
-- Without explicit blocks, Hyprland uses each display's preferred mode.
-- hl.monitor({
--     output = "EDIT-ME",
--     mode = "preferred",
--     position = "0x0",
--     scale = 1,
-- })

---------------------
---- MY PROGRAMS ----
---------------------

local terminal = "kitty"
local file_manager = "dolphin"
local menu = "qs ipc call ember toggleLauncher"
local main_mod = "SUPER"
local smart_scroll_nav = require("/home/tera/.config/hypr/smart_scroll_nav.lua")
local column_widths = require("/home/tera/.config/hypr/column_widths.lua")
local agent_focus = require("/home/tera/.config/hypr/agent_focus.lua")

-------------------
---- AUTOSTART ----
-------------------

-- These retain the original order: the portal restart happens before
-- applications that need the Wayland portal environment.
hl.on("hyprland.start", function()
    hl.exec_cmd("sleep 1 && systemctl --user import-environment GTK_THEME QT_QPA_PLATFORMTHEME ADW_DISABLE_PORTAL && systemctl --user restart xdg-desktop-portal.service")
    -- Hyprland does not consume KDE-only XDG autostart entries. Start the
    -- authentication agent explicitly so pkexec-backed GUI tools can prompt.
    hl.exec_cmd("systemctl --user start plasma-polkit-agent.service")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("qs --daemonize --no-duplicate")
    hl.exec_cmd("uwsm app -- env QT_QPA_PLATFORM=wayland flameshot")
    hl.exec_cmd("sleep 5 && env XDG_CURRENT_DESKTOP=Unity /opt/piavpn/bin/pia-client")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("GTK_THEME", "Adwaita:dark")
hl.env("ADW_DISABLE_PORTAL", "1")
hl.env("TERMINAL", terminal)
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    cursor = {
        no_hardware_cursors = true,
        hotspot_padding = 2,
    },

    general = {
        gaps_in = 4,
        gaps_out = 4,
        border_size = 2,
        col = {
            active_border = { colors = { "rgba(d81f53ff)", "rgba(ff3f9eff)" }, angle = 45 },
            inactive_border = "rgba(2a0710aa)",
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "scrolling",
    },

    decoration = {
        rounding = 8,
        rounding_power = 4,
        active_opacity = 1.0,
        inactive_opacity = 0.85,
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = 0xee1a1a1a,
        },
        blur = {
            enabled = true,
            size = 3,
            passes = 1,
            vibrancy = 0.1696,
        },
    },

    animations = { enabled = true },

    master = { new_status = "master" },

    -- Niri-like scrolling defaults for workspaces 1–4. Column widths are
    -- applied below from column_widths.lua.
    scrolling = {
        fullscreen_on_one_column = false,
        focus_fit_method = 0,
        follow_focus = true,
    },

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo = false,
        size_limits_tiled = false,
    },

    input = {
        kb_layout = "gb",
        kb_variant = "",
        kb_model = "",
        kb_options = "",
        kb_rules = "",
        follow_mouse = 0,
        mouse_refocus = false,
        float_switch_override_focus = 0,
        sensitivity = 0,
        touchpad = { natural_scroll = false },
    },
})

-- Applied separately so the width maths sees the gaps configured above.
-- column_widths.lua keeps them pixel-stable when a pinned panel reserves
-- part of the monitor.
hl.config({ scrolling = column_widths.scrolling_config() })

------------------
---- ANIMATIONS ---
------------------

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })

---------------
---- INPUT ----
---------------

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })

---------------------
---- KEYBINDINGS ----
---------------------

hl.bind(main_mod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(main_mod .. " + C", hl.dsp.window.close())
hl.bind(main_mod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))
hl.bind(main_mod .. " + E", hl.dsp.exec_cmd(file_manager))
hl.bind(main_mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(main_mod .. " + F", hl.dsp.window.fullscreen())
hl.bind(main_mod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(main_mod .. " + W", hl.dsp.layout("colresize +conf"))
hl.bind(main_mod .. " + P", hl.dsp.window.pseudo())
hl.bind(main_mod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(main_mod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind("CTRL + Print", hl.dsp.exec_cmd("uwsm app -- env QT_QPA_PLATFORM=wayland flameshot gui --clipboard"))

hl.bind(main_mod .. " + left", smart_scroll_nav.focus_left)
hl.bind(main_mod .. " + right", smart_scroll_nav.focus_right)
hl.bind(main_mod .. " + SHIFT + left", smart_scroll_nav.move_window_left)
hl.bind(main_mod .. " + SHIFT + right", smart_scroll_nav.move_window_right)
-- Reorder the focused tiled window within its current scrolling column.
-- Left/right deliberately retain their column consume/expel behaviour above.
hl.bind(main_mod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(main_mod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))
hl.bind(main_mod .. " + up", smart_scroll_nav.focus_up)
hl.bind(main_mod .. " + down", smart_scroll_nav.focus_down)

for workspace = 1, 8 do
    hl.bind(main_mod .. " + " .. workspace, hl.dsp.focus({ workspace = workspace }))
    hl.bind(main_mod .. " + SHIFT + " .. workspace, hl.dsp.window.move({ workspace = workspace }))
end

-- Scratchpad shortcuts disabled for now to avoid accidental overlays.
-- hl.bind(main_mod .. " + S", hl.dsp.workspace.toggle_special("magic"))
-- hl.bind(main_mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(main_mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(main_mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(main_mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

------------------------------
---- WINDOWS AND WORKSPACES ---
------------------------------

-- Text-only Ember overlays must not blur or dim the windows underneath.
-- QML animates their text opacity; compositor surface fades are unnecessary.
hl.layer_rule({
    name = "ember-text-overlays",
    match = { namespace = "^ember-(focused-window|notification-popups)$" },
    blur = false,
    blur_popups = false,
    dim_around = false,
    no_anim = true,
})

-- EDIT ME: Add monitor-specific workspace rules after identifying your output
-- names with `hyprctl monitors`. Example for workspaces 1–4:
-- for workspace = 1, 4 do
--     hl.workspace_rule({ workspace = tostring(workspace), monitor = "EDIT-ME", default = workspace == 1, layout = "scrolling" })
-- end

-- Use workspace 2 as the inbox for newly created windows. "silent" keeps a
-- new window from pulling focus away from the currently visible workspace.
-- Put application-specific workspace rules below this catch-all to override it.
hl.window_rule({
    name = "default-window-workspace",
    match = { class = ".*" },
    workspace = "2 silent",
})

-- Windows opened by AI agents (claude, codex, opencode) appear without
-- taking focus; see agent_focus.lua.
hl.on("window.open_early", agent_focus.handle_open_early)
hl.on("window.open", agent_focus.handle_open)
hl.on("window.destroy", agent_focus.handle_destroy)

-- EDIT ME: Add any per-monitor window rules here once you have chosen outputs.

hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

hl.window_rule({
    name = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move = "20 monitor_h-120",
    float = true,
})

-- Keep the PoE trade overlay floating above the game on its workspace.
hl.window_rule({
    name = "awakened-poe-trade-overlay",
    match = { class = "^(awakened-poe-trade)$" },
    workspace = "1 silent",
    float = true,
    no_initial_focus = true,
    no_blur = true,
    no_shadow = true,
    border_size = 0,
    opacity = "1.0 override 1.0 override",
})

-- Keep the game opaque while interacting with the price check controls.
hl.window_rule({
    name = "path-of-exile-opaque",
    match = { class = "^(steam_app_238960)$" },
    opacity = "1.0 override 1.0 override",
})
