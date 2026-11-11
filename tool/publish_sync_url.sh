#!/usr/bin/env bash
# 把当前 cpolar 公网地址写进 GitHub 仓库，手机 App 会从这里自动拉取。
# 用法：
#   tool/publish_sync_url.sh https://xxxx.r6.cpolar.cn
#   tool/publish_sync_url.sh https://xxxx.r6.cpolar.cn cami-home
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
URL="${1:-}"
TOKEN="${2:-cami-home}"
FILE="$ROOT/web/sync-endpoint.json"

if [[ -z "$URL" ]]; then
  echo "用法: $0 <https://xxx.cpolar.cn> [token]"
  exit 1
fi

URL="${URL%/}"
NOW="$(date +%Y-%m-%dT%H:%M:%S%z | sed 's/\([0-9][0-9]\)$/:\1/')"

python3 - <<PY
import json
from pathlib import Path
Path("$FILE").write_text(json.dumps({
  "url": "$URL",
  "token": "$TOKEN",
  "updatedAt": "$NOW",
}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("wrote $FILE")
PY

cd "$ROOT"
git add web/sync-endpoint.json
if git diff --cached --quiet; then
  echo "地址未变化，跳过推送"
  exit 0
fi

git commit -m "Update sync endpoint to ${URL}"
git push origin HEAD
SHA="$(git rev-parse HEAD)"

purge_jsdelivr() {
  local path="$1"
  curl -fsS --connect-timeout 8 --max-time 15 "https://purge.jsdelivr.net/${path}" >/dev/null 2>&1 || true
}

# @main 有缓存；同时 purge @main 与精确 commit，方便国内 CDN 回源
purge_jsdelivr "gh/xtyzmnchen/cami@main/web/sync-endpoint.json"
purge_jsdelivr "gh/xtyzmnchen/cami@${SHA}/web/sync-endpoint.json"
# 再清一次 fastly 入口
curl -fsS --connect-timeout 8 --max-time 15 \
  -X PURGE "https://cdn.jsdelivr.net/gh/xtyzmnchen/cami@main/web/sync-endpoint.json" >/dev/null 2>&1 || true

echo "已发布（GitHub 为准，即时生效）："
echo "  API: https://api.github.com/repos/xtyzmnchen/cami/contents/web/sync-endpoint.json?ref=main"
echo "  jsDelivr@commit: https://cdn.jsdelivr.net/gh/xtyzmnchen/cami@${SHA}/web/sync-endpoint.json"
echo "  （不要依赖 jsDelivr @main，它可能延迟几分钟）"
echo "当前同步电脑：$URL"

# 校验 GitHub API 是否已是新地址（App 也优先读这个）
API_URL="$(curl -fsS --connect-timeout 8 --max-time 15 \
  -H 'Accept: application/vnd.github.raw+json' \
  -H 'User-Agent: cami-publish' \
  "https://api.github.com/repos/xtyzmnchen/cami/contents/web/sync-endpoint.json?ref=main" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin).get("url",""))' 2>/dev/null || true)"
if [[ -n "$API_URL" && "$API_URL" == "$URL" ]]; then
  echo "GitHub API 校验通过: $API_URL"
else
  echo "GitHub API 校验: ${API_URL:-空}（若为空请稍后重试；App 会优先读 API）"
fi
