pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

// Weather (PH.11) — open-meteo fetch via curl, cached to
// ~/.local/state/yutashell/weather.json so a cold boot still shows the last
// conditions. Location comes from Geo (IP-locate or manual coords); units
// follow ShellState.weatherUnit (celsius|fahrenheit). Refreshes every 30 min.
Singleton {
    id: root

    readonly property bool available: _probed && _curlOk && Geo.configured
    property bool _curlOk: false
    property bool _probed: false

    // display label for the effective location (manual override or IP city)
    readonly property string locLabel: Geo.locLabel

    readonly property bool configured: Geo.configured

    property bool fetching: false
    property string error: ""
    property date lastFetch: new Date(0)

    // staged write for cacheFile — coalesces setText calls from async callbacks
    property string cacheCache: ""
    Timer {
        id: cacheFlush
        interval: 100
        onTriggered: {
            if (root.cacheCache.length > 0) {
                cacheFile.setText(root.cacheCache);
                root.cacheCache = "";
            }
        }
    }

    // current conditions
    property var current: null   // {temp, code, wind, time}
    property var forecast: []    // [{date, max, min, code}]

    function refresh() {
        if (!root.configured || !root.available)
            return;
        // auto mode still resolving — Geo fires refresh when it lands
        if (Geo.latStr.length === 0 || Geo.lonStr.length === 0)
            return;
        // an in-flight curl would lose the command reassignment anyway
        if (root.fetching)
            return;
        root.fetching = true;
        fetchProc.command = ["curl", "-s", "--max-time", "10",
            "https://api.open-meteo.com/v1/forecast?latitude=" + Geo.latStr + "&longitude=" + Geo.lonStr + "&current_weather=true&daily=temperature_2m_max,temperature_2m_min,weathercode&timezone=auto&temperature_unit=" + ShellState.weatherUnit + "&forecast_days=5"];
        fetchProc.running = true;
    }

    // WMO weather code → { glyph, label }
    function codeInfo(code) {
        const c = Number(code);
        if (c === 0)
            return ["☀", "CLEAR"];
        if (c <= 3)
            return ["◐", "PARTLY CLOUDY"];
        if (c === 45 || c === 48)
            return ["≡", "FOG"];
        if (c >= 51 && c <= 57)
            return ["∴", "DRIZZLE"];
        if (c >= 61 && c <= 67)
            return ["≋", "RAIN"];
        if (c >= 71 && c <= 77)
            return ["❄", "SNOW"];
        if ((c >= 80 && c <= 82) || c === 85 || c === 86)
            return c === 85 || c === 86 ? ["❄", "SNOW SHOWERS"] : ["▽", "SHOWERS"];
        if (c >= 95)
            return ["⚡", "STORM"];
        return ["·", "—"];
    }

    function _parse(raw) {
        try {
            const j = JSON.parse(raw);
            const cw = j.current_weather ?? {};
            root.current = {
                temp: Math.round(cw.temperature ?? 0),
                code: cw.weathercode ?? 0,
                wind: Math.round(cw.windspeed ?? 0),
                time: cw.time ?? ""
            };
            const d = j.daily ?? {};
            const times = d.time ?? [];
            const maxs = d.temperature_2m_max ?? [];
            const mins = d.temperature_2m_min ?? [];
            const codes = d.weathercode ?? [];
            const out = [];
            for (let i = 0; i < times.length; i++)
                out.push({
                    date: times[i],
                    max: Math.round(maxs[i] ?? 0),
                    min: Math.round(mins[i] ?? 0),
                    code: codes[i] ?? 0
                });
            root.forecast = out;
            // a cached payload carries its true fetch time — stamping "now"
            // would make days-old data read as fresh
            root.lastFetch = j._fetchedAt ? new Date(j._fetchedAt) : new Date();
            root.error = "";
            // cache the raw payload (with fetch timestamp) for boot-time
            if (!j._fetchedAt)
                j._fetchedAt = Date.now();
            cacheCache = JSON.stringify(j);
            cacheFlush.restart();
        } catch (e) {
            root.error = "parse error";
        }
    }

    Component.onCompleted: {
        binProbe.command = ["sh", "-c", "command -v curl >/dev/null 2>&1 && echo yes || echo no"];
        binProbe.running = true;
        // seed from cache if present
        try {
            if (cacheFile.text().trim().length > 0)
                root._parse(cacheFile.text());
        } catch (e) {
        }
    }

    Process {
        id: binProbe

        stdout: StdioCollector {
            onStreamFinished: {
                root._probed = true;
                root._curlOk = text.trim() === "yes";
                if (root._curlOk && root.configured)
                    root.refresh();
            }
        }
    }

    Process {
        id: fetchProc

        stdout: StdioCollector {
            onStreamFinished: {
                root.fetching = false;
                root._parse(this.text);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0)
                    root.error = this.text.trim();
            }
        }
    }

    FileView {
        id: cacheFile

        path: (Quickshell.env("HOME") ?? "") + "/.local/state/yutashell/weather.json"
        printErrors: false
        blockLoading: true
    }

    // Geo resolved (or mode flipped) — pull weather for the fresh coords
    Connections {
        function onReadyChanged() {
            if (Geo.ready)
                root.refresh();
        }

        target: Geo
    }

    // refresh every 30 min
    Timer {
        interval: 1800000
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refresh()
    }
}
