# IPC reference

Everything user-facing is exposed over [Quickshell IPC](https://quickshell.outfoxxed.me/docs/types/Quickshell/Ipc) — Hyprland keybinds, the CLI and the settings panel all call the same functions.

```sh
qs ipc -c yuta-qs call <target> <function> [args...]
```

## Targets

| target | function | action |
|---|---|---|
| `launcher` | `toggle` / `open` / `close` | app launcher |
| `panel` | `toggle` / `open` / `close` | settings panel |
| `settings` | `page <id>` / `list` | jump to a settings page; list page ids (`appearance bar dock osd panels launcher controlcenter notifications power security services system shell plugins about`) |
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
| `power` | `saver` / `balanced` / `performance` / `cycle` / `status` | power profile; announces a toast on switch |
| `session` | `lock` / `logout` / `suspend` / `reboot` / `poweroff` / `profile …` / `idle …` | session actions |
| `dnd` | `on` / `off` / `toggle` / `status` | do not disturb |
| `notifycenter` | `toggle` / `clear` / `test <urgency>` | notification history center |
| `network` / `bluetooth` | `toggle` / `open` / `close` | connectivity panels |
| `shot` | `region` / `full` / `window` / `copy` | screenshots |
| `weather` | `set <lat> <lon> <label>` / `auto` / `detect` / `refresh` / `status` | weather widget; `auto` switches to IP geolocation (drives weather + timezone), `set` pins static coords |
| `calendar` / `emoji` / `clipboard` | `toggle` / `open` / `close` | popups |
| `bar` | see below | bar layout |
| `spawn` | see below | where each popup spawns from |
| `dock` | `toggle` / `pin` / `unpin` / `hide` / `mode` | bottom dock |
| `compositor` | `info` / `dsp <lua>` | capability report / warm-client dispatch passthrough |

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
