pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common
import "../notify"

// CIService — reads GitHub Actions / GitLab CI via `gh` CLI (PH.04).
// 60s refresh, configurable repos via ShellState.cicdRepos.
Singleton {
    id: root

    readonly property bool available: _probed
    property bool _probed: false
    property bool _hasGh: false

    property var runs: []
    property string status: ""

    signal runsRefreshed()

    readonly property var repos: {
        try {
            const r = JSON.parse(ShellState.cicdRepos);
            return Array.isArray(r) ? r : [];
        } catch (e) { return []; }
    }

    function refresh() {
        if (!_hasGh || repos.length === 0) return;
        for (let i = 0; i < repos.length; i++) {
            ghRunProc.command = ["gh", "run", "list", "--repo", repos[i], "--json", "name,headBranch,status,conclusion,url,createdAt,updatedAt", "--limit", "5"];
            ghRunProc.running = true;
            return; // one repo at a time; cycle through on completion
        }
    }

    function addRepo(name) {
        let list = repos.slice();
        if (list.indexOf(name) < 0) {
            list.push(name);
            ShellState.set("cicdRepos", JSON.stringify(list));
        }
    }

    function removeRepo(name) {
        const list = repos.filter(r => r !== name);
        ShellState.set("cicdRepos", JSON.stringify(list));
    }

    function _parseRuns(text, repo) {
        try {
            const data = JSON.parse(text);
            const newRuns = Array.isArray(data) ? data.map(r => ({
                repo: repo,
                name: r.name || "",
                branch: r.headBranch || "",
                status: r.status || "",
                conclusion: r.conclusion || "",
                url: r.url || "",
                createdAt: r.createdAt || "",
                updatedAt: r.updatedAt || ""
            })) : [];

            // merge with existing runs (replace this repo's runs)
            const others = root.runs.filter(r => r.repo !== repo);
            root.runs = others.concat(newRuns);

            const failures = root.runs.filter(r => r.conclusion === "failure").length;
            root.status = root.runs.length + " runs" + (failures > 0 ? " (" + failures + " failed)" : "");

            // notify on new failures
            for (let i = 0; i < newRuns.length; i++) {
                if (newRuns[i].conclusion === "failure") {
                    Notify.announce("CI Failed", newRuns[i].repo + "/" + newRuns[i].branch + " — " + newRuns[i].name);
                }
            }
        } catch (e) {}
        root.runsRefreshed();
    }

    Component.onCompleted: {
        ghProbeProc.running = true;
    }

    Process {
        id: ghProbeProc
        command: ["which", "gh"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._probed = true;
                root._hasGh = this.text.trim().length > 0;
                if (root._hasGh) root.refresh();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root._probed = true;
                root._hasGh = false;
            }
        }
    }

    property int _repoIdx: 0

    Process {
        id: ghRunProc
        stdout: StdioCollector {
            onStreamFinished: {
                const repo = root.repos[root._repoIdx] ?? "";
                root._parseRuns(this.text, repo);
                // cycle to next repo
                root._repoIdx = (root._repoIdx + 1) % Math.max(root.repos.length, 1);
                if (root._repoIdx < root.repos.length && root._repoIdx > 0) {
                    ghRunProc.command = ["gh", "run", "list", "--repo", root.repos[root._repoIdx], "--json", "name,headBranch,status,conclusion,url,createdAt,updatedAt", "--limit", "5"];
                    ghRunProc.running = true;
                }
            }
        }
        stderr: StdioCollector {}
    }

    Timer {
        interval: 60000
        running: root._hasGh && root.repos.length > 0
        repeat: true
        onTriggered: {
            root._repoIdx = 0;
            root.refresh();
        }
    }
}
