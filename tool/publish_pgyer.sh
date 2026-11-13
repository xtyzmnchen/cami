#!/usr/bin/env bash
# 上传 APK 到蒲公英（Pgyer API v2）。
# 用法：
#   tool/publish_pgyer.sh [path/to.apk]
# API Key 来自：
#   1) 环境变量 PGYER_API_KEY
#   2) tool/secrets.local.env（已 gitignore）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SECRETS="$ROOT/tool/secrets.local.env"
if [[ -f "$SECRETS" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$SECRETS"
  set +a
fi

API_KEY="${PGYER_API_KEY:-}"
APK="${1:-}"
if [[ -z "$APK" ]]; then
  if [[ -f "$ROOT/dist/小皇冠.apk" ]]; then
    APK="$ROOT/dist/小皇冠.apk"
  elif [[ -f "$ROOT/build/app/outputs/flutter-apk/app-release.apk" ]]; then
    APK="$ROOT/build/app/outputs/flutter-apk/app-release.apk"
  fi
fi

if [[ -z "$API_KEY" ]]; then
  echo "缺少 PGYER_API_KEY。请写入 tool/secrets.local.env 或 export PGYER_API_KEY=..."
  exit 1
fi
if [[ -z "$APK" || ! -f "$APK" ]]; then
  echo "找不到 APK。用法: $0 path/to.apk"
  exit 1
fi

# 绝对路径，避免中文相对路径问题
APK="$(cd "$(dirname "$APK")" && pwd)/$(basename "$APK")"

echo "准备上传: $APK ($(du -h "$APK" | awk '{print $1}'))"

DESC="小皇冠 release $(date '+%Y-%m-%d %H:%M')"
TOKEN_JSON="$(curl -fsS --connect-timeout 20 --max-time 60 \
  -X POST 'https://www.pgyer.com/apiv2/app/getCOSToken' \
  -F "_api_key=${API_KEY}" \
  -F 'buildType=android' \
  -F "buildUpdateDescription=${DESC}")"

META_FILE="$(mktemp)"
python3 - "$TOKEN_JSON" "$META_FILE" <<'PY'
import json, sys
raw, out = sys.argv[1], sys.argv[2]
data = json.loads(raw)
if data.get("code") != 0:
    raise SystemExit(f"getCOSToken 失败: {data}")
d = data["data"]
json.dump({
    "endpoint": d["endpoint"],
    "key": d["key"],
    "signature": d["params"]["signature"],
    "token": d["params"]["x-cos-security-token"],
}, open(out, "w"), ensure_ascii=False)
print("已获取上传凭证")
PY

ENDPOINT="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["endpoint"])' "$META_FILE")"
KEY="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["key"])' "$META_FILE")"
SIGNATURE="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["signature"])' "$META_FILE")"
XTOKEN="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["token"])' "$META_FILE")"

echo "上传到蒲公英 COS..."
# 用 --form-string 避免 signature 被错误编码；补上官方要求的文件名头
HTTP_CODE="$(curl -sS --connect-timeout 30 --max-time 600 \
  -o /tmp/cami-pgyer-upload.out -w '%{http_code}' \
  -X POST "$ENDPOINT" \
  --form-string "key=${KEY}" \
  --form-string "signature=${SIGNATURE}" \
  --form-string "x-cos-security-token=${XTOKEN}" \
  --form-string "x-cos-meta-file-name=$(basename "$APK")" \
  -F "file=@${APK};type=application/vnd.android.package-archive")"

if [[ "$HTTP_CODE" != "204" && "$HTTP_CODE" != "200" ]]; then
  echo "上传失败 HTTP $HTTP_CODE"
  cat /tmp/cami-pgyer-upload.out 2>/dev/null || true
  rm -f "$META_FILE"
  exit 1
fi
echo "上传完成 (HTTP $HTTP_CODE)，等待蒲公英处理..."

for _ in $(seq 1 60); do
  INFO="$(curl -fsS --connect-timeout 15 --max-time 30 \
    -X POST 'https://www.pgyer.com/apiv2/app/buildInfo' \
    -F "_api_key=${API_KEY}" \
    -F "buildKey=${KEY}" || true)"
  CODE="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("code", -1))' "$INFO" 2>/dev/null || echo -1)"
  if [[ "$CODE" == "0" ]]; then
    python3 - "$INFO" <<'PY'
import json, sys
d = json.loads(sys.argv[1])["data"]
name = d.get("buildName") or d.get("buildFileName") or ""
ver = d.get("buildVersion") or ""
bn = d.get("buildBuildVersion") or ""
short = d.get("buildShortcutUrl") or ""
qr = d.get("buildQRCodeURL") or ""
page = short if str(short).startswith("http") else (f"https://www.pgyer.com/{short}" if short else "")
print("蒲公英发布成功")
print(f"  应用: {name} {ver} ({bn})")
print(f"  页面: {page}")
if qr:
    print(f"  二维码: {qr}")
PY
    rm -f "$META_FILE"
    exit 0
  fi
  if [[ "$CODE" != "1246" && "$CODE" != "1247" && "$CODE" != "-1" ]]; then
    echo "查询失败: $INFO"
    rm -f "$META_FILE"
    exit 1
  fi
  sleep 2
done

echo "等待超时，buildKey=$KEY（可稍后在蒲公英后台查看）"
rm -f "$META_FILE"
exit 1
