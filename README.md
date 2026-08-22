# YUTASHELL

A full desktop shell for Hyprland, built on [Quickshell](https://quickshell.outfoxxed.me).
Neo-brutalist Japanese cyber-minimalist: flat black surfaces, bone-white ink, one acid accent, hairline structure, uppercase mono type, sparse Japanese micro-labels. No rounded corners.

> **Status:** WIP — Phases 0–3 done (foundations, taskbar incl. per-monitor bars + media ticker, theme engine + matugen incl. light mode, settings control core). See [ROADMAP.md](ROADMAP.md) for the full build plan and progress.

![screenshot placeholder — add one when the shell stabilizes]

## Features (current)

- **Taskbar** (`modules/bar/`) — one bar window per connected screen, hot-plug aware
  - Identity block (`YUTA//OS`) with blinking cursor, hover inversion; **left-click opens the settings panel**
  - Workspace switcher: dynamic slots, occupied/empty/urgent states, acid underline that slides to the focused workspace, red blink on window-urgent events
  - Focused-window title with app class, tracked via Hyprland's event stream
  - System tray (StatusNotifier): left-click menus, middle-click secondary actions, wheel scroll
  - Media segment: MPRIS now-playing ticker between tray and stats — prefers the playing player, marquee track line while playing, click play/pause, wheel next/prev, hover tooltip; toggleable in settings
  - Live stats cluster: network down/up rates, CPU % + VU meter, memory %, battery % with charging/low states
  - Clock with blinking colon, seconds, weekday/date; kanji weekday when a CJK font is installed
- **Theme engine** (`theme/`): every color/font/metric lives in one singleton. Twelve curated scheme presets (acid, crimson, cyan, amber, catppuccin, cyberpunk, doom, gruvbox, mono, tokyonight, kanagawa, dracula) plus wallpaper-driven palettes via matugen — regenerating a scheme repaints every open surface live. **Light mode** regenerates every palette at runtime (paper surfaces, ink text, contrast-fitted accents); an **accent override** lets any color take the acid slot. Japanese labels auto-degrade to romaji when no CJK font is present.
- **Wallpaper module** (`modules/common/Wallpaper.qml`): indexes `~/Pictures/Wallpapers`, paints through awww, feeds matugen, applies the generated palette to the whole shell
- **Matugen template registry**: per-app config theming (kitty, alacritty, fuzzel, hyprland, gtk3/gtk4, mako, dunst, starship, btop, rofi, or custom entries) regenerated on every wallpaper change
- **Settings panel** (`modules/settings/`): right-side drawer — scheme swatches, light/dark mode + accent override ("Mode & accent"), current-wallpaper card, full matugen template catalog browser (search + add custom), bar segment toggles, system/about tabs
- **Wallpaper picker** (`modules/picker/`): standalone overlay panel with searchable thumbnail grid — bind it to its own key and swap wallpapers without touching settings; picking runs the whole pipeline (paint → matugen → every enabled template → live recolor)
- **UI kit** (`modules/common/ui/`): YButton / YSwitch / YRow / YSection / YField / YChip / YScroll — every panel is composed from these plus Theme tokens only, so both surfaces read as one system

## Requirements

- Arch Linux (or similar), Hyprland
- `quickshell` >= 0.3.1
- Fonts: `JetBrainsMono Nerd Font` (required), `noto-fonts-cjk` (recommended — enables the Japanese micro-labels):

  ```
  sudo pacman -S --needed ttf-jetbrains-mono-nerd noto-fonts-cjk
  ```

- Optional (needed for wallpaper theming): `matugen`, `awww` — used by the scheme engine:

  ```
  sudo pacman -S --needed matugen awww
  ```

- Later phases will use: `grim`, `slurp`, `wl-clipboard`, `cliphist`, `brightnessctl`

## Run

```
quickshell -p ~/.config/quickshell/yutashell
```

Or set it as your session shell by launching that command from your Hyprland/Helmsman autostart.

## Keybinds & IPC

Every user-facing action is exposed over Quickshell's IPC, so keybinds, CLI, and the settings panel all drive the same functions. The general form is:

```
qs ipc call <target> <function> [args...]
```

| target | function | what it does |
|---|---|---|
| `panel` | `toggle` / `open` / `close` | settings drawer |
| `picker` | `toggle` / `open` / `close` | standalone wallpaper picker panel |
| `scheme` | `set <name>` | apply a preset — see `scheme list` for all 12 ids |
| `scheme` | `list` | print available preset ids |
| `scheme` | `wallpaper` | re-follow the last applied wallpaper's palette |
| `wallpaper` | `set <path>` | set + paint + regenerate palette for an image |
| `wallpaper` | `next` | cycle to the next indexed wallpaper |
| `wallpaper` | `random` | jump to a random indexed wallpaper |
| `wallpaper` | `list` | print every indexed wallpaper path |
| `theme` | `generate <image>` | same as `wallpaper set` (explicit alias) |
| `theme` | `dark on\|off\|toggle` | light/dark mode — light palettes are regenerated live from the active scheme or wallpaper |
| `theme` | `accent <#hex\|none>` | override the acid accent (persisted; `none` follows the scheme again) |
| `templates` | `list` | show template catalog with enabled state |
| `templates` | `on <id>` / `off <id>` | enable/disable a template (rewrites matugen.toml, re-applies) |
| `templates` | `add <id> <input> <output>` | register a custom matugen template |
| `templates` | `remove <id>` | remove one |

### Hyprland binds (standard setup)

Add to your `hyprland.conf` (or Helmsman equivalent):

```
bind = SUPER, S, exec, qs ipc call panel toggle
bind = SUPER, W, exec, qs ipc call wallpaper next
bind = SUPERSHIFT, W, exec, qs ipc call picker toggle
bind = SUPERSHIFT, C, exec, qs ipc call scheme set crimson
```

If your config wraps dispatches in a dispatcher layer (e.g. this machine's Helmsman Lua dispatcher), route the command through that layer's exec wrapper instead — the shell side is plain `exec`, no special dispatch strings needed.

## Project structure

```
yutashell/
├── shell.qml                  # entry point + per-screen Variants + IpcHandlers
├── theme/
│   ├── qmldir                 # singleton registration
│   ├── Theme.qml              # design tokens + scheme engine + contrast check
│   ├── schemes/               # static preset palettes (12 schemes)
│   └── matugen/               # our own template + vendored catalog → theme.json
├── modules/
│   ├── bar/                   # taskbar: identity, workspaces, active window,
│   │                          # tray, media ticker, stats, clock + ui/
│   ├── common/
│   │   ├── ShellState.qml     # runtime state + persisted prefs singleton
│   │   ├── TemplateCatalog.qml# vendored matugen-themes registry
│   │   ├── Wallpaper.qml      # index/apply pipeline, template registry
│   │   └── ui/                # YButton/YSwitch/YRow/YSection/YField/YChip/YScroll
│   ├── picker/                # standalone wallpaper picker + ui/
│   └── settings/              # control-core drawer + ui/
```

## Environment notes

This shell is tuned to this machine's setup; two quirks are load-bearing:

1. **Helmsman Lua dispatcher.** This system's Hyprland wraps all IPC dispatches in Lua, so plain dispatch strings like `workspace 3` fail. All compositor actions go through wrapper functions using Lua-form dispatches, e.g. `Workspaces.switchTo(id)` sends `hl.dsp.focus({ workspace = "N" })`. If you ever remove Helmsman, change those wrappers back to standard dispatch strings.
2. **`Hyprland.activeToplevel` stays null** on this Quickshell build, so the focused-window title is derived from `activewindow` / `activewindowv2` raw events plus a one-shot `hyprctl -j activewindow` query at startup.

## Files written at runtime

Everything the shell writes lives under `~/.local/state/yutashell/`:

| file | purpose |
|---|---|
| `state.json` | persisted prefs: active scheme, wallpaper path, follow-wallpaper, dark mode, accent override, bar segment toggles, template registry |
| `theme.json` | matugen output for the shell's own palette (watched, live-reloads) |
| `matugen.toml` | generated matugen config assembled from the template registry |

## Theming contract

Modules never hardcode colors. Everything reads from the `Theme` singleton so future matugen integration only rewrites token values. Palette today:

| token | value | role |
|---|---|---|
| `bg` | `#0a0a0c` | surfaces |
| `ink` | `#eae8e0` | primary text |
| `acid` | `#c8ff3d` | accent |
| `alert` | `#ff3b52` | urgent/destructive |

## Roadmap

The full phased build plan — launcher, notifications, WiFi/BT panels, audio/media OSDs, dock, lock screen, settings core, matugen theming — lives in [ROADMAP.md](ROADMAP.md).
