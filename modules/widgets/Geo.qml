pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

// Location resolution — feeds weather + timezone display. Two sources:
//
//  auto    IP geolocation via ipwho.is (fallback ip-api.com), cached to
//          geo.json so a cold boot has an answer immediately, re-resolved
//          every 6 h while the mode stays auto.
//  manual  ShellState.weatherLat/Lon/Label exactly as before.
//
// Mode selection lives in ShellState.weatherMode:
//   ""        legacy behavior — manual wins when coords are set, else auto
//   "auto"    force IP geolocation
//   "manual"  force static coords
// Consumers read ONLY the effective accessors (configured/latStr/lonStr/
// locLabel/tz) — never the raw prefs.
Singleton {
    id: root

    readonly property bool available: _probed && _curlOk
    property bool _curlOk: false
    property bool _probed: false

    readonly property bool modeManual: ShellState.weatherMode === "manual" || (ShellState.weatherMode === "" && String(ShellState.weatherLat).length > 0 && String(ShellState.weatherLon).length > 0)
    readonly property bool modeAuto: !modeManual

    // resolved geo state (auto path)
    property bool resolving: false
    property bool ready: false // geo.json seeded or live resolution landed
    property real glat: 0
    property real glon: 0
    property string glabel: ""
    property string gtz: ""
    property real gfetchedAt: 0
    property string error: ""

    // ---- effective accessors -------------------------------------------
    readonly property bool configured: modeManual ? (String(ShellState.weatherLat).length > 0 && String(ShellState.weatherLon).length > 0) : ready
    readonly property string latStr: modeManual ? String(ShellState.weatherLat) : root.ready ? String(root.glat) : ""
    readonly property string lonStr: modeManual ? String(ShellState.weatherLon) : root.ready ? String(root.glon) : ""
    // raw label; UI layers uppercase it
    readonly property string locLabel: modeManual ? (String(ShellState.weatherLabel).length > 0 ? String(ShellState.weatherLabel) : "LOCATION") : root.ready && root.glabel.length > 0 ? root.glabel : "LOCATING…"
    readonly property string tz: root.ready ? root.gtz : ""

    function detect(force) {
        if (!root.available || root.resolving)
            return;
        if (!force && root.ready)
            return;
        root.resolving = true;
        // primary (ipwho.is) wins when it answers success; otherwise the
        // http-only ip-api fallback runs — exactly one JSON object prints
        resolveProc.command = ["sh", "-c", "r=$(curl -s --max-time 8 'https://ipwho.is/' 2>/dev/null); case \"$r\" in *'\"success\":true'*) printf '%s\\n' \"$r\" ;; *) curl -s --max-time 6 'http://ip-api.com/json/?fields=status,lat,lon,city,countryCode,timezone' 2>/dev/null ;; esac"];
        resolveProc.running = true;
    }

    function _apply(j) {
        const lat = j.latitude ?? j.lat;
        const lon = j.longitude ?? j.lon;
        if (lat === undefined || lon === undefined)
            throw new Error("no coords");
        root.glat = Number(lat);
        root.glon = Number(lon);
        const cc = j.country_code ?? j.countryCode ?? "";
        root.glabel = (j.city ?? "") + (cc.length > 0 ? ", " + cc : "");
        root.gtz = typeof j.timezone === "string" ? j.timezone : (j.timezone?.id ?? "");
        root.gfetchedAt = Date.now();
        root.ready = true;
        root.error = "";
        cacheFile.setText(JSON.stringify({
                "_geo": {
                    "lat": root.glat,
                    "lon": root.glon,
                    "label": root.glabel,
                    "tz": root.gtz,
                    "fetchedAt": root.gfetchedAt
                }
            }));
    }

    Component.onCompleted: {
        binProbe.command = ["sh", "-c", "command -v curl >/dev/null 2>&1 && echo yes || echo no"];
        binProbe.running = true;
        try {
            const t = cacheFile.text().trim();
            if (t.length > 0) {
                const g = JSON.parse(t)._geo ?? {};
                if (g.lat !== undefined) {
                    root.glat = Number(g.lat);
                    root.glon = Number(g.lon);
                    root.glabel = String(g.label ?? "");
                    root.gtz = String(g.tz ?? "");
                    root.gfetchedAt = Number(g.fetchedAt ?? 0);
                    root.ready = true;
                }
            }
        } catch (e) {
        }
    }

    Process {
        id: binProbe

        stdout: StdioCollector {
            onStreamFinished: {
                root._probed = true;
                root._curlOk = text.trim() === "yes";
                if (!root._curlOk)
                    return;
                // stale cache (> 30 min) or nothing cached → resolve now
                const ageMin = (Date.now() - root.gfetchedAt) / 60000;
                if (root.modeAuto && (!root.ready || ageMin > 30))
                    root.detect(true);
            }
        }
    }

    Process {
        id: resolveProc

        stdout: StdioCollector {
            onStreamFinished: {
                root.resolving = false;
                const s = text.trim();
                const i = s.indexOf("{");
                const k = s.lastIndexOf("}");
                if (i >= 0 && k > i) {
                    try {
                        const j = JSON.parse(s.slice(i, k + 1));
                        if ((j.success === true || j.status === "success") && (j.latitude ?? j.lat) !== undefined) {
                            root._apply(j);
                            return;
                        }
                    } catch (e) {
                    }
                }
                root.error = "geo lookup failed";
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

        path: (Quickshell.env("HOME") ?? "") + "/.local/state/yutashell/geo.json"
        printErrors: false
        blockLoading: true
    }

    // re-resolve when switching into auto mode
    Connections {
        function onModeAutoChanged() {
            if (root.modeAuto)
                root.detect(true);
        }

        target: root
    }

    // periodic refresh while auto
    Timer {
        interval: 21600000 // 6 h
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            if (root.modeAuto)
                root.detect(true);
        }
    }
}
