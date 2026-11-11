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
echo "已发布发现地址（手机可自动拉取）："
echo "  https://cdn.jsdelivr.net/gh/xtyzmnchen/cami@main/web/sync-endpoint.json"
echo "当前同步电脑：$URL"
