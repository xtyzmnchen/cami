#!/usr/bin/env bash
# 停止守护、同步服务与 cpolar。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CPOLAR="${CPOLAR_BIN:-$HOME/cpolar}"
SERVER_PID_FILE="${TMPDIR:-/tmp}/cami-server.pid"
CPOLAR_PID_FILE="${TMPDIR:-/tmp}/cami-cpolar.pid"
WATCH_PID_FILE="${TMPDIR:-/tmp}/cami-watch.pid"

if [[ -f "$WATCH_PID_FILE" ]]; then
  kill "$(cat "$WATCH_PID_FILE" 2>/dev/null || true)" 2>/dev/null || true
  rm -f "$WATCH_PID_FILE"
fi
pkill -f "${ROOT}/tool/watch_sync.sh" 2>/dev/null || true

if [[ -f "$CPOLAR_PID_FILE" ]]; then
  kill "$(cat "$CPOLAR_PID_FILE" 2>/dev/null || true)" 2>/dev/null || true
  rm -f "$CPOLAR_PID_FILE"
fi
pkill -f "${CPOLAR} http" 2>/dev/null || true

if [[ -f "$SERVER_PID_FILE" ]]; then
  kill "$(cat "$SERVER_PID_FILE" 2>/dev/null || true)" 2>/dev/null || true
  rm -f "$SERVER_PID_FILE"
fi
pkill -f "${ROOT}/tool/server.dart" 2>/dev/null || true

echo "已停止守护 / 同步服务 / cpolar"
