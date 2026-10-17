# DotFiles

  Each machine gets its own folder:
   `Tera/` and `Luna/`,
Shared settings can be factored out later, after both machines have been
inventoried.

## Tera

`Tera/` is a snapshot of selected active configuration files and dependencies,
not a shared baseline. It contains:

- `home/.config/`: selected active files mirroring `~/.config/`.
- `assets/`: desktop wallpapers and font files used by the setup.
- `system/sddm/`: installed `iz-ember` login theme and selector config from
  `/etc/sddm.conf.d/10-theme.conf`.

### Captured configuration

- Hyprland Lua config and helper modules, Hyprlock, Hyprpaper, and media status
  script.
- Quickshell shell configuration. Launcher history is runtime data and is
  excluded from Git.
- Kitty, btop, Fish, and Fastfetch config, including referenced theme files
  and logo.
- xsettingsd, Flameshot, and Satty settings.
- Wallpapers, Iceland and JetBrains Mono fonts, and the custom SDDM theme.

### Machine-specific notes

GPU and monitor-specific values have been replaced with obvious `EDIT ME`
placeholders in the example configs, including the monitor helper and
Quickshell display selection. Hyprland will use preferred
display modes until you add monitor blocks based on `hyprctl monitors`. Several
files contain `/home/tera` paths. Hyprpaper/Hyprlock point under
`/home/tera/Pictures/`. Copies are also preserved in `Tera/assets/`; those
wallpaper paths have not been rewritten.

Fish sources CachyOS's installed config at
`/usr/share/cachyos-fish-config/cachyos-config.fish`.

## License and third-party assets

The root [LICENSE](LICENSE) applies only to the original configuration,
scripts, and documentation written by Tera. It does not apply to bundled
third-party assets. I do not own the images included with these dot
files; their rights remain with their respective creators or rights holders.
See [ASSETS.md](ASSETS.md) for known credits and source terms. The repository
license does not grant permission to reuse those assets.
