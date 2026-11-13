#!/usr/bin/env bash
# 启动 cpolar → 8787，探测到公网地址后自动写到 GitHub（App 可自动换地址）。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CPOLAR="${CPOLAR_BIN:-$HOME/cpolar}"
PORT="${PORT:-8787}"
REGION="${CPOLAR_REGION:-cn}"
TOKEN="${CAMI_TOKEN:-cami-home}"
LOG="${TMPDIR:-/tmp}/cami-cpolar.log"

if [[ ! -x "$CPOLAR" ]]; then
  echo "找不到 cpolar：$CPOLAR"
  exit 1
fi

pkill -f "$CPOLAR http" 2>/dev/null || true
pkill -f '[c]polar' 2>/dev/null || true
killall cpolar 2>/dev/null || true
sleep 2
pkill -9 -f '[c]polar' 2>/dev/null || true
: >"$LOG"
"$CPOLAR" http "$PORT" -log=stdout -log-level=INFO -region="$REGION" >>"$LOG" 2>&1 &
CPID=$!
echo "cpolar pid=$CPID，日志 $LOG"

URL=""
for _ in $(seq 1 60); do
  sleep 1
  if ! kill -0 "$CPID" 2>/dev/null; then
    echo "cpolar 已退出，见日志："
    tail -30 "$LOG" || true
    exit 1
  fi
  if command -v rg >/dev/null 2>&1; then
    URL="$(rg -o 'https://[a-z0-9.-]+\.cpolar\.[a-z.]+' "$LOG" | tail -1 || true)"
  else
    URL="$(grep -Eo 'https://[a-z0-9.-]+\.cpolar\.[a-z.]+' "$LOG" | tail -1 || true)"
  fi
  if [[ -z "$URL" ]]; then
    for port in 4040 4041 4042 4043; do
      body="$(curl -fsS --connect-timeout 1 --max-time 3 "http://127.0.0.1:${port}/api/tunnels" 2>/dev/null || true)"
      if [[ -n "$body" ]]; then
        URL="$(printf '%s' "$body" | grep -Eo 'https://[a-z0-9.-]+\.cpolar\.[a-z.]+' | tail -1 || true)"
        [[ -n "$URL" ]] && break
      fi
    done
  fi
  if [[ -n "$URL" ]]; then
    break
  fi
done

if [[ -z "$URL" ]]; then
  echo "60 秒内未拿到公网地址，请检查 cpolar 登录/网络"
  tail -40 "$LOG" || true
  exit 1
fi

echo "隧道已建立：$URL"
"$ROOT/tool/publish_sync_url.sh" "$URL" "$TOKEN"

echo "前台继续跑 cpolar（Ctrl+C 结束）"
wait "$CPID"
