# YUTASHELL

Quickshell config for Hyprland. Entry: `shell.qml`. Design tokens in `theme/Theme.qml` (import as `qs.theme`). ROADMAP.md is the master checklist — work top to bottom, keep checkboxes honest.

## Verified environment facts (this machine)

- Quickshell 0.3.1. `Hyprland.activeToplevel` never populates — track focused windows via `activewindow`/`activewindowv2` raw events + one-shot `hyprctl -j activewindow` probe.
- Per-monitor surfaces: `Variants { model: Quickshell.screens; Bar { required property var modelData; screen: modelData } }` — verified working for the bar; instances follow hot-plug. Known limitation: the shared Tooltip window sits on one screen, so tooltips triggered from another monitor's bar can misposition (fine single-monitor; fix when multi-monitor matters).
- `Quickshell.Services.Mpris` verified: `Mpris.players.values`; player has `identity`, `isPlaying`, `trackArtist`/`trackTitle`, `canTogglePlaying`/`togglePlaying()`, `canGoNext/Previous`/`next()`/`previous()`, `volume`+`volumeSupported`. Used by the bar media segment (`modules/bar/MediaBlock.qml`).
- `DesktopEntries` singleton verified: `applications.values` (filter `noDisplay`), `byId(id)`, `heuristicLookup(name)`. `DesktopEntry` has `id/name/genericName/startupClass/noDisplay/comment/icon/execString/command/workingDirectory/runInTerminal/categories/keywords` + **`execute()`** (launches properly — no manual Exec parsing) and **`actions`** (`QList<DesktopAction*>`, each with `id/name/icon` + `execute()`). Used by the launcher (`modules/launcher/`).
- Light mode is **generated, not stored**: `Theme._toLight()` HSL-remaps any token map (preset or wallpaper palette) to paper/ink; `_fitOnLight()` darkens acid/alert against the live bg until they pass the same ratios the contrast self-check asserts (3.0 / 2.5). Zero warnings across full preset cycles in light mode = acceptance signal.
- Hyprland runs the **Helmsman Lua dispatcher**: raw dispatch strings (`workspace 3`) fail; wrapper functions send Lua-form dispatches like `hl.dsp.focus({ workspace = "N" })`.
- **Hyprland color formats (verified 0.56.2 by hyprctl round-trip)**: `rgba()` hex is parsed as RRGGBBAA (trailing alpha — `rgba(112233ff)` → internal `ff112233`), and bare `0xAARRGGBB` strings parse directly (`"0xff18130b"` → `ff18130b`). The colors.lua template's `0xff…` values are therefore correct as-is. Internal/`getoption -j` form is always AARRGGBB.
- **Runtime config on this machine goes through `hyprctl eval '<lua>'`** — plain `hyprctl keyword` fails ("keyword can't work with non-legacy parsers"). Nested Lua tables mirror option paths: `hl.config({general={col={active_border="…"}}})` sets `general:col.active_border`; verified paths: general.col.active/inactive_border, group.col.border_active/inactive, group.groupbar.col.active/inactive.
- **Hyprland theming (hyprland-lua template)**: `colors.lua` both returns the palette table AND applies borders via `hl.config` at require time (boot); live updates come from the catalog post hook running the same `hl.config` through `hyprctl eval` after every matugen run. Nothing else in the Helmsman config consumed colors.lua before this — borders stayed default forever, which read as "matugen broken for hyprland".
- Wallpaper engine is **awww** (`awww-daemon`, not swww/hyprpaper). matugen installed.
- No CJK font → `Theme.jpEnabled` false → romaji fallbacks everywhere.
- `~/.local/state/yutashell/` holds all runtime files: state.json, theme.json, matugen.toml. Nothing else writes dotfiles.
- Deps present: grim, slurp, wl-copy, cliphist (0.7), curl, checkupdates, nvidia-smi (RTX 5080 — GPU stats via batched `nvidia-smi --query-gpu=...`), gpu-screen-recorder 6.x, notify-send, pactl, nmcli, bluetoothctl, rfkill, cava, hyprsunset, ddcutil, powerprofilesctl. Absent: hyprpicker. Features needing absent deps must hide gracefully (ROADMAP tracks which phase gates each).
- Network reality: **wired ethernet is primary** (enp133s0), wlan0 exists but rfkill soft-blocked + NM wifi disabled (panel shows radio state honestly), `wg0-mullvad` wireguard ACTIVE (externally managed — visible via nmcli, not Quickshell.Networking). Bluetooth controller hci0 present, bluetoothd active.
- `Quickshell.Services.Notifications` verified: `NotificationServer` claims the bus when no other daemon runs; caps props (`bodySupported`/`actionsSupported`/`imageSupported`/…); `onNotification(n)` → n has appName/appIcon/summary/body/urgency enum/expireTimeout/actions/**`tracked` (set true to hold)**/`expire()`/`dismiss()`; `closed` signal. Used by `modules/notify/`.
- `Quickshell.Networking`: `Networking.devices.values` → WifiDevice (`networks`, `scannerEnabled`, `mode`) / WiredDevice (`hasLink`, `linkSpeed`, `address`); `wifiEnabled`+`wifiHardwareEnabled` writable-ish; connectivity compares against `NetworkConnectivity.Full`. Enum name is **NetworkConnectivity** (not Connectivity).
- `Quickshell.Bluetooth`: root singleton exports as **`Bluetooth`** (NOT Bluez): `Bluetooth.defaultAdapter` (`enabled/discovering/discoverable/devices`) → devices have `deviceName/icon/state/paired/trusted/batteryAvailable/battery` + `pair()/connect()/disconnect()/forget()`.
- `Quickshell.Services.Pipewire` verified (PH.07, `modules/audio/AudioService.qml`): `Pipewire.defaultAudioSink`/`defaultAudioSource` (writable — assign a node to set default), `Pipewire.preferredDefaultAudioSource`, `Pipewire.nodes.values` → node `.audio` (PwNodeAudio: `volume` linear 0..1+, `muted`) + `.isStream` + `.name`/`.description`. Volume is LINEAR; perceptual steps need cubic mapping (`nodeFrac`/`stepPct`). Streams vs devices distinguished by `isStream`.
- **Hyprland Lua dispatches require a WARM client.** `Hyprland.dispatch('hl.dsp.*')` silently no-ops from a freshly-spawned instance unless (a) the event socket is connected (`Hyprland.rawEvent.connect(() => {})` or any event listener) AND (b) ~8 s of uptime has elapsed. The live shell always qualifies (long-lived + always subscribed) — that's why bar workspace clicks work but a 2 s-lived test instance's identical dispatch does nothing. `hyprctl eval '<lua>'` is always a cold client: fine for `hl.config` (theming), but its `hl.dsp.*` calls are inert. Verified working from a warm client: `hl.dsp.focus({ window = "class:X" })` (selector strings AND userdata objects from `hl.get_windows()`), `hl.dsp.workspace.toggle_special("magic")`, `hl.dsp.window.move({ workspace = N })` (focused window only — no window selector arg), `hl.dsp.focus({ workspace = "N" })` (existing workspaces only; does NOT auto-create). `hl.dsp.focus({ bogus })` returns the "Expected one of: direction, monitor, window, urgent_or_last, last" hint. Full `hl.dsp`/`hl.*` API enumerable from `hyprctl eval` by writing `io.open("/tmp/x","w")` and dumping `pairs(hl.dsp)` etc.
- **PH.08 session APIs**: `WlSessionLock` default property is **`surface`** (a Component, NOT `surfaceComponent`) — declare `WlSessionLockSurface {}` directly inside it; `WlSessionLockSurface` exposes `screen` (ShellScreen = QuickshellScreenInfo, has `.name`), `color` (writable), `contentItem`; children CAN `anchors.fill: parent`. `PamContext` (Quickshell.Services.Pam): `config`/`user`/`responseRequired`/`responseVisible`, `start()`/`abort()`/`respond(pw)`, `completed(result)` where `PamResult.Success/Failed/Error/MaxTries`; `config` = a `/etc/pam.d/` service name — **`system-auth`** works for password verification. `Quickshell.Services.UPower` exports TWO singletons: `UPower` (devices/displayDevice) AND **`PowerProfiles`** (`.profile` read+write, enum 0=saver/1=balanced/2=performance, `hasPerformanceProfile`, `holds`). power-profiles-daemon is DBus-activatable here — probe availability with `busctl --system introspect net.hadess.PowerProfiles /net/hadess/PowerProfiles` (exit 0 = available; `systemctl is-active` lies before first activation). `PolkitAgent` is instantiable (not singleton): `isActive`, `flow` → AuthFlow {`message`/`inputPrompt`/`responseVisible`/`identities`/`selectedIdentity`/`supplementaryMessage`+`supplementaryIsError`, `submit(value)`, `cancelAuthenticationRequest()`, `failed`}. `IdleMonitor` lives under `Quickshell.Wayland._IdleNotify` (import the submodule). `Quickshell.quit()` is the exit API. `loginctl list-inhibitors --no-legend` needs no privileges for the user's seat.
- **PH.09/PH.10 Hyprland models**: `HyprlandToplevel` has `address/title/activated/urgent/workspace/monitor/wayland(Toplevel)/lastIpcObject(QVariantMap)` — **no `.class` and no `activate()` method**; app id = `tl.wayland?.appId || tl.lastIpcObject?.class`. Focus a window via `Hyprland.dispatch('hl.dsp.focus({ window = "address:' + addr + '" })')` (selector strings work from a warm client). `HyprlandWorkspace` has `id/name/active/focused/urgent/hasFullscreen/toplevels` + `activate()`. The models auto-update once populated; call `refreshToplevels()`/`refreshWorkspaces()` once at boot. `WlrLayershell` anchors are ONLY `left/right/top/bottom` (bool) — **no `horizontalCenter`**; a centered bottom dock = full-width window (`left+right+bottom`) + `mask: Region { item: <centered content> }` + centered child. `resize` accepts `{ x, y }`; `float`/`center`/`fullscreen`/`close` take no validated args. `hl.dsp.window.move({ workspace = "special:magic" })` is the minimize-to-scratchpad gesture. DesktopEntries: `byId(id)`, `heuristicLookup(name)` (returns DesktopEntry with `.icon`/`.name`/`.execute()`).

