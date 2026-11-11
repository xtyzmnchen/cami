#!/usr/bin/env bash
# 守护：保证本地同步服务 + cpolar 可用；公网挂了就重启并推送新地址到 GitHub。
#
# 用法：
#   tool/watch_sync.sh
# 停止：
#   tool/stop_all.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PORT="${PORT:-8787}"
TOKEN="${CAMI_TOKEN:-cami-home}"
CPOLAR="${CPOLAR_BIN:-$HOME/cpolar}"
REGION="${CPOLAR_REGION:-cn}"
CHECK_SECS="${CHECK_SECS:-20}"
FAIL_NEED="${FAIL_NEED:-2}"

SERVER_LOG="${TMPDIR:-/tmp}/cami-server.log"
CPOLAR_LOG="${TMPDIR:-/tmp}/cami-cpolar.log"
SERVER_PID_FILE="${TMPDIR:-/tmp}/cami-server.pid"
CPOLAR_PID_FILE="${TMPDIR:-/tmp}/cami-cpolar.pid"
WATCH_PID_FILE="${TMPDIR:-/tmp}/cami-watch.pid"
ENDPOINT_FILE="$ROOT/web/sync-endpoint.json"

if command -v fvm >/dev/null 2>&1; then
  DART=(fvm dart)
elif command -v dart >/dev/null 2>&1; then
  DART=(dart)
else
  echo "找不到 dart / fvm"
  exit 1
fi

if [[ ! -x "$CPOLAR" ]]; then
  echo "找不到 cpolar: $CPOLAR"
  exit 1
fi

echo $$ >"$WATCH_PID_FILE"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

current_url() {
  python3 - <<'PY' 2>/dev/null || true
import json
from pathlib import Path
p = Path("web/sync-endpoint.json")
if p.exists():
    print(json.loads(p.read_text(encoding="utf-8")).get("url","").rstrip("/"))
PY
}

health_ok() {
  local url="$1"
  [[ -z "$url" ]] && return 1
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 12 "${url}/health" || true)"
  [[ "$code" == "200" ]]
}

local_ok() {
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 5 "http://127.0.0.1:${PORT}/health" || true)"
  [[ "$code" == "200" ]]
}

ensure_server() {
  if local_ok; then
    return 0
  fi
  log "本地同步服务不可用，正在启动..."
  pkill -f "${ROOT}/tool/server.dart" 2>/dev/null || true
  sleep 1
  : >"$SERVER_LOG"
  "${DART[@]}" run tool/server.dart >>"$SERVER_LOG" 2>&1 &
  echo $! >"$SERVER_PID_FILE"
  for _ in $(seq 1 30); do
    local_ok && { log "本地服务已就绪"; return 0; }
    sleep 0.5
  done
  log "本地服务启动失败，见 $SERVER_LOG"
  return 1
}

read_cpolar_url_from_log() {
  if command -v rg >/dev/null 2>&1; then
    rg -o 'https://[a-z0-9.-]+\.cpolar\.[a-z.]+' "$CPOLAR_LOG" 2>/dev/null | tail -1 || true
  else
    grep -Eo 'https://[a-z0-9.-]+\.cpolar\.[a-z.]+' "$CPOLAR_LOG" 2>/dev/null | tail -1 || true
  fi
}

restart_cpolar_and_publish() {
  log "重启 cpolar 并发布新地址..."
  pkill -f "${CPOLAR} http" 2>/dev/null || true
  sleep 2
  : >"$CPOLAR_LOG"
  "${CPOLAR}" http "${PORT}" -log=stdout -log-level=INFO -region="${REGION}" >>"$CPOLAR_LOG" 2>&1 &
  local cpid=$!
  echo "$cpid" >"$CPOLAR_PID_FILE"

  local url=""
  for _ in $(seq 1 45); do
    sleep 1
    if ! kill -0 "$cpid" 2>/dev/null; then
      log "cpolar 进程退出，稍后重试"
      return 1
    fi
    url="$(read_cpolar_url_from_log)"
    if [[ -n "$url" ]]; then
      break
    fi
  done

  if [[ -z "$url" ]]; then
    log "未拿到公网地址"
    return 1
  fi

  log "新公网地址: $url"
  # 等隧道真正可访问
  for _ in $(seq 1 15); do
    if health_ok "$url"; then
      break
    fi
    sleep 2
  done

  if ! health_ok "$url"; then
    log "新地址暂时 health 不通，仍先发布到 GitHub"
  fi

  "$ROOT/tool/publish_sync_url.sh" "$url" "$TOKEN" || log "发布 GitHub 失败，下次会再试"
  return 0
}

cleanup() {
  log "守护退出（不自动杀服务；需要全停请用 tool/stop_all.sh）"
  rm -f "$WATCH_PID_FILE"
}
trap cleanup EXIT INT TERM

log "守护启动：每 ${CHECK_SECS}s 检查一次，连续失败 ${FAIL_NEED} 次则重建隧道"
ensure_server || true

URL="$(current_url)"
if ! health_ok "$URL"; then
  restart_cpolar_and_publish || true
  URL="$(current_url)"
fi

fails=0
while true; do
  if ! local_ok; then
    ensure_server || true
  fi

  URL="$(current_url)"
  if health_ok "$URL"; then
    if [[ "$fails" -gt 0 ]]; then
      log "公网恢复正常: $URL"
    fi
    fails=0
  else
    fails=$((fails + 1))
    log "公网不可用 ($fails/${FAIL_NEED}): ${URL:-空}"
    if [[ "$fails" -ge "$FAIL_NEED" ]]; then
      restart_cpolar_and_publish || true
      fails=0
      URL="$(current_url)"
    fi
  fi
  sleep "$CHECK_SECS"
done
