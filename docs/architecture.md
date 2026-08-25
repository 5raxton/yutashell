# Architecture & development

## Layout

```
yuta-qs/
├── shell.qml              entry point, 30 IPC handlers (130+ functions), per-screen instances
├── theme/                 Theme singleton, 12 preset palettes, matugen setup
├── modules/
│   ├── bar/               22 segment types + Kanban drag-drop editor, BarActions dispatcher
│   ├── common/            ShellState, Wallpaper/89-template pipeline, SystemStats,
│   │                      PluginService, FocusMonitor, Compositor, Health, 13 UI primitives
│   ├── settings/          settings panel (15 pages behind searchable nav rail)
│   ├── control/           control center (11 tabs)
│   ├── launcher/          app launcher (grid/list/detail + :command mode + calculator)
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
├── plugins/               reference widget + daemon plugins
└── docs/                  these pages
```

## Design rules

- **One theme source** — colors/fonts/metrics only via `Theme.*`; that's what makes live recoloring free
- **One sampler** — `SystemStats` is the single stats reader; widgets bind to it instead of opening their own `/proc` watchers
- **Shared choreography** — every floating surface composes the `YSurface` primitive: one entrance ceremony, flare shoulders toward its spawn seam (bar / top edge / bottom edge / float), click-outside catcher
- **Graceful degradation** — optional backends are probed at startup; missing features report through a `Health` singleton shown as a `!` chip in the bar instead of failing silently
- **Single action path** — keybinds, CLI and panel buttons all route through the same IPC handlers

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
