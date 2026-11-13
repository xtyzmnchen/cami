#!/usr/bin/env bash
# 打包 release APK，复制到 dist/，并上传蒲公英。
# 用法：
#   tool/build_apk.sh
#   SKIP_PGYER=1 tool/build_apk.sh   # 只打包不上传
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if command -v fvm >/dev/null 2>&1; then
  FLUTTER=(fvm flutter)
else
  FLUTTER=(flutter)
fi

echo "==> flutter build apk --release"
"${FLUTTER[@]}" build apk --release

mkdir -p dist
cp -f build/app/outputs/flutter-apk/app-release.apk "dist/小皇冠.apk"
ls -lh "dist/小皇冠.apk"

if [[ "${SKIP_PGYER:-0}" == "1" ]]; then
  echo "已跳过蒲公英上传 (SKIP_PGYER=1)"
  exit 0
fi

echo "==> 上传蒲公英"
exec "$ROOT/tool/publish_pgyer.sh" "dist/小皇冠.apk"
