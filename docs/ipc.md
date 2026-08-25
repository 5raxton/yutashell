# IPC reference

Everything user-facing is exposed over [Quickshell IPC](https://quickshell.outfoxxed.me/docs/types/Quickshell/Ipc) — Hyprland keybinds, the CLI and the settings panel all call the same functions.

```sh
qs ipc -c yuta-qs call <target> <function> [args...]
```

## Targets

| target | function | action |
|---|---|---|
| `launcher` | `toggle` / `open` / `close` | app launcher (grid/list/detail + :command mode) |
| `panel` | `toggle` / `open` / `close` | settings panel |
| `settings` | `page <id>` / `list` | jump to a settings page; list page ids (`appearance bar dock osd panels launcher controlcenter notifications power security services system shell plugins about`) |
| `cc` | `toggle` / `open` / `close` | control center |
| `picker` | `toggle` / `open` / `close` | wallpaper archive |
| `overview` | `toggle` / `open` / `close` / `alttab` / `scratchpad` / `scratchsend` / `tile <preset>` / `status` | overview grid, window switcher, scratchpad, quick-tile |
| `scheme` | `set <name>` / `list` / `wallpaper` | 12 preset schemes; re-follow wallpaper palette |
| `wallpaper` | `set <path>` / `next` / `random` / `list` | set/cycle wallpapers (runs the whole theming pipeline) |
| `theme` | `dark on\|off\|toggle` / `accent <#hex\|none>` / `generate <image>` | light-dark mode; accent override; apply wallpaper image |
| `templates` | `list` / `on <id>` / `off <id>` / `add <id> <input> <output>` / `remove <id>` | 89 matugen template registry |
| `plugins` | `list` / `rescan` / `enable <id>` / `disable <id>` | plugin lifecycle |
| `audio` | `toggle` / `open` / `close` / `volup` / `voldown` / `mute` / `micmute` / `status` | PipeWire audio with OSD |
| `display` | `bright <pct>` | set brightness (0–100) |
| `brightness` | `up` / `down` / `set <pct>` / `status` | display brightness (internal + DDC/CI) + OSD |
| `power` | `saver` / `balanced` / `performance` / `cycle` / `status` | power profile; announces a toast on switch |
| `session` | `toggle` / `open` / `close` / `lock` / `logout` / `suspend` / `hibernate` / `reboot` / `poweroff` / `profile <name>` / `idle <action> <secs>` / `status` | session actions, idle config, power profiles |
| `dnd` | `on` / `off` / `toggle` / `status` | do not disturb |
| `notify` | `show <app> <sum> <body>` | send a toast notification |
| `notifycenter` | `toggle` / `open` / `close` / `clear` / `test <urgency>` | notification history center |
| `network` | `toggle` / `open` / `close` | network panel |
| `bluetooth` | `toggle` / `open` / `close` | bluetooth panel |
| `media` | `toggle` / `close` / `playpause` / `next` / `previous` | MPRIS media widget |
| `nightlight` | `toggle` / `on` / `off` / `temp <kelvin>` / `status` | night light (hyprsunset) |
| `shot` | `region` / `full` / `window` / `copy` / `dir` | screenshots (grim + slurp) |
| `clipboard` | `toggle` / `open` / `close` / `status` | clipboard history (cliphist) |
| `calendar` | `toggle` / `open` / `close` | calendar widget |
| `emoji` | `toggle` / `open` / `close` | emoji picker |
| `weather` | `toggle` / `open` / `close` / `set <lat> <lon> <label>` / `auto` / `detect` / `refresh` / `status` | weather widget; `auto` = IP geolocation |
| `updates` | `check` / `list` / `open` / `status` | package update checker |
| `recording` | `stop` / `status` | screen recording (gpu-screen-recorder) |
| `colorpicker` | `pick` | color pick operation (hyprpicker) |
| `compositor` | `info` / `dsp <lua>` | capability report / warm-client Hyprland dispatch passthrough |
| `dock` | `toggle` / `enable` / `disable` / `pin <id>` / `unpin <id>` / `hide <mode>` / `mode <mode>` / `status` | bottom dock |
| `bar` | see below | bar layout |
| `spawn` | see below | where each popup spawns from |

### `bar`

```
bar seg <id> on|off|left|center|right   # toggle/place a segment
bar move <id> <±n>                      # reorder across zones
bar scale <0.8–1.4>                     # bar height scaling
bar position top|bottom
bar click <id> <action>                 # per-segment click action
bar reset                               # restore default layout
bar wsmode default|numbers|pills|active # workspace render mode
bar status                              # current model as text
```

22 segment types: `identity`, `workspaces`, `taskbar`, `activewindow`, `tray`, `media`, `net`, `bt`, `audio`, `stats`, `cpu`, `mem`, `bat`, `cputemp`, `gpu`, `disk`, `nightlight`, `session`, `recording`, `pluginwidgets`, `clock`, `spacer`

### `spawn`

Every popup surface spawns from one of four modes — **bar** (dock flush under/over the bar), **top** (hang flush from the top edge), **bottom** (land flush on the bottom edge), **float** (fade in dead-center):

```
spawn set <panel> <mode>     # per-panel override (cc, settings, launcher, picker,
                             # notify, calendar, clipboard, emoji, weather,
                             # power, net, bt, vol, media, overview)
spawn setdefault <mode>
spawn list                   # effective mode for every panel
```

## Keybind examples

Hyprland Lua form:

```lua
_G.yuta = "qs -c yuta-qs ipc call"

hl.bind(mainMod .. " + SPACE",       hl.dsp.exec_cmd(yuta .. " launcher toggle"))
hl.bind(mainMod .. " + ALT + SPACE", hl.dsp.exec_cmd(yuta .. " panel toggle"))
hl.bind(mainMod .. " + CTRL + SPACE",hl.dsp.exec_cmd(yuta .. " picker toggle"))
hl.bind(mainMod .. " + V",           hl.dsp.exec_cmd(yuta .. " clipboard toggle"))
hl.bind(mainMod .. " + COMMA",       hl.dsp.exec_cmd(yuta ..  " session poweroff"))
hl.bind(mainMod .. " + PERIOD",      hl.dsp.exec_cmd(yuta .. " cc toggle"))
hl.bind(mainMod .. " + L",           hl.dsp.exec_cmd(yuta .. " session lock"))
hl.bind(mainMod .. " + SHIFT + P",   hl.dsp.exec_cmd(yuta .. " shot region"))
hl.bind(mainMod .. " + N",           hl.dsp.exec_cmd(yuta .. " notifycenter toggle"))
hl.bind("ALT + Tab",                 hl.dsp.exec_cmd(yuta .. " overview alttab"))
```
