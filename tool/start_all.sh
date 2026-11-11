#!/usr/bin/env bash
# 一键启动小皇冠电脑端：
#   1) 本地同步服务 tool/server.dart → :8787
#   2) cpolar 公网隧道
#   3) 把最新地址推到 GitHub（手机 App 可自动拉取）
#
# 用法（在项目根目录）：
#   tool/start_all.sh
# 停止：
#   Ctrl+C   或   tool/stop_all.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PORT="${PORT:-8787}"
TOKEN="${CAMI_TOKEN:-cami-home}"
CPOLAR="${CPOLAR_BIN:-$HOME/cpolar}"
REGION="${CPOLAR_REGION:-cn}"
SERVER_LOG="${TMPDIR:-/tmp}/cami-server.log"
CPOLAR_LOG="${TMPDIR:-/tmp}/cami-cpolar.log"
SERVER_PID_FILE="${TMPDIR:-/tmp}/cami-server.pid"
CPOLAR_PID_FILE="${TMPDIR:-/tmp}/cami-cpolar.pid"

SERVER_PID=""
CPID=""
STARTED_SERVER=0
STARTED_CPOLAR=0

if command -v fvm >/dev/null 2>&1; then
  DART=(fvm dart)
elif command -v dart >/dev/null 2>&1; then
  DART=(dart)
else
  echo "找不到 dart / fvm，请先安装 Flutter/Dart"
  exit 1
fi

if [[ ! -x "$CPOLAR" ]]; then
  echo "找不到 cpolar: $CPOLAR"
  echo "请安装并登录 cpolar，或设置 CPOLAR_BIN"
  exit 1
fi

cleanup() {
  echo
  echo "正在停止..."
  if [[ -n "${CPID}" ]]; then
    kill "${CPID}" 2>/dev/null || true
  fi
  if [[ -f "$CPOLAR_PID_FILE" ]]; then
    kill "$(cat "$CPOLAR_PID_FILE" 2>/dev/null || true)" 2>/dev/null || true
    rm -f "$CPOLAR_PID_FILE"
  fi
  pkill -f "${CPOLAR} http" 2>/dev/null || true

  if [[ "${STARTED_SERVER}" -eq 1 ]]; then
    if [[ -n "${SERVER_PID}" ]]; then
      kill "${SERVER_PID}" 2>/dev/null || true
    fi
    if [[ -f "$SERVER_PID_FILE" ]]; then
      kill "$(cat "$SERVER_PID_FILE" 2>/dev/null || true)" 2>/dev/null || true
      rm -f "$SERVER_PID_FILE"
    fi
    pkill -f "${ROOT}/tool/server.dart" 2>/dev/null || true
  fi
  echo "已停止本地同步服务与 cpolar"
}
trap cleanup EXIT INT TERM

echo "==> 1/3 本地同步服务 (:${PORT})"
if curl -sf --connect-timeout 1 "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
  echo "    已在运行，复用现有服务"
else
  : >"$SERVER_LOG"
  "${DART[@]}" run tool/server.dart >>"$SERVER_LOG" 2>&1 &
  SERVER_PID=$!
  echo "${SERVER_PID}" >"$SERVER_PID_FILE"
  STARTED_SERVER=1
  for _ in $(seq 1 30); do
    if curl -sf --connect-timeout 1 "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
      break
    fi
    sleep 0.5
  done
  if ! curl -sf --connect-timeout 1 "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
    echo "同步服务启动失败，日志:"
    tail -40 "$SERVER_LOG" || true
    exit 1
  fi
  echo "    已启动 (pid ${SERVER_PID})，日志 ${SERVER_LOG}"
fi
echo "    本机: http://127.0.0.1:${PORT}/health"
echo "    口令: ${TOKEN}"

echo "==> 2/3 cpolar 公网隧道"
pkill -f "${CPOLAR} http" 2>/dev/null || true
sleep 1
: >"$CPOLAR_LOG"
"${CPOLAR}" http "${PORT}" -log=stdout -log-level=INFO -region="${REGION}" >>"$CPOLAR_LOG" 2>&1 &
CPID=$!
echo "${CPID}" >"$CPOLAR_PID_FILE"
STARTED_CPOLAR=1
echo "    cpolar pid=${CPID}"
echo "    日志: ${CPOLAR_LOG}"

URL=""
for _ in $(seq 1 40); do
  sleep 1
  if ! kill -0 "${CPID}" 2>/dev/null; then
    echo "cpolar 已退出，日志:"
    tail -40 "$CPOLAR_LOG" || true
    exit 1
  fi
  if command -v rg >/dev/null 2>&1; then
    URL="$(rg -o 'https://[a-z0-9.-]+\.cpolar\.[a-z.]+' "$CPOLAR_LOG" 2>/dev/null | tail -1 || true)"
  else
    URL="$(grep -Eo 'https://[a-z0-9.-]+\.cpolar\.[a-z.]+' "$CPOLAR_LOG" 2>/dev/null | tail -1 || true)"
  fi
  if [[ -n "${URL}" ]]; then
    break
  fi
done

if [[ -z "${URL}" ]]; then
  echo "60 秒内未拿到公网地址，请检查 cpolar 登录/网络"
  tail -40 "$CPOLAR_LOG" || true
  exit 1
fi
echo "    公网: ${URL}"

echo "==> 3/3 推送到 GitHub（手机发现用）"
"$ROOT/tool/publish_sync_url.sh" "${URL}" "${TOKEN}"

echo
echo "======= 全部就绪 ======="
echo "本机健康检查: http://127.0.0.1:${PORT}/health"
echo "手机同步地址: ${URL}"
echo "发现接口: https://cdn.jsdelivr.net/gh/xtyzmnchen/cami@main/web/sync-endpoint.json"
echo "口令: ${TOKEN}"
echo
echo "保持此终端开着。Ctrl+C 结束全部服务。"
echo "另开终端可执行: tool/stop_all.sh"
wait "${CPID}"
