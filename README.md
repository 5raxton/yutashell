# YUTASHELL

A complete desktop shell for Wayland, built on Quickshell.

Flat black surfaces, bone-white ink, a single acid accent, hairline structure and sparse Japanese micro-labels — no rounded corners, no gradients. Every surface slides out from behind the bar on one shared choreography, every color flows from one theme engine, and every feature degrades gracefully when its backend is missing.

| | | |
|---|---|---|
| ![desktop](images/showcase/desktop.png) | ![launcher](images/showcase/app-launcher.png) | ![settings](images/showcase/appearance-settings-tab.png) |
| *desktop* | *launcher* | *settings* |
| ![notifications](images/showcase/notification-center.png) | ![wallpaper picker](images/showcase/wallpaper-selector.png) | |
| *notification center* | *wallpaper archive* | |

## Features

**Bar** — one per connected screen (hot-plug aware), fully data-driven: an ordered `{id, zone, enabled}` model persisted in state.json controls 18 segments across left/center/right zones — center segments hold the true middle of the screen and only yield when the flanks collide. Workspaces with four render modes (numbered pills / bare digits / digit-less pills / occupied-only), occupied/urgent states, merged pinned+running taskbar, system tray (SNI), MPRIS now-playing ticker, CPU/MEM/NET/BAT stat cells (plus GPU / disk-IO / CPU-temp), clock, night-light and session chips. Scale 0.8–1.4×, top or bottom, per-segment click actions with sane fallbacks (no segment is ever a dead button).

**Theme engine** — every color, font and metric lives in a single `Theme` singleton; modules never hardcode values, so the whole shell repaints live when the palette changes. Twelve curated schemes (`acid`, `crimson`, `cyan`, `amber`, `catppuccin`, `cyberpunk`, `doom`, `gruvbox`, `mono`, `tokyonight`, `kanagawa`, `dracula`), wallpaper-derived palettes via matugen, runtime-generated light mode for any palette (with WCAG contrast fitting), and an accent override that lets any hex take the accent slot. Japanese labels fall back to romaji automatically when no CJK font is installed.

**Wallpaper & template pipeline** — index → paint (awww) → palette (matugen) → apply. The wallpaper archive UI keeps a type-driven index spine plus one full-quality preview; picking a wallpaper repaints the desktop and regenerates every enabled app template in one pass. ~70 vendored matugen templates (terminals, editors, GTK, bars, prompts…); for include-style configs the shell writes and strips its own managed block inside the target app's config, so toggling a template is zero-friction and fully reversible. Custom templates are two paths away.

**Surfaces** — settings panel (15 pages behind a searchable nav rail), control center (11 tabs), app launcher (fuzzy search, pins/recents, inline calculator, `:` command mode), wallpaper archive, notification center, network/bluetooth/audio consoles, calendar, clipboard, weather, emoji pickers, workspace overview with Alt-Tab switcher and quick-tile presets, power menu, lock screen. One surface open at a time; click-outside closes; ESC closes.

**Notifications** — the shell *is* the notification daemon (`org.freedesktop.Notifications`): themed toasts with timeout underlines and hover-pause, inline action buttons, do-not-disturb with suppressed counter, per-app overrides (quiet/block), and a persisted history ring with replay.

**Connectivity & audio** — native NetworkManager and BlueZ panels (Wi-Fi join/forget, VPN tunnels, DNS override, airplane mode, device pairing/trust/battery) and a PipeWire console (per-device and per-stream volume with perceptual taper, overdrive ceiling, default-device switching). Volume/mic/brightness OSDs with per-kind toggles. Night light (hyprsunset) and display brightness through brightnessctl or DDC/CI. Weather/location resolves by IP automatically or from static coordinates.

**Session & security** — hold-to-confirm power menu, full-screen lock screen with PAM auth, inhibitor-aware idle actions, power profiles (power-profiles-daemon), and a themed polkit authentication dialog.

**Plugins** — drop a folder with `plugin.json` + QML into `plugins/`: `widget` types render in a dedicated bar segment, `daemon` types run headless at boot. State is namespaced and persists across restarts. Two reference plugins ship with the shell.

**Graceful degradation** — every optional backend (cliphist, hyprsunset, ddcutil, hyprpicker, gpu-screen-recorder…) is probed at startup; missing features report through a Health singleton shown as a `!` chip in the bar instead of failing silently.

## Requirements

