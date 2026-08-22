# YUTASHELL

A full desktop shell for Hyprland, built on [Quickshell](https://quickshell.outfoxxed.me).
Neo-brutalist Japanese cyber-minimalist: flat black surfaces, bone-white ink, one acid accent, hairline structure, uppercase mono type, sparse Japanese micro-labels. No rounded corners.

> **Status:** WIP — Phase 1 (taskbar) is functional. See [ROADMAP.md](ROADMAP.md) for the full build plan and progress.

![screenshot placeholder — add one when the shell stabilizes]

## Features (current)

- **Taskbar** (`modules/bar/`)
  - Identity block (`YUTA//OS`) with blinking cursor and hover inversion
  - Workspace switcher: dynamic slots, occupied/empty/urgent states, acid underline that slides to the focused workspace, red blink on window-urgent events
  - Focused-window title with app class, tracked via Hyprland's event stream
  - System tray (StatusNotifier): left-click menus, middle-click secondary actions, wheel scroll
  - Live stats cluster: network down/up rates, CPU % + VU meter, memory %, battery % with charging/low states
  - Clock with blinking colon, seconds, weekday/date; kanji weekday when a CJK font is installed
- **Theme system** (`theme/`): every color/font/metric lives in one singleton. Japanese labels auto-degrade to romaji when no CJK font is present — no tofu boxes.

## Requirements

- Arch Linux (or similar), Hyprland
- `quickshell` >= 0.3.1
- Fonts: `JetBrainsMono Nerd Font` (required), `noto-fonts-cjk` (recommended — enables the Japanese micro-labels):

  ```
  sudo pacman -S --needed ttf-jetbrains-mono-nerd noto-fonts-cjk
  ```

- Optional: `matugen`, `grim`, `slurp`, `wl-clipboard`, `cliphist`, `brightnessctl` (used by later roadmap phases)

## Run

```
quickshell -p ~/.config/quickshell/yutashell
```

Or set it as your session shell by launching that command from your Hyprland/Helmsman autostart.

## Project structure

```
yutashell/
├── shell.qml                  # entry point
├── theme/
│   ├── qmldir                 # singleton registration
│   └── Theme.qml              # design tokens: palette, type, metrics, JP detection
└── modules/
    └── bar/
        ├── Bar.qml            # panel window + layout + urgent-event routing
        ├── IdentityBlock.qml
        ├── Workspaces.qml
        ├── ActiveWindow.qml
        ├── TrayCluster.qml
        ├── StatsCluster.qml
        ├── ClockBlock.qml
        └── ui/
            └── DividerV.qml   # hairline divider with crosshair marks
```

## Environment notes

This shell is tuned to this machine's setup; two quirks are load-bearing:

1. **Helmsman Lua dispatcher.** This system's Hyprland wraps all IPC dispatches in Lua, so plain dispatch strings like `workspace 3` fail. All compositor actions go through wrapper functions using Lua-form dispatches, e.g. `Workspaces.switchTo(id)` sends `hl.dsp.focus({ workspace = "N" })`. If you ever remove Helmsman, change those wrappers back to standard dispatch strings.
2. **`Hyprland.activeToplevel` stays null** on this Quickshell build, so the focused-window title is derived from `activewindow` / `activewindowv2` raw events plus a one-shot `hyprctl -j activewindow` query at startup.

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
