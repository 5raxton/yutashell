pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

// DockerService — reads docker compose projects via `docker compose ls --format json`
// (PH.04). Exposes project list with container details, status, resource usage.
Singleton {
    id: root

    readonly property bool available: _probed
    property bool _probed: false
    property bool _hasDocker: false

    property var projects: []
    property string status: ""

    signal projectsRefreshed()

    function refresh() {
        if (!_hasDocker) return;
        dockerLsProc.running = true;
    }

    function restartProject(name) {
        if (!_hasDocker || !name) return;
        dockerRestartProc.command = ["sh", "-c", "docker compose -p " + name + " restart"];
        dockerRestartProc.running = true;
    }

    function stopProject(name) {
        if (!_hasDocker || !name) return;
        dockerStopProc.command = ["sh", "-c", "docker compose -p " + name + " down"];
        dockerStopProc.running = true;
    }

    function startProject(name) {
        if (!_hasDocker || !name) return;
        dockerRestartProc.command = ["sh", "-c", "docker compose -p " + name + " up -d"];
        dockerRestartProc.running = true;
    }

    function _parseProjects(text) {
        try {
            const data = JSON.parse(text);
            const projects = Array.isArray(data) ? data : [];
            root.projects = projects.map(p => ({
                name: p.Name || "",
                status: p.Status || "",
                configFiles: p.ConfigFiles || "",
                running: (p.ConfigFiles || "").length > 0,
                containers: p.Containers || 0
            }));
            root.status = root.projects.length + " projects";
        } catch (e) {
            root.projects = [];
            root.status = "parse error";
        }
        root.projectsRefreshed();
    }

    Component.onCompleted: {
        dockerProbeProc.running = true;
    }

    Process {
        id: dockerProbeProc
        command: ["which", "docker"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._probed = true;
                root._hasDocker = this.text.trim().length > 0;
                if (root._hasDocker) root.refresh();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root._probed = true;
                root._hasDocker = false;
            }
        }
    }

    Process {
        id: dockerLsProc
        command: ["docker", "compose", "ls", "--format", "json"]
        stdout: StdioCollector {
            onStreamFinished: root._parseProjects(this.text);
        }
        stderr: StdioCollector {}
    }

    Process {
        id: dockerRestartProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onRunningChanged: {
            if (!running) root.refresh();
        }
    }

    Process {
        id: dockerStopProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onRunningChanged: {
            if (!running) root.refresh();
        }
    }

    Timer {
        interval: 10000
        running: root._hasDocker
        repeat: true
        onTriggered: root.refresh()
    }
}