| dependency | why |
|---|---|
| [Hyprland](https://hyprland.pl) ≥ 0.56 **with the Helmsman Lua dispatcher** | compositor; all shell→compositor dispatches use Helmsman's `hl.dsp.*` Lua forms |
| `quickshell` ≥ 0.3.1 | shell runtime |
| `matugen` ≥ 4.x | wallpaper theming pipeline |
| `awww` | wallpaper painting |
| JetBrainsMono Nerd Font | required typeface |
| `noto-fonts-cjk` *(optional)* | enables Japanese micro-labels (romaji fallback otherwise) |

Optional feature backends — each hides its feature cleanly when absent:

`grim` + `slurp` (screenshots) · `wl-clipboard` + `cliphist` (clipboard manager) · `cava` (visualizer) · `hyprsunset` (night light) · `brightnessctl` (internal panel brightness) · `ddcutil` (external monitor brightness over DDC/CI) · `curl` (weather + IP geolocation) · `power-profiles-daemon` (power plans) · `gpu-screen-recorder` (recording indicator) · `hyprpicker` (color picker) · `checkupdates` from pacman-contrib (update counter)

> **Helmsman note**: this config drives Hyprland through the Helmsman Lua dispatcher's `hl.dsp.*` API rather than raw IPC dispatch strings. On a stock Hyprland install without Helmsman, compositor-facing features (workspace switching, window management, scratchpad, tiling presets) will not function; panels, widgets and theming are unaffected. Porting the handful of dispatch wrappers in `modules/bar/Workspaces.qml`, `modules/dock/Dock.qml`, `modules/overview/Overview.qml` and `modules/common/{FocusMonitor,Compositor}.qml` to raw dispatches is straightforward if you don't run Helmsman.

## Installation

**Scripted (Arch, Debian, Fedora, openSUSE, Gentoo):**

```sh
git clone https://github.com/braxtonculver/yuta-qs
cd yuta-qs
make install          # detects your package manager, checks deps,
                      # prints exact install commands, then rsyncs
                      # the config into ~/.config/quickshell/yuta-qs
```

Run it again at any time to sync updates — your state in `~/.local/state/yutashell/` is never touched.

**Manual:**

```sh
git clone https://github.com/braxtonculver/yuta-qs ~/.config/quickshell/yuta-qs
```

**Arch (AUR-style):** a `PKGBUILD` is provided in [`packaging/`](packaging/PKGBUILD).

**Nix:** a flake with a home-manager module is provided in [`flake.nix`](flake.nix) (`programs.yutashell.enable`; pulls quickshell + runtime deps, registers the autostart entry).

Then start it from your Hyprland autostart:

```
exec-once = qs -c yuta-qs
```

or test in place:

```sh
qs -p ~/.config/quickshell/yuta-qs
```

## Keybinds & IPC

Everything user-facing is exposed over Quickshell IPC — keybinds, CLI and the settings panel all call the same functions:

```sh
qs ipc call <target> <function> [args...]
```

| target | function | action |
|---|---|---|
| `launcher` | `toggle` / `open` / `close` | app launcher |
| `panel` | `toggle` / `open` / `close` | settings panel |
| `cc` | `toggle` / `open` / `close` | control center |
| `picker` | `toggle` / `open` / `close` | wallpaper archive |
| `overview` | `toggle` / `alttab` / `scratchpad` / `tile <preset>` | overview grid, window switcher, scratchpad, quick-tile |
| `scheme` | `set <name>` / `list` / `wallpaper` | preset schemes; re-follow wallpaper palette |
| `wallpaper` | `set <path>` / `next` / `random` / `list` | set/cycle wallpapers (runs the whole theming pipeline) |
| `theme` | `dark on\|off\|toggle` / `accent <#hex\|none>` | light-dark mode; accent override |
| `templates` | `list` / `on <id>` / `off <id>` / `add …` / `remove <id>` | matugen template registry |
| `plugins` | `list` / `rescan` / `enable <id>` / `disable <id>` | plugin lifecycle |
| `audio` | `volup` / `voldown` / `mute` / `micmute` / `status` | master audio with OSD |
| `brightness` | `up` / `down` / `set <pct>` / `status` | display brightness (internal + DDC/CI) |
| `power` | `saver` / `balanced` / `performance` / `cycle` / `status` | power profile per keybind; announces a toast on switch |
| `session` | `lock` / `logout` / `suspend` / `reboot` / `poweroff` / `profile …` / `idle …` | session actions |
| `dnd` | `on` / `off` / `toggle` / `status` | do not disturb |
| `notifycenter` | `toggle` / `clear` / `test <urgency>` | history center |
| `network` / `bluetooth` | `toggle` / `open` / `close` | connectivity panels |
| `shot` | `region` / `full` / `window` / `copy` | screenshots |
| `weather` | `set <lat> <lon> <label>` / `auto` / `detect` / `refresh` / `status` | weather widget; `auto` switches to IP geolocation (drives weather + timezone), `set` pins static coords |
| `calendar` / `emoji` / `clipboard` | `toggle` / `open` / `close` | popups |
| `bar` | `seg <id> on\|off\|left\|center\|right` / `move` / `scale` / `position` / `click` / `wsmode default\|numbers\|pills\|active` | bar layout |
| `dock` | `toggle` / `pin` / `unpin` / `hide` / `mode` | bottom dock |
| `compositor` | `info` / `dsp <lua>` | capability report / warm-client dispatch passthrough |

Example Hyprland keybinds:

```
_G.yuta = "qs -c yuta-qs ipc call"
```

```
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(yuta .. " launcher toggle"))
hl.bind(mainMod .. " + ALT + SPACE", hl.dsp.exec_cmd(yuta .. " panel toggle"))
hl.bind(mainMod .. " + CTRL + SPACE", hl.dsp.exec_cmd(yuta .. " picker toggle"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(yuta .. " clipboard toggle"))
hl.bind(mainMod .. " + COMMA", hl.dsp.exec_cmd(yuta ..  " session poweroff"))
hl.bind(mainMod .. " + PERIOD", hl.dsp.exec_cmd(yuta .. " cc toggle"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(yuta .. " session lock"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(yuta .. " shot region"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(yuta .. " notifycenter toggle"))
hl.bind("ALT + Tab", hl.dsp.exec_cmd(yuta .. " overview alttab"))
```

## Configuration

All user preferences persist to `~/.local/state/yutashell/`:

| file | purpose |
|---|---|
| `state.json` | every pref: scheme, wallpaper, bar segments, launcher pins/recents, notification rules, session/idle config, dock layout, plugin data |
| `geo.json` | cached IP-geolocation fix (lat/lon/city/timezone) for auto location |
| `weather.json` | last open-meteo payload (boot-time conditions before first refresh) |
| `theme.json` | current matugen-generated palette (watched; edits hot-reload) |
| `matugen.toml` | generated matugen config assembled from the enabled templates |

Day-to-day configuration happens in the settings panel (`SUPER,S` or `qs ipc call panel toggle`) — appearance, bar segments, notifications, OSD, session behavior, dock, plugins. Nothing needs hand-editing.

### Theming contract

Modules read colors exclusively from the `Theme` singleton, which is why live recoloring is free: changing scheme, applying a wallpaper, toggling light mode or setting an accent only rewrites token values. Baseline tokens of the `acid` scheme: `bg #0a0a0c`, `ink #eae8e0`, `acid #c8ff3d`, `alert #ff3b52`.

## Plugins

Create a folder under `plugins/<your-plugin>/` with a manifest:

```json
{
    "id": "my-plugin",
    "name": "My Plugin",
    "version": "1.0.0",
    "type": "widget",
    "component": "./main.qml"
}
```

- `"type": "widget"` — a `Rectangle`-rooted QML component rendered inside the bar's PLUGIN WIDGETS segment
- `"type": "daemon"` — instantiated invisibly at boot while enabled; persist state via `PluginService.loadPluginData()` / `savePluginData()`
- optional `settings[]` array describes per-plugin options surfaced in Settings → PLUGINS

Plugin QML can import the shell's own kit (`qs.theme`, `qs.modules.common.ui`). See `plugins/PulseDot/` (widget) and `plugins/WallpaperWatcherDaemon/` (daemon) for reference implementations. Plugins execute with full shell privileges — only install ones you trust.

## Development

```sh
make lint-qml   # qmllint gate (fails on syntax errors)
make test       # integration smoke test: spawns an isolated instance,
                # drives the IPC surface, greps the log, checks RSS
make dist       # release tarball
```

The smoke test refuses to run while another instance is live and always terminates the instance it spawns.

```
yuta-qs/
├── shell.qml              entry point, per-screen instances, IPC handlers
├── theme/                 Theme singleton, 12 preset palettes, matugen setup
├── modules/
│   ├── bar/               taskbar segments + segment framework
│   ├── common/            ShellState, Theme consumers, Wallpaper/template
│   │                      pipeline, SystemStats, PluginService,
│   │                      FocusMonitor, Compositor, Health, ui kit
│   ├── settings/          settings panel (15 pages)
│   ├── control/           control center (11 tabs)
│   ├── launcher/          app launcher
│   ├── picker/            wallpaper archive
│   ├── notify/            notification daemon, toasts, history center
│   ├── net/               network + bluetooth panels, bar chips
│   ├── audio/             PipeWire service, audio console, OSDs, media,
│   │                      night light, display brightness
│   ├── session/           power menu, lock screen, idle, polkit dialog
│   ├── dock/              bottom dock
│   ├── overview/          workspace grid, alt-tab, tile presets
│   └── widgets/           calendar, weather, clipboard, screenshots,
│                          emoji, updates, recording, color picker
└── plugins/               reference widget + daemon plugins
```

## Acknowledgments

Design and feature inspiration from [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell), Ryoku and [caelestia-shell](https://github.com/caelestia-dots/shell). Built on [Quickshell](https://quickshell.outfoxxed.me) by outfoxxed.

## License

[GPL-3.0-only](LICENSE)
