# YUTASHELL

A complete desktop shell for Wayland, built on [Quickshell](https://quickshell.outfoxxed.me).

Flat black surfaces, bone-white ink, a single acid accent, hairline structure, sparse Japanese micro-labels. Every color flows from one theme engine and every feature degrades gracefully when its backend is missing.

| | | |
|---|---|---|
| ![desktop](images/showcase/desktop.png) | ![launcher](images/showcase/appselector.png) | ![control center](images/showcase/controlcenter.png) |
| *desktop* | *app launcher* | *control center* |
| ![settings](images/showcase/settings.png) | ![notifications](images/showcase/notificationspanel.png) | ![wallpaper picker](images/showcase/wallpaperselector.png) |
| *settings* | *notification center* | *wallpaper archive* |

## Features

- **Bar** — data-driven segments: workspaces, taskbar, tray, media ticker, stat blocks, clock; reorder/toggle everything live (even from the settings UI)
- **Theme engine** — 12 preset schemes, wallpaper-derived palettes via matugen, runtime light mode, any-hex accent override; the whole shell repaints live
- **Wallpapers** — archive UI with one-pick apply: paints the desktop and regenerates every enabled app template in a single pass (~70 vendored matugen templates)
- **Surfaces** — settings panel, control center, app launcher, notification center, network/bluetooth/audio consoles, calendar, clipboard, weather, emoji picker, workspace overview, power menu, lock screen — each spawns from the bar, a screen edge, or float, per panel
- **Notifications** — the shell *is* the notification daemon: themed toasts, inline actions, DND, per-app rules, persisted history with replay
- **Connectivity & audio** — NetworkManager + BlueZ panels, PipeWire console with perceptual volume taper, OSDs, night light, brightness (internal + DDC/CI)
- **Session** — hold-to-confirm power menu, PAM lock screen, inhibitor-aware idle actions, power profiles, polkit dialog
- **Plugins** — drop-in QML widgets for the bar and headless daemons

## Requirements

| dependency | why |
|---|---|
| `quickshell` ≥ 0.3.1 | shell runtime |
| `matugen` ≥ 4.x | theming pipeline |
| `awww` | wallpaper painting |
| `grim` | screenshot capture |
| `slurp` | region selection |
| `wl-clipboard` | clipboard write |
| `cliphist` | clipboard history |
| JetBrainsMono Nerd Font | typeface |
| `noto-fonts-cjk` *(optional)* | Japanese labels (romaji fallback otherwise) |

Required backends (`grim`, `cliphist`, `wl-clipboard`) are probed at startup — missing ones hide their feature cleanly. Optional backends (`cava`, `hyprsunset`, `ddcutil`, `power-profiles-daemon`, `hyprpicker`, `networkmanager`, `bluez`, …) are also checked; if absent the related feature simply disappears.

## Installation

**Scripted (Arch, Debian, Fedora, openSUSE, Gentoo):**

```sh
git clone https://github.com/braxtonculver/yuta-qs
cd yuta-qs
make install    # checks deps, prints install commands, rsyncs to ~/.config/quickshell/yuta-qs
```

Re-run anytime to sync updates — your state in `~/.local/state/yutashell/` is never touched.

**Manual:** `git clone https://github.com/braxtonculver/yuta-qs ~/.config/quickshell/yuta-qs`
**Arch:** [`packaging/PKGBUILD`](packaging/PKGBUILD) · **Nix:** [`flake.nix`](flake.nix) (`programs.yutashell.enable`)

Then add to your Hyprland autostart:

```
exec-once = qs -c yuta-qs
```

## Keybinds

Everything user-facing is exposed over IPC — keybinds, CLI and the settings panel share one implementation:

```sh
qs ipc call <target> <function> [args...]
qs ipc call launcher toggle      # app launcher
qs ipc call wallpaper next       # cycle wallpaper + retheming pipeline
qs ipc call spawn set cc bottom  # control center docks to the bottom edge
```

Example hyprland keybinds:

```lua
_G.yuta = "qs -c yuta-qs ipc call"

hl.bind(mainMod .. " + SPACE",       hl.dsp.exec_cmd(yuta .. " launcher toggle"))
hl.bind(mainMod .. " + PERIOD",      hl.dsp.exec_cmd(yuta .. " cc toggle"))
hl.bind(mainMod .. " + L",           hl.dsp.exec_cmd(yuta .. " session lock"))
hl.bind("ALT + Tab",                 hl.dsp.exec_cmd(yuta .. " overview alttab"))
```

Full command table → [docs/ipc.md](docs/ipc.md)

## Documentation

| doc | contents |
|---|---|
| [docs/ipc.md](docs/ipc.md) | complete IPC target/function reference, keybind examples |
| [docs/configuration.md](docs/configuration.md) | state files, theming contract, per-panel spawn origins |
| [docs/plugins.md](docs/plugins.md) | writing widgets & daemon plugins |
| [docs/architecture.md](docs/architecture.md) | repo layout, development workflow |

Day-to-day configuration lives in the settings panel (`qs ipc call panel toggle`) — nothing needs hand-editing.

## License

[GPL-3.0-only](LICENSE)
