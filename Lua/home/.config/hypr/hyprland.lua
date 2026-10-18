-- Migrated from hyprland.conf for Hyprland 0.56.2.
-- The original hyprland.conf is deliberately retained as a rollback reference.

------------------
---- MONITORS ----
------------------

-- EDIT ME: run `hyprctl monitors` before adding fixed output settings.
-- Otherwise, use each connected display's preferred mode.
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
local menu = "qs -c ember-test ipc call ember toggleLauncher"
local main_mod = "SUPER"
local home = assert(os.getenv("HOME"), "HOME is not set")
local smart_scroll_nav = require(home .. "/.config/hypr/smart_scroll_nav.lua")
local column_widths = require(home .. "/.config/hypr/column_widths.lua")

-- Apply the custom first-column alignment when focus comes from a mouse click.
hl.on("window.active", smart_scroll_nav.handle_pointer_focus)

-------------------
---- AUTOSTART ----
-------------------

-- These retain the original order: the portal restart happens before
-- applications that need the Wayland portal environment.
hl.on("hyprland.start", function()
    hl.exec_cmd("sleep 1 && systemctl --user restart xdg-desktop-portal.service")
    -- Hyprland does not consume KDE-only XDG autostart entries. Start the
    -- authentication agent explicitly so pkexec-backed GUI tools can prompt.
    hl.exec_cmd("systemctl --user start plasma-polkit-agent.service")
    hl.exec_cmd("qs -c ember-test --daemonize --no-duplicate")
    hl.exec_cmd("uwsm app -- env QT_QPA_PLATFORM=wayland flameshot")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("/usr/lib/kdeconnectd &")
    hl.exec_cmd("sleep 5 && env XDG_CURRENT_DESKTOP=Unity /opt/piavpn/bin/pia-client")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("GTK_THEME", "Adwaita-dark")
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
        gaps_in = 8,
        gaps_out = 10,
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
        rounding = 4,
        rounding_power = 4,
        active_opacity = 1.0,
        inactive_opacity = 0.80,
        shadow = {
            enabled = false,
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

    -- Niri-like scrolling defaults used by every regular workspace.
    scrolling = {
        column_width =  0.4817708333,
        -- EDIT ME: tune these fractional widths for your preferred layout.
        -- Optional pixel calibration lives in column_widths.lua.
        explicit_column_widths = "0.1536458333, 0.4817708333, 0.6796875",
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
        sensitivity = 0,
        touchpad = { natural_scroll = false },
    },
})

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
hl.bind(main_mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(main_mod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(main_mod .. " + W", column_widths.cycle)
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

hl.bind(main_mod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(main_mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
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

-- EDIT ME: optionally assign workspaces after choosing output names.
-- Match the placeholders in Quickshell's workspaceIdsFor() if you use them.
-- for workspace = 1, 4 do
--     hl.workspace_rule({ workspace = tostring(workspace), monitor = "EDIT-ME" })
-- end
-- for workspace = 5, 8 do
--     hl.workspace_rule({ workspace = tostring(workspace), monitor = "EDIT-ME-SECONDARY", default = workspace == 5 })
-- end

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
