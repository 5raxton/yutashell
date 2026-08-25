# Plugins

Drop a folder under `plugins/<your-plugin>/` with a `plugin.json` manifest and a QML entry component. Plugins can import the shell's own kit (`qs.theme`, `qs.modules.common.ui`).

## Manifest

```json
{
    "id": "my-plugin",
    "name": "My Plugin",
    "version": "1.0.0",
    "type": "widget",
    "component": "main.qml"
}
```

Optional fields: `description`, `author`, `icon`, `settings[]`, `permissions[]`.

## Types

### `widget`

A `Rectangle`-rooted QML component rendered inside the bar's PLUGIN WIDGETS segment. Keep it bar-height; the shell sizes the segment around natural content width.

```qml
import QtQuick
import qs.theme

Rectangle {
    implicitWidth: label.implicitWidth + 24
    implicitHeight: Theme.barH - 12
    radius: 2
    color: Theme.bg

    Text {
        id: label
        anchors.centerIn: parent
        text: "hello"
        color: Theme.acid
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsLabel
    }
}
```

### `daemon`

Instantiated invisibly at boot while enabled — timers, file watchers, IPC bridges, anything headless.

### `bar`

Registers its own bar segment (visible in the BAR Kanban editor) and optionally a floating panel. Manifest fields:

```json
{
    "type": "bar",
    "barSegment": { "id": "my-seg", "label": "My Segment", "jp": "私", "zone": "right" },
    "barComponent": "BarWidget.qml",
    "panelComponent": "MyPanel.qml"
}
```

- `barSegment.id` — unique segment identifier (registered in BarSegments automatically)
- `barSegment.label` / `jp` — display name and optional Japanese label
- `barSegment.zone` — default zone (`left` / `center` / `right`)
- `barComponent` — QML file rendered in the bar (defaults to `BarWidget.qml`)
- `panelComponent` — QML file loaded as a floating PanelWindow + YSurface (optional)

Bar widget components receive `modelData` (the segment object from BarSegments) and should set `implicitWidth`/`implicitHeight` for bar-height rendering. Click the segment to toggle the panel via `BarActions.dispatch("plugin:<id>")`.

The panel is a standard `PanelWindow` + `YSurface` + `YClickAway`. Open state: `PluginService.isPluginPanelOpen("my-plugin")`. Close: `PluginService.closePluginPanel()`. Spawn origin respects PanelSpawn (falls back to default).

## Settings array

An optional `settings[]` in the manifest describes per-plugin options surfaced in Settings → PLUGINS:

```json
"settings": [
    { "key": "announce", "label": "Announce changes to stderr", "type": "bool", "default": true }
]
```

Read the current value from QML through the namespaced data store (the settings UI writes there):

```qml
readonly property bool announce: PluginService.loadPluginData(pluginId, "announce", true)
```

## State persistence

Widgets and daemons persist state across restarts through the same store:

```qml
Component.onCompleted: counter = PluginService.loadPluginData(pluginId, "count", 0)
onCounterChanged: PluginService.savePluginData(pluginId, "count", counter)
```

## Lifecycle

```sh
qs ipc -c yuta-qs call plugins list           # scan state as text
qs ipc -c yuta-qs call plugins rescan
qs ipc -c yuta-qs call plugins enable my-plugin
qs ipc -c yuta-qs call plugins disable my-plugin
qs ipc -c yuta-qs call plugins panel my-plugin # toggle bar plugin panel
```

Or via Settings → PLUGINS (live toggle, no restart needed).

## Reference implementations

- [`plugins/PulseDot/`](../plugins/PulseDot) — widget: pulsing dot keyed to audio output
- [`plugins/WallpaperWatcherDaemon/`](../plugins/WallpaperWatcherDaemon) — daemon: reacts to wallpaper changes
- [`plugins/ArchUpdater/`](../plugins/ArchUpdater) — bar: scans for pacman/AUR/Flatpak updates with panel

> Plugins execute with full shell privileges — only install ones you trust.