## Hard-won lessons (do not regress these)

### 1. NEVER decode full-res images for thumbnails — OOM incident
The settings panel's wallpaper grid decoded every image in `~/Pictures/Wallpapers` (194 files) at full resolution: quickshell hit **7–13 GB RSS**, swap thrashed the system to a freeze, and the kernel OOM-killed the session back to the greeter. Kernel log proof: `Out of memory: Killed process ... (quickshell) anon-rss:6977652kB`.

Rules:
- Any preview/thumbnail `Image` MUST set `sourceSize` (see `modules/picker/ui/PickerTile.qml`: 256×160).
- Gate `source` on visibility (`root.visible ? url : ""`) so off-screen delegates never decode.
- Remember: components inside always-instantiated singletons/panels run at startup even when "closed" — a Repeater there creates ALL delegates immediately once its model populates.

After fix: same panel + 194 tiles = ~365 MB RSS total shell footprint.

### 2. awww-daemon socket race
A fixed `sleep 0.4` after spawning the daemon raced daemon startup and dropped paints silently. Pattern that works (Wallpaper.qml): spawn detached via `setsid`, then retry `awww img` up to 8× with 0.25 s gaps.

### 3. Quickshell FileView semantics (confirmed working)
- `JsonAdapter` + `writeAdapter()` persists structured prefs (ShellState pattern).
- `setText()` on a plain FileView stages AND writes (genConfigFile writes matugen.toml this way).
- `watchChanges: true` + reload-on-callback = live theme recolor without touching module code.

