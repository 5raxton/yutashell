#!/usr/bin/env bash
# QML integration smoke test — spawns an isolated instance, exercises core
# IPC targets, greps the authoritative log for errors, checks RSS, kills.
#
# Refuses to run when another instance is live (the session shell hot-reloads
# this same config; mutating IPC from two instances would fight).
set -u

CFG="$(cd "$(dirname "$0")/.." && pwd)"
LOGDIR=/tmp/opencode/yuta-smoke
mkdir -p "$LOGDIR"

if pgrep -x qs >/dev/null 2>&1 || pgrep -x quickshell >/dev/null 2>&1; then
    echo "SKIP: a quickshell instance is already running — smoke test needs exclusivity"
    exit 0
fi

setsid nohup qs -p "$CFG" < /dev/null > "$LOGDIR/stdout.log" 2>&1 &
PID=$!
echo "spawned pid $PID"
trap 'kill "$PID" 2>/dev/null' EXIT

# boot + singleton warm-up
sleep 11

fails=0
ipc() {
    if ! qs ipc --pid "$PID" call "$@" > /tmp/opencode/yuta-smoke/ipc.out 2>&1; then
        echo "IPC FAIL: $*"
        fails=$((fails+1))
    fi
    sleep 0.7
}

ipc shell state
ipc theme info 2>/dev/null || true
ipc scheme list
ipc compositor info
ipc plugins list
ipc templates list
ipc audio status 2>/dev/null || ipc panel toggle
ipc panel toggle
ipc notifycenter test normal
sleep 1
ipc notifycenter clear

L=/run/user/$(id -u)/quickshell/by-pid/$PID/log.log
errs=$(grep -cE " ERROR |TypeError|ReferenceError|Cannot read property|is not a type|Property value set multiple times" "$L" 2>/dev/null)
[ -z "$errs" ] && errs=0
rss=$(ps -o rss= -p "$PID" 2>/dev/null | tr -d ' ' || echo 0)

echo "---"
echo "log errors: $errs"
echo "rss: $((rss / 1024)) MB"

if [ "$errs" != "0" ]; then
    echo "--- offending lines ---"
    grep -E " ERROR |TypeError|ReferenceError|Cannot read property|is not a type|Property value set multiple times" "$L" | sort | uniq -c | head
    fails=$((fails+1))
fi

kill "$PID" 2>/dev/null
wait "$PID" 2>/dev/null
trap - EXIT

if [ "$fails" = 0 ]; then
    echo "SMOKE OK"
else
    echo "SMOKE FAILED ($fails)"
    exit 1
fi
