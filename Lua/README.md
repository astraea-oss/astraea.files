# Lua — laptop dotfiles

Snapshot of Lua's selected active configuration, using the same `home/`,
`assets/`, and `system/sddm/` structure as Tera. Hardware-specific values are marked `EDIT ME`; this is a reviewed snapshot
rather than an automatic installer.

- `home/.config/hypr/`: active Lua config, scrolling helpers, lock screen,
  wallpaper config and media helper. Wallpapers and the logo live under
  `assets/wallpapers/` and `assets/logos/`.
- `home/.config/quickshell/ember-test/`: active shell, Bluetooth pairing agent,
  and edge-kvm notification bridge. The laptop has per-monitor bars, battery,
  Wi-Fi and Bluetooth controls, and notifications on the right, including when
  pinned. Run with `qs -c ember-test`; Hyprland starts it automatically.
- Kitty, btop, Fish (including Android/Rust environment snippets), Fastfetch
  and its logo, and Flameshot settings.
- `assets/fonts/`: locally installed Iceland font. JetBrains Mono and Symbols
  Nerd Font are referenced by the shell but are not bundled in this snapshot.
- `system/sddm/`: active `iz-ember` theme and the selector from
  `/etc/sddm.conf.d/10-theme.conf`. Theme files belong under
  `/usr/share/sddm/themes/iz-ember/` when installing.

The active Hyprland config is `hyprland.lua`. The older `hyprland.conf`, backups,
launcher history, saved UI state, credentials and pairing databases are excluded.
There are no matching active Satty, xsettingsd, xdph, custom btop theme, or
Fish `windows` function files on Lua.

## Paths and machine settings

Wallpaper and Fastfetch logo paths point directly into this checkout:
`/home/lua/Desktop/Projects/astraea.files/Lua/assets/`. Change that prefix if
cloning elsewhere. They do not reference the laptop's live config assets or
cloud-sync directories. Like Tera, the SDDM theme keeps relative, theme-local
background and font files so it remains self-contained when installed.

Search for `EDIT ME` / `EDIT-ME` before installing. Fixed display modes and
workspace/output assignments are commented examples; preferred display modes
and discovered workspaces are used by default. Optional output names in
Quickshell fall back to the first available display. The column-width helper
uses relative widths unless you set its optional pixel calibration.

Set Quickshell's `EDIT-ME-BATTERY` and `EDIT-ME-WIFI` placeholders for your battery
and wireless interface. The greeter's fallback account is also `EDIT-ME` when
there is no previously selected user. The lock prompt uses generic positioning,
and Fastfetch detects the GPU rather than displaying a fixed model name.

The setup uses Hyprland's Lua API, Quickshell/Qt 6, CachyOS Fish defaults,
Hyprpaper, Hyprlock, PipeWire tools, NetworkManager, UPower, power-profiles-daemon,
playerctl, brightnessctl and wl-clipboard. The Bluetooth helper uses Python's
PyGObject/Gio bindings. Hyprland also starts the distribution's
`plasma-polkit-agent.service`, KDE Connect and the locally installed PIA client.
Install the corresponding applications separately.

Shared notifications require edge-kvm's Quickshell integration. The bridge
component is included; its backend, credentials, notification history and
pairing state are not. The bridge is disabled until you enable it through
edge-kvm's settings or set `EDGE_KVM_NOTIFICATION_SOCKET` explicitly. Standalone
Quickshell does not retry a missing backend or queue offline closures.
See [MouseWithoutBorders Quickshell integration](https://github.com/astraea-oss/MouseWithoutBorders/blob/feat/shared-notifications/integrations/quickshell/README.md)
for setup and supported behaviour.

The review found no obvious embedded credentials, private cloud paths, saved
network identities or pairing/history databases. Image EXIF/XMP/text metadata
was removed from the repository copies without re-encoding their image data.
Live files were not modified. The video wallpaper is not distributed; Hyprpaper
uses the bundled static wallpaper instead.

Image and font assets retain their third-party rights; see
[ASSETS.md](../ASSETS.md).