### 4. QML gotchas hit so far
- Binding to a JS function call (`readonly property var x: Singleton.fn()`) DOES re-evaluate when properties read inside fn change — used for the template list, but it recreates every delegate on any persist. Fine for small lists; don't use for big ones.
- Offscreen platform (`QT_QPA_PLATFORM=offscreen`) cannot create PanelWindows — validation must run against the live Wayland session with `timeout`.
- **Flickable/GridView/ListView reparent declared children into `contentItem`** — anything declared inside scrolls away with the content. Scroll indicators, edge fades, overlays MUST be siblings positioned over the scroll area, not children of it. (Bit us in both picker grid and settings pages.)
- Binding `Flickable.contentHeight` to `loader.item.childrenRect.height` is a binding loop; use `loader.item.height` (Column/implicitHeight) instead.
- A `Loader` per tab (lazy pages) keeps heavy lists from building at startup and stops scroll offsets leaking between tabs.
- **Declare `required property var modelData` exactly ONCE.** Having it both in the delegate component's root (TemplateRow.qml) and again in the inline delegate wrapper produces `Cannot create delegate / Required property modelData was not initialized` for every row — silently, at runtime only.
- Host items whose default property aliases children elsewhere (YRow's `trailingHost`) must NEVER size themselves from `childrenRect` while children anchor to them — instant binding loop. Give the host an explicit consumer-set width (`YRow.trailingW`).
- **`IconImage` needs `implicitSize`, not width/height** — it wraps an inner Image and only sizes via `implicitSize`; width/height alone renders blank. `status` is aliased, so `status === Image.Error || Image.Null` drives the acid-initials fallback for apps with no theme icon. Missing icons still WARN in the log (`Cannot open: qrc:/.../<app-id>`) — that noise is expected fallback behavior, not a bug.
- Quickshell single-window components (no explicit `screen`) map on the primary monitor; a second instance's bars get exclusive-zone-pushed to y=44 under the first instance's bar — don't misread stacked test-instance layers as a bug.
- **Assigning `Process.command` does NOT start it** — unlike the one-shot patterns where we set both, a Process only runs when `running: true` is set (before or after command). Symptom: silent no-op, no stderr, nothing.
- **`StdioWriter` does not exist** in Quickshell 0.3.1. To write a file from QML and then move it with shell: FileView (`setText` + `atomicWrites`/`blockWrites`) → `onSaved:` → Process `cp`. See snipStage/snipCopier in Wallpaper.qml.
- **A duplicate property assignment anywhere in a file kills the WHOLE config load** ("Property value set multiple times" + cascading `Type unavailable` up the whole import tree) and the instance **exits instantly** — which makes `pgrep -n` silently fall through to the user's live instance. Always capture the spawn PID explicitly; never pgrep for test driving.
- `console.log` emitted during Singleton boot (`Component.onCompleted`) does not reach nohup-captured stderr; `console.warn` does. Use warn for boot-phase diagnostics.
- **Singletons instantiate lazily on first access.** An IPC call right after spawn can race the singleton's `Component.onCompleted` (e.g. the binary probe). Warm up with an innocent list/read call before asserting on state.
- QtQuick.Shapes arc direction is `PathArc.Clockwise` / `PathArc.Counterclockwise` — there is no global `ArcDirection`.
- `IconImage.source` needs real URLs; desktop-entry icon *names* render as blank qrc misses. Resolve via **`Quickshell.iconPath(name)`** (variants `(icon)`, `(icon,checkExists)`, `(icon,fallback)`); keep the status-driven initials fallback for apps without theme icons.
- Binding `contentHeight` to `loader.item.height` can **latch onto a dying item** across `sourceComponent` switches and go permanently stale (scroll dead until restart). Sync imperatively in one function called from page switches AND a retargetable `Connections { target: loader.item }` watching height changes.
- A row-level MouseArea that spans the full row **eats clicks meant for trailing slots** (switches/buttons anchored into a host item). Constrain its right edge to `trailingHost.left`.
- **Anchored Loaders STRETCH their loaded root item** to the Loader's own size even when that root declares explicit width/height — this silently rendered the launcher/picker cards fullscreen for weeks. When a loaded component must keep its own geometry, wrap it: `Component { Item { id: filler; anchors.fill: parent; readonly property alias surface: card; YSurface { id: card ... } } }` and point input masks at `uiLoader.item.surface`, never at the filler.
- **This Qt build's JS engine lacks `String.trimStart`/`trimEnd`** — error signature: `Property 'trimStart' of object  is not a function` (the blank is an empty-string receiver). Use `.replace(/^\s+/, "")`.
- **The user's wallpaper is animated**: two arbitrary screenshots of the same idle desktop differ by ~2M pixels. Screenshot pixel-diffing CANNOT verify shell rendering on this machine — log geometry from QML (`console.warn` + delayed Timer) instead.
- **`Qt.callLater` samples PRE-compositor-configure**: window/contentItem sizes read as 0×0 or defaults in the tick when `visible` flips true. Probe real geometry from a Timer ≥500 ms after open.
- **A `QtObject` root has NO default property** — child objects (Timer/Process) inside a QtObject-rooted singleton fail with `Cannot assign to non-existent default property`. Use Quickshell's `Singleton` type as the root instead (it accepts children); keep QtObject only for childless singletons.
- **qmldir must declare `singleton <Name> 1.0 <File>.qml` for EVERY pragma-Singleton file** — a singleton listed as a plain type resolves but property reads on it yield `[undefined] to bool` warnings and dead bindings (bit NightLight/DisplayService in modules/audio/qmldir).
- **No `Quickshell.primaryScreen` in 0.3.1** — use `Quickshell.screens.length > 0 ? Quickshell.screens[0] : null`.
- **`anchors.fill/left/right` inside a `Row`'s direct children warns "Row will not function"** — Rows position by x; children that need full-size overlays must use explicit `width: parent.width; height: parent.height`.
- **Auto-changed signals for underscore properties**: `property var _dispList` → handler is `on_DispListChanged` (first letter after the underscore capitalizes). Guessing `on_DisplaysChanged` fails as `non-existent property`.

### 4b. Surface architecture (layer sandwich + YSurface)
- **Bar → `WlrLayershell.layer: WlrLayer.Overlay`** (topmost); ALL popup windows (settings/picker/launcher) → `WlrLayer.Top`. Anything sliding from negative-y emerges from behind the bar — this is the shell's signature entrance.
- **No scrims anywhere by default**: popups are fullscreen transparent PanelWindows; input is confined to the card via `mask: Region { item: open ? <cardItem> : null }`. Desktop around the card stays visible AND clickable. Closing is ESC / keybind / IPC only. Panels keep the window alive ~190 ms after close (`hideDelay` Timer + `open || hideDelay.running` visible binding) so the exit ceremony renders; the mask nulls instantly so input passes through immediately.
- **YSurface kit component owns the choreography** (`modules/common/ui/YSurface.qml`): restY = barHeight + restGap, hiddenY = −height−12, enter movSlow(260) OutBack(0.12)/exit movMed OutCubic, bgAlt card + lineStrong border + acid corner tick + swallow MouseArea. Every new floating surface composes YSurface instead of re-animating by hand.
- **FastWheel** (`modules/common/ui/FastWheel.qml`) is the standard wheel handler for every Flickable/GridView/ListView — drop-in child, notchStep 132, clamped. Plain Flickables scroll too slowly without it.

### 4b+. YSurface entrance ritual, exit ceremony & cascade
- Every popup gets, free of charge: drop from behind the bar with a slight OutBack overshoot into the flush socket, one acid scanline sweeping down the face, border burning acid → cooling to lineStrong (~230 ms), family tick drawing down the left edge, and the **power line** (2 px acid bottom edge) drawing left→right. On close it runs backwards: outro scanline returns up as the card lifts. Driven by `onOpenChanged` inside YSurface; consumers do nothing.
- **Content cascade**: set `cascade: <content Item>` on YSurface; on open (after a 140 ms revealDelay) its direct children stagger-rise (26 ms apart, opacity + Translate y14→0). Dynamic KidAnim instances are created via `Component { id: kidAnim; SequentialAnimation {...} }` + `createObject` — **inline `component X:` types cannot be createObject'd directly**; they need a Component wrapper. Transforms are destroyed in `onStopped`. Children that expose a `reveal()` function get it connected to their animation's `started` signal (YSection draws its hairline rule via Scale.xScale from the left — never animate `width` of an anchor-positioned item).
- Launcher/picker deliberately skip content cascade (transient tools must be ready to type); they still carry the full card ritual.

### 4b++. Organism layer ("the machine is alive")
- The binding spec lives at the top of ROADMAP.md (VIBE CHARTER). Implementation inventory: `YPulse.qml` (opacity breathing, lo 0.62, movDrift) for idle chrome pulses — currently the bar's 132 px acid strip; media equalizer bars + net-arrow activity flashes + BT scan blink + breathing clock colon in the bar; kit interrogation language (YSwitch fill-wipe + OutBack knob 0.45, YButton hover underline, YRow hover wipe + tick growth + sub→note crossfade, YField focus underline, YChip label pop, YScroll sleeping rails); toast stagger (70 ms/card) + retire-based exit send-off.
- Perf guardrails: animations gate on `visible`; pulses are opacity-only; staggered reveals clean up their dynamic objects; transforms over layout properties where possible.

### 4c. Template snippet engine (Wallpaper.qml)
- Toggling an include-style template edits the TARGET APP's config itself (managed `# >>> yutashell-matugen` blocks), serialized through `_snipQueue` → reader Process → staged FileView → copier Process.
- **TOML configs cannot take appended include lines**: duplicate top-level keys are invalid, and bare keys appended after table headers land inside the LAST table (alacritty's `import` ended up in `[cursor]`). The alacritty rule uses `mode: "toml-import"` — merge our path into the existing single-line `import = [...]`, else insert after `[general]`, else append a managed `[general]` block. OFF reverses all three byte-exactly.
- Startup binary probe (`binProbe`) maps catalog ids → installed apps; absent apps refuse to enable and are auto-pruned from stale enabled state.

### 5. Quickshell FileView drops overlapping operations
Back-to-back `writeAdapter()` / `setText()` / `reload()` calls within a few hundred ms overlap internally and get **silently dropped** (warning: `got operation finished from dropped operation`). Symptoms seen: IPC bursts losing writes, template toggles never landing. Fixes shipped:
- `ShellState.set()` coalesces through an 80 ms flush Timer; `Wallpaper.writeGenConfig()` same with 100 ms.
- Startup seeding only writes adapter when the state file is absent AND empty — a transient read race must never clobber user prefs with defaults.
- When scripting e2e tests, keep ≥0.5 s between mutating IPC calls even with coalescing.

### 6. matugen 4.x + TOML config generation
- matugen **hard-fails without a TTY** when several source colors are candidates ("Multiple source colors found..."). Always pass `--source-color-index 0` when invoking non-interactively.
- TOML **literal strings (`'…'`) do not support `''` escaping** — that's basic-string syntax only; `'a '' b'` fails to parse. Generate values as multiline literals `'''…'''` instead (no escape processing, tolerates quotes/newlines; just never emit a literal `'''`).
- Post-hooks with embedded quotes (gsettings, sudoers) only parse via the above.

### 7. Test harness
- Background quickshell between bash-tool calls needs `setsid nohup … < /dev/null & disown`; plain nohup gets reaped when the tool session ends (looks like a mysterious crash — it isn't). The spawn command may still hold the tool session's pipe open past its timeout even with redirects — outputs arrive anyway; run spawns in their own short-timeout call.
- `console.log` from QML does NOT reliably reach nohup-captured stderr — stream logs with `qs -p <path> log > file &` and read that file.
- Bare `qs ipc call …` fails when the instance was launched with an explicit `-p` path — always pass the same `-p`.
- Template ids are catalog ids (`kitty`, not `kitty.conf`).
- **`qs ipc` without `--pid`/`--id` targets exactly ONE instance per config path (the first found — usually the user's live shell), it does NOT broadcast.** Discovered when a spawned test instance never reacted to path-targeted calls while the live instance did all the work. To drive a specific instance: `qs ipc --pid <pid> call <target> <fn>` (or `-i <id-substring>`). Consequence: mutating verification calls via bare `-p` targeting DO hit the user's live session — note their prefs from logs first and restore after, or target the test PID directly.
- **NEVER `pkill -f "quickshell -p <path>"`** — that pattern matches the user's live instance too (it runs the same `-p`). Record the test instance's PID at spawn time (`$!` from the setsid call) and kill that exact PID. This actually bit once: a pattern-kill took down the live session's shell mid-test; it was restarted manually.
- Failed-config instances exit instantly — `pgrep -n` then returns the USER'S live shell and your IPC hits it instead. Capture the spawn PID at spawn time and pass `--pid <that>` everywhere.
- Editing QML while an instance runs triggers hot-reload mid-edit-sequence: saving a caller before its callee produces transient `ReferenceError`s in the running shell's log. Don't chase those in log captures — they're edit-order artifacts, not code bugs. Verify against a freshly spawned instance instead.

### 8. Notification daemon lifecycle (modules/notify)
- **`Notification.actions` is a plain JS array** — iterate `n.actions[i]` directly; there is NO `.values` (that's ObjectModel syntax from other services). `n.actions.values` resolves to Array.prototype.values and returns an iterator; `.map` on it throws `Property 'map' of object [object Array Iterator] is not a function`.
- **The C++ side enforces the client's expireTimeout independently of `tracked`.** When it wins the race, our later `expire()`/`dismiss()` logs `Cannot close destroyed notification`. Fixes shipped: (a) effective timeout shrunk by a 300 ms margin so WE always close first; (b) `n.closed.connect(() => vm.dead = true)` marks liveness — check `dead` before closing; (c) NEVER touch the notification object after close, not even `tracked = false` — property writes on destroyed wrappers log the same error.
- A hot-reloaded instance can hold a **zombie bus registration**: mid-edit reloads leave org.freedesktop.Notifications owned by a stale internal server that answers GetCapabilities but never fires `notification` into current QML. Symptom: notify-send succeeds (id returned), zero history. Fix: restart the instance; verify ownership with `busctl --user list | grep Notifications`.
- Directory qmldir makes imports STRICT: once `modules/<x>/qmldir` exists, only types declared there import — non-singleton windows must be listed too (`ToastStack 1.0 ToastStack.qml`).
- state.json is written through ShellState's coalescing flush but NOT watched for external edits — injecting JSON behind a running instance changes nothing in memory. Test overrides/prefs via IPC or restart.
- Toast cards must be stable across the 100 ms countdown tick: live entries are in-place QtObjects (`component Entry: QtObject`) mutated field-by-field; reassigning a plain JS array per tick would recreate every delegate and kill hover-pause mid-countdown.

### 9. The live shell is `qs`, not `quickshell` — and it hot-reloads your edits (read this before testing)
This machine's session runs the shell as **`qs -c yuta-qs`** (pid name `qs`, started via Helmsman autostart — NOT `quickshell`). Consequences that cost hours of phantom debugging:
- `pgrep -a quickshell` / `pgrep -x quickshell` find NOTHING even while the shell is up. Check `pgrep -af 'qs -c'`.
- It **hot-reloads on every file edit**. Editing QML mid-thought produces a stream of transient `Failed to load configuration` / `Property value set multiple times` / `<Type> is not a type` errors in ITS log — these are edit-order artifacts against the live instance, NOT bugs in your settled code. Always re-check after the dust settles.
- `quickshell -p . log > file` **attaches to the existing instance's buffered log** when one is running (same Shell ID = config-path hash), streaming its HISTORY first. So a "fresh spawn" shows the live shell's old mid-edit errors. The authoritative, current-state log is `/run/user/1000/quickshell/by-id/<id>/log.log` (or `by-pid/<pid>`), not the stderr you captured.
- To actually test fresh, you must have zero running instances — which means briefly stopping the user's session shell, which is disruptive. Prefer reading `log.log` tail + relying on the clean-load signal after edits settle.

### 10. Click-outside-to-close (the new surface language)
`YClickAway.qml` (`modules/common/ui/`) is a fullscreen transparent `MouseArea` that emits `outsideClicked`. The pattern per floating panel:
1. `mask: Region { item: <open> ? clickAway : null }` — the WHOLE window accepts input while open (previously the mask was the card, so outside clicks passed through).
2. Declare `YClickAway { id: clickAway; onOutsideClicked: <close> }` as the FIRST child of the content root, with the card (YSurface) AFTER it.
3. YSurface's own swallow `MouseArea` keeps in-card clicks from reaching the catcher; only genuine outside clicks close.
This deliberately supersedes the old "scrim abolition / desktop stays clickable" behavior — the user asked for outside-click = close. PolkitDialog + LockScreen stay modal (security surfaces). ToastStack/Osd/Dock don't use it (passive/transient/bar).

### 11. Session-phase bug notes (all shipped)
- **`WlSessionLockSurface.screen` is null until the compositor assigns it** — the old `visible: Session.lockScreenSelected(screen.name)` threw `TypeError: Cannot read property 'name' of null` on every boot. Guard: `screen !== null && …`.
- **`Keys.on*Pressed` handlers must declare `event`** — `Keys.onUpPressed: if (x) { event.accepted … }` logs `Parameter "event" is not declared` (deprecated injection). Use `Keys.onUpPressed: event => { … }`.
- **Never call `applyWallpaperTokens()` synchronously after `FileView.reload()`** — reload is async, so the immediate read saw an empty file and logged `theme.json unreadable: Parse error` on EVERY load. Rely on `wallThemeFile.onLoaded` instead (it already re-applies when `followWallpaper`).
- `Process` works fine in the session module with `import Quickshell.Io` — the earlier "Process is not a type" was a transient mid-edit reload, not a real API gap.

### 12. Settings panel now has 8 tabs (DOCK + SYSTEM are real)
`SettingsPanel.pages` is the declarative registry; each page is a lazy `Loader` behind a `switch (activePageId)`. New tabs: **DOCK** (enable/mode/hide/monitors) and **SYSTEM** (power plan, idle action+timeout, hold-to-confirm, lock scope, inhibit chip, avatar). Tab labels elide to survive narrow panel widths. The `systemPage` "planned" stub is gone — no placeholders remain in shipped phases.

### 13. SystemStats is the one sampler (PH.13) — never add a second
`modules/common/SystemStats.qml` owns every periodic read of `/proc`, `/sys/class/hwmon` and `nvidia-smi`. Two poll classes: FAST 2 s (cpu/mem/net/load/uptime via FileView), SLOW 5 s (disk/hwmon-temps/nvidia-smi/battery via Process). `StatsCluster.qml` is now a thin consumer — its old FileViews/Timer are deleted. Rule: **any new stat reader binds to `SystemStats.*`, never opens its own FileView/Timer over those files.** Threshold signals (`warnRaised`/`critRaised`) fire once per crossing per kind. `fmtRate`/`fmtBytes`/`fmtTime`/`fmtTemp` are the shared formatters (move any format drift here).

### 14. Widgets (PH.11) + graceful degradation + Health
- `modules/widgets/` holds each PH.11 widget as either a **singleton service** (Clipboard/Weather/Screenshot/Updates/Recording/ColorPicker) or a **PanelWindow** (Calendar/ClipboardPanel/WeatherPanel/Emoji/ShotFlash). Each service probes its backend binary once at boot via a `Process command -v` and exposes `available`; every consumer hides or shows a flat "not installed" message when `available` is false — **never a dead button**.
- Absences report to the `Health` singleton (`modules/common/Health.qml`): `Health.report(module, msg)` / `Health.clear(module)`. The bar shows a `!` chip while `Health.count > 0` (tooltip = `Health.summary`, click opens settings). Add a `Health.report` call in any new backend's probe so degradation is never silent.
- **Warm lazy singletons at boot.** Services referenced only from IpcHandlers instantiate on first IPC call, which races their async binary probe (first `status` returns "unavailable"). shell.qml has a boot `Timer` that reads each `*.available` + `SystemStats.hostname` to force instantiation at boot.
- **`shell.qml` needs `import QtQuick`** for `Timer`/`QtObject` — it's the only file that didn't import it (was added for the warm-up timer). Other singletons need `import Quickshell` for the `Singleton` base type (Health.qml hit `Singleton is not a type` without it).
- cliphist 0.7 `list` output is `id<TAB>preview`; binary (image) entries carry raw bytes in the preview — detect via control chars and surface as IMAGE rows. `cliphist decode <id> | wl-copy` re-copies; `cliphist delete <id>` removes.
- `qs ipc call <target> show` collides with quickshell's built-in target listing — name list functions `list`, not `show`.

### 15. Bar v2 segments + control center + settings v4 (PH.14-16)
- **The bar is data-driven now.** `ShellState.barSegments` is an ordered `[{id,zone,enabled}]` array; `BarSegments` (singleton in `modules/bar/`) parses it and answers `leftVisible`/`rightVisible`/`centerVisible` (runtime visibility = enabled AND the segment's live condition) plus `present(id)`, `clickFor(id)` and the mutation helpers. `Bar.qml` renders three zones via `Repeater` + `Loader` with a divider on `index > 0`. `BarActions.dispatch(action)` maps click-actions (calendar/network/…/`ipc:target/fn`). New segments only need a Component in Bar.qml + a `BarSegments.meta` entry + a `present()` case.
- **Modules with `pragma Singleton` need a qmldir** declaring `singleton X 1.0 X.qml`. Adding one to `modules/bar/` made its imports strict — every top-level type is now listed there. Sub-directory `ui/` types (DividerV) stay a relative `import "ui"`.
- **Height-only scaling**: the bar's content uses `transform: Scale { yScale }` (xScale stays 1) so the bar thickens without changing width.
- **Control center** (`modules/control/ControlCenter.qml`): 11 lazy tabs behind a `switch`, tab order/visibility from `ShellState.ccTabs` (a JSON id array), anchor from `ccAnchor`. Tab state that needs per-tab `Timer`s (SYSTEM sparklines) gates on `activePageId === "x" && ShellState.ccOpen`.
- **Settings v4**: two-level nav rail (`groups` + `pages` with a `group`/`keywords` field each) + `searchQuery` filters the rail via `matchesQuery(p)` (label/jp/keywords). Content area shifted right of the rail by `railW`. A Repeater delegate that *redeclares* a host type's own property (e.g. `readonly property bool on_` inside a `YRow` delegate) → `Property value set multiple times`; use a fresh name and bind the host property to it.
- **Nav-rail rows MUST NOT sit inside a Flickable** — the Flickable's gesture handling swallowed the row `MouseArea` clicks (the panel could only be navigated with TAB). Use a plain `Column` of groups/rows (the rail fits the card height); `clip: true` on the rail Item guards short panels. Same rule for any tight, always-visible click strip; only wrap in a Flickable when the content genuinely scrolls.
- **Don't reference a window type's instance from another file** — `MediaWidget.player` (a PanelWindow *type*) is `undefined`; resolve MPRIS directly (`Mpris.players.values`). The control center carries its own `player`/`playing`.
- **`Cannot display PlatformMenuEntry … not in QApplication mode`** is a real limitation of the SNI tray's native menu in non-QApplication mode — `shell.qml` now carries `//@ pragma UseQApplication` to fix it, but **the pragma only takes effect on a fresh start** (hot-reload keeps the old mode, so the error still logs mid-session until the shell restarts).

## Conventions (enforced)

- Colors/fonts/metrics ONLY from `Theme.*`. No hardcoded colors in modules — this is what makes live recoloring free.
- **UI primitives ONLY from the kit** (`modules/common/ui`): YButton / YSwitch / YRow / YSection / YField / YChip / YScroll. Never hand-roll a button, row, switch, or section header inside a panel — compose the kit. This is what makes both panels feel like one object.
- Type ramp from Theme only: `fsDisplay > fsTitle > fsBody > fsLabel > fsMicro`. Body copy is **sentence case** at fsBody; UPPERCASE + wide tracking is reserved for micro-chrome (nav rail, chips, section labels). If text at fsMicro carries information the user needs, it's at the wrong size.
- Acid is semantic: active state, focus, primary CTA, status ticks. Never decoration. Acid may PULSE/DRAW/SWEEP (it's the living tissue) but only where it carries meaning.
- Motion: hover/focus snap instantly (`movSnap`); positional indicators animate `Theme.movFast`/`movMed` OutCubic; idle life pulses at `movDrift` and is opacity-only — never pulse text. YButton's hard-shadow press collapse is the one allowed "physical" flourish.
- Floating surfaces MUST compose YSurface (card ritual + exit ceremony + power line + optional `cascade`) — never re-animate a popup by hand.
- Scroll indicators are SIBLINGS over their Flickable via `YScroll { target }` — never children (contentItem reparenting).
- User-facing actions go through IpcHandlers (keybinds + CLI + settings panel share one implementation). IPC surface documented in README "Keybinds & IPC".
- Persistence only through `ShellState.set(key, value)` → state.json.
- Compositor dispatches through wrapper functions (Helmsman Lua form), never inline strings.
- Japanese labels gated behind `Theme.jpEnabled` with romaji fallback.

## Testing protocol

The live shell runs as `qs -c yuta-qs` (see lesson 9) and hot-reloads edits, so the cleanest smoke test is to tail its authoritative log after edits settle:

```
tail -n 30 /run/user/1000/quickshell/by-pid/$(pgrep -f 'qs -c')/log.log   # clean-load signal
ps -o rss -p $(pgrep -f 'qs -c')                                          # RSS sanity (~250-500 MB)
qs ipc -c yuta-qs call panel toggle                                       # exercise the panel via IPC
```

To validate all settings pages build, spawn `YUTA_DEBUG_CYCLE=1` — but that needs a truly fresh instance (zero others running), which means briefly stopping the session shell.

Watch RSS after model-heavy panels open. If it climbs into GBs, something is decoding full-res again or leaking delegates.
