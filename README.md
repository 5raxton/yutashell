# YUTASHELL

A full desktop shell for Hyprland, built on [Quickshell](https://quickshell.outfoxxed.me).
Neo-brutalist Japanese cyber-minimalist: flat black surfaces, bone-white ink, one acid accent, hairline structure, uppercase mono type, sparse Japanese micro-labels. No rounded corners.

> **Status:** WIP — Phases 0–6 done (foundations, taskbar incl. per-monitor bars + media ticker, theme engine + matugen incl. light mode, settings control core, notification daemon, connectivity suite). See [ROADMAP.md](ROADMAP.md) for the full build plan and progress.

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
- **Matugen template registry**: per-app config theming (kitty, alacritty, fuzzel, hyprland, gtk3/gtk4, mako, dunst, starship, btop, rofi, or custom entries) regenerated on every wallpaper change. The shell detects which themed apps are actually installed (absent apps show ABSENT and refuse to enable), and for include-style configs it **writes the include line itself** into a managed `# >>> yutashell-matugen` block — toggling a template is zero-friction; disabling strips the block again
- **Settings panel** (`modules/settings/`): drops from behind the bar as a large tabbed card — bar-style tab strip with sliding acid underline, scheme swatches, light/dark mode + accent override ("Mode & accent"), current-wallpaper card, full matugen template catalog browser (search + add custom), bar segment toggles, placement (center/left/right) + width customization, system/about tabs; remembers your last visited tab
- **Wallpaper picker** (`modules/picker/`): the ARCHIVE, a centered rectangle a step larger than the launcher (~1000×600) — a numbered index spine on the left (pure type, no thumbnail decoding) and a huge framed preview stage on the right showing one wallpaper at full quality. The always-focused filter field drives everything: type to filter, arrows to walk the index, enter or APPLY to commit; random/rescan in the spine, current wallpaper marked with an acid dot. Picking runs the whole pipeline (paint → matugen → every enabled template → live recolor)
- **App launcher**: small centered card (~640×460) dropping from beneath the bar, indexing every installed `.desktop` entry — fuzzy search (subsequence + boundary scoring across name/id/generic-name/keywords), grid or list view, pinned apps + recents weighting (right-click to pin, shift-del forgets), desktop-action rows, an inline calculator row (click to copy), and a `:` command mode driving the shell's own functions (`:scheme cyan`, `:wall random`, `:dark`, `:panel`, …). Placement, width, view mode, pins and recents persist.
- **One surface at a time**: opening any popup (settings / launcher / picker / network / bluetooth / notification center) closes the others; every surface arrives with the house entrance ritual — drop from behind the bar with a soft socket landing, one acid scanline sweep, border burn, family tick draw
- **Notification daemon** (`modules/notify/`): a full themed replacement for mako/dunst built on `Quickshell.Services.Notifications` — the shell *is* `org.freedesktop.Notifications`
  - Toast cards drop from behind the bar in a configurable corner (top-right/top-left), max N visible (1–6), flat black with a 1px urgency border (critical = alert red + CRITICAL tag), and a shrinking acid underline as the timeout progress; hovering a card pauses its countdown, criticals persist until dismissed
  - Inline action buttons rendered straight from each notification's actions; a global switch hides them all
  - **History ring**: every notification is recorded (50 in memory, 30 persisted to state.json) into the notification center — browsable card with per-row REPLAY / dismiss, CLEAR ALL, DND row with suppressed-counter chip
  - **Do not disturb**: IPC (`dnd on/off/toggle/status`) + bar-independent; normals/lows are held to history while criticals break through; a counter chip shows how many were silenced
  - Per-app overrides: match by app-name/desktop-entry substring → QUIET (history only) or BLOCK (drop entirely); edited in settings → NOTIFY tab along with default timeout, max visible, corner, and display-field toggles (app name / body / icon)
- **Connectivity suite** (`modules/net/`): native NetworkManager + BlueZ panels — no nm-applet
  - Bar segments: NET glyph with 4-tier wifi signal bars (or wired link bars, red × when wifi is off) and BT glyph when the adapter is powered; clicking opens their panels. Both toggleable in settings → MODULES
  - **Network panel**: wireless network list sorted by signal with lock glyphs + SAVED/CONN chips, inline passphrase join dialog (masked field), connect/forget for known networks, wired link speed + address, airplane mode master switch (wifi + BT radios down together), Wi-Fi radio/hard-block awareness
  - VPN tunnels: wireguard/vpn profiles listed from NetworkManager with UP/DOWN toggles
  - DNS: current resolvers readout + quick-set override applied to the active connection profile, REVERT back to DHCP
  - **Bluetooth panel**: adapter power/scanning/discoverable switches, device list with theme icons + battery % chips, PAIR / CONNECT / DISCONNECT / FORGET, and a trust switch (BlueZ trust doubles as the autoconnect flag)
- **UI kit** (`modules/common/ui/`): YButton / YSwitch / YRow / YSection / YField / YChip / YScroll / YSurface / FastWheel — every panel is composed from these plus Theme tokens only, so all surfaces read as one system
- **Surface language**: the bar sits on the overlay layer (topmost); every popup slides out from behind it on a shared choreography (`movSlow` drop, eased exit) and never dims the desktop — input is masked to the card so the rest of the screen stays live

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
| `launcher` | `toggle` / `open` / `close` | app launcher overlay (fuzzy search, `:` commands, calc) |
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
| `templates` | `on <id>` / `off <id>` | enable/disable a template (rewrites matugen.toml, injects/strips app-config snippet, re-applies; refuses absent apps) |
| `templates` | `add <id> <input> <output>` | register a custom matugen template |
| `templates` | `remove <id>` | remove one |
| `dnd` | `on` / `off` / `toggle` | do-not-disturb: normals/lows held to history, criticals break through |
| `dnd` | `status` | print dnd state + suppressed count + history size |
| `notifycenter` | `toggle` / `open` / `close` | notification history center |
| `notifycenter` | `clear` | dismiss all live toasts + wipe history |
| `notifycenter` | `test <urgency>` | send a test toast (`normal`/`low`/`critical`) |
| `network` | `toggle` / `open` / `close` | network panel (wifi/wired/vpn/dns) |
| `bluetooth` | `toggle` / `open` / `close` | bluetooth panel |

### Hyprland binds (standard setup)

Add to your `hyprland.conf` (or Helmsman equivalent):

```
bind = SUPER, A, exec, qs ipc call launcher toggle
bind = SUPER, S, exec, qs ipc call panel toggle
bind = SUPER, W, exec, qs ipc call wallpaper next
bind = SUPERSHIFT, W, exec, qs ipc call picker toggle
bind = SUPERSHIFT, C, exec, qs ipc call scheme set crimson
bind = SUPER, N, exec, qs ipc call notifycenter toggle
bind = SUPERSHIFT, N, exec, qs ipc call dnd toggle
bind = SUPER, G, exec, qs ipc call network toggle
bind = SUPER, B, exec, qs ipc call bluetooth toggle
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
│   ├── launcher/              # app launcher overlay (AppLauncher + fuzzy.js)
│   ├── notify/                # notification daemon: Notify singleton,
│   │                          # toast stack, history center + ui/
│   ├── net/                   # connectivity: NetBlock/BtBlock bar segments,
│   │                          # NetworkPanel, BluetoothPanel
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
| `state.json` | persisted prefs: active scheme, wallpaper path, follow-wallpaper, dark mode, accent override, bar segment toggles, template registry, launcher (mode/anchor/width/pins/recents), settings panel (placement/width/last page) |
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

Licensed under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/)
