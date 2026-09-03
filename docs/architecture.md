# Architecture & development

## Layout

```
yuta-qs/
├── shell.qml              entry point, 39 IPC targets (IPC-driven actions), per-screen instances
├── theme/                 Theme singleton, 12 preset palettes, matugen setup
├── modules/
│   ├── bar/               21 segment types + Kanban drag-drop editor, BarActions dispatcher
│   ├── common/            ShellState, Wallpaper template pipeline, SystemStats,
│   │                      PluginService, FocusMonitor, Compositor, Health, 13 UI primitives
│   ├── settings/          settings panel (17 pages behind searchable nav rail)
│   ├── control/           control center (11 tabs)
│   ├── launcher/          app launcher (grid/list/detail + prefix modes + calculator)
│   ├── picker/            wallpaper archive
│   ├── notify/            notification daemon, toasts, history center
│   ├── net/               network + bluetooth panels, bar chips
│   ├── audio/             PipeWire service, audio console, OSDs, media,
│   │                      night light, display brightness
│   ├── session/           power menu, lock screen, idle, polkit dialog
│   ├── dock/              bottom dock
│   ├── overview/          workspace grid, alt-tab, tile presets
│   └── widgets/           calendar, weather, clipboard, screenshots,
│                          emoji, updates, recording, color picker, storage monitor
├── plugins/               reference widget + daemon plugins
└── docs/                  these pages
```

## Design rules

- **One theme source** — colors/fonts/metrics only via `Theme.*`; that's what makes live recoloring free
- **One sampler** — `SystemStats` is the single stats reader; widgets bind to it instead of opening their own `/proc` watchers
- **Shared choreography** — every floating surface composes the `YSurface` primitive: one entrance ceremony, flare shoulders toward its spawn seam (bar / top edge / bottom edge / float), click-outside catcher
- **Graceful degradation** — optional backends are probed at startup; missing features are hidden or report through the internal `Health` singleton instead of failing silently
- **Single action path** — keybinds, CLI and panel buttons all route through the same IPC handlers
- **Accessibility** — `Theme.reducedMotion` snaps all animation durations to 0 (toast entrance excluded at 80 ms); `Theme.highContrast` overrides palette tokens for maximum contrast; all UI primitives support Tab/Shift+Tab focus cycling and Enter/Space activation

## Accessibility (PH.10)

- `Theme.reducedMotion` — persisted in `ShellState.reducedMotion`; when true, all `mov*` tokens become 0; `Behavior on` blocks evaluate to instant transitions
- `Theme.highContrast` — persisted in `ShellState.highContrast`; overrides ink/bg to pure black/white, sets muted/faint/hairline/lineStrong to maximum contrast; acid accent preserved
- **Focus ring** — all interactive UI primitives (`YButton`, `YSwitch`, `YField`) have `activeFocusOnTab: true` and show an acid border on keyboard focus; Enter/Space activates the focused element
- Settings → A11Y page with reduced motion toggle, high contrast toggle, and keyboard navigation reference

## Hyprland

The shell drives Hyprland through the Lua dispatcher's `hl.dsp.*` API rather than raw dispatch strings — window/workspace actions go through small wrapper functions in:

- `modules/bar/Workspaces.qml`
- `modules/dock/Dock.qml`
- `modules/overview/Overview.qml`
- `modules/common/FocusMonitor.qml`, `modules/common/Compositor.qml`

Porting the handful of wrappers to raw dispatches is straightforward.

Runtime compositor config uses `hyprctl eval '<lua>'` with nested Lua tables mirroring option paths. The `compositor` IPC target reports capability and offers a warm-client passthrough (`qs ipc call compositor dsp '<lua>'`) — cold one-shot evals can't run `hl.dsp.*` forms.

## Development workflow

```sh
make lint-qml   # qmllint gate (fails on syntax errors)
make test       # integration smoke test: spawns an isolated instance,
                # drives the IPC surface, greps the log, checks RSS
make dist       # release tarball
```

Notes:

- Quickshell hot-reloads every file edit; verify settled code against a freshly spawned instance since mid-edit reloads show transient errors.
- The smoke test refuses to run while another instance is live and always terminates the instance it spawns.
- User state lives outside the repo (`~/.local/state/yutashell/`) — test instances share it, so revert any preference mutations you make while poking at a test instance.
