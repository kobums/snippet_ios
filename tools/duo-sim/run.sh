#!/bin/bash
# iPhone Duo 시뮬레이터에서 Snippet을 자세별로 순회하며 스크린샷을 찍는다. 자세한 설명은 README.md.
#   tools/duo-sim/run.sh                        바깥·안쪽 가로·안쪽 세로·반쯤 접기 전부
#   tools/duo-sim/run.sh -c outer,inner_port    일부 자세만 (outer inner_land inner_port book book_port)
#   tools/duo-sim/run.sh --ocr                  OCR 밑줄 접기·회전 검증도 실행 (--ocr-only: 그것만)
#   tools/duo-sim/run.sh --skip-build           앱을 다시 빌드·설치하지 않음
#   tools/duo-sim/run.sh --device <UDID>        Duo가 아닌 기기와 비교할 때 (-c first 와 함께)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
IOS="$(cd "$HERE/../.." && pwd)"
BUILD="$HERE/build"
OUT_BASE="$HERE/out"
CONFIGS="outer,inner_land,inner_port,book"; OCR=0; TOUR=1; SKIP_BUILD=0
RUN="run-$(date +%Y%m%d-%H%M%S)"; DEV="${DUO_DEVICE:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    -c|--configs) CONFIGS="$2"; shift 2 ;;
    --ocr) OCR=1; shift ;;
    --ocr-only) OCR=1; TOUR=0; shift ;;
    --skip-build) SKIP_BUILD=1; shift ;;
    --run) RUN="$2"; shift 2 ;;
    --device) DEV="$2"; shift 2 ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) echo "알 수 없는 옵션: $1" >&2; exit 1 ;;
  esac
done
OUT="$OUT_BASE/$RUN"
mkdir -p "$BUILD" "$OUT"
PIDS=()
cleanup() { for p in "${PIDS[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null || true; done; }
trap cleanup EXIT
step() { echo "▶ $*"; }

# 1. Duo 시뮬레이터 — --device/DUO_DEVICE → 이미 켜진 Duo → 전용 "Snippet Duo QA" 순.
#    다른 용도로 쓰는 Duo 시뮬레이터는 건드리지 않도록, 없으면 전용 기기를 새로 만든다.
if [ -z "$DEV" ]; then
  DEV=$(xcrun simctl list devices available -j | python3 -I -c '
import json, sys
duos = [d for ds in json.load(sys.stdin)["devices"].values() for d in ds
        if d.get("deviceTypeIdentifier", "").endswith("iPhone-Duo")]
pick = next((d for d in duos if d["state"] == "Booted"), None) or next((d for d in duos if d["name"] == "Snippet Duo QA"), None)
print(pick["udid"] if pick else "")')
fi
if [ -z "$DEV" ]; then
  RT=$(xcrun simctl list runtimes -j | python3 -I -c '
import json, sys
for r in json.load(sys.stdin)["runtimes"]:
    if r["isAvailable"] and any(t["name"] == "iPhone Duo" for t in r.get("supportedDeviceTypes", [])):
        print(r["identifier"])' | tail -1)
  [ -n "$RT" ] || { echo "iPhone Duo를 지원하는 시뮬레이터 런타임(iOS 27.1+)이 없습니다 — xcodebuild -downloadPlatform iOS" >&2; exit 1; }
  DEV=$(xcrun simctl create "Snippet Duo QA" com.apple.CoreSimulator.SimDeviceType.iPhone-Duo "$RT")
fi
step "simulator $DEV"
xcrun simctl boot "$DEV" 2>/dev/null || true
xcrun simctl bootstatus "$DEV" -b >/dev/null

# 2. 접기 도구
step "duotool"
"$HERE/duotool/build.sh" "$BUILD/duotool" >/dev/null

# 3. 로컬 QA 백엔드 + 테스트 데이터 (운영 서버와 무관)
step "QA backend"
"$HERE/qa/backend.sh" up
"$HERE/qa/backend.sh" seed
set -a; . "$HERE/.qa.env"; set +a

# 4. 표지 이미지 HTTPS 서버 — QA 전용 CA를 이 시뮬레이터에만 신뢰시킨다
step "cover server"
[ -d "$BUILD/covers" ] || { mkdir -p "$BUILD/covers"; swift "$HERE/qa/covers.swift" "$HERE/qa/books.json" "$BUILD/covers" >/dev/null; }
TLS="$BUILD/tls"
if [ ! -f "$TLS/server.pem" ]; then
  mkdir -p "$TLS"
  ( umask 077; cd "$TLS"
    openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj "/CN=Snippet Duo QA CA (simulator only)" -keyout ca.key -out ca.pem \
      -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null
    openssl req -newkey rsa:2048 -nodes -subj "/CN=localhost" -keyout server.key -out server.csr 2>/dev/null
    printf "subjectAltName=DNS:localhost,IP:127.0.0.1\nextendedKeyUsage=serverAuth\nbasicConstraints=CA:FALSE\nkeyUsage=digitalSignature,keyEncipherment\n" > ext.cnf
    openssl x509 -req -in server.csr -CA ca.pem -CAkey ca.key -CAcreateserial -days 30 -out server.pem -extfile ext.cnf 2>/dev/null )
fi
xcrun simctl keychain "$DEV" add-root-cert "$TLS/ca.pem"
if ! lsof -nP -iTCP:8090 -sTCP:LISTEN >/dev/null 2>&1; then
  python3 -I "$HERE/qa/cover_server.py" "$BUILD/covers" "$TLS/server.pem" "$TLS/server.key" > "$BUILD/cover_server.log" 2>&1 &
  PIDS+=($!)
fi

# 5. 앱 — Debug 시뮬레이터 빌드는 localhost:8008에 붙는다
if [ "$SKIP_BUILD" = 0 ]; then
  step "build Snippet (Debug)"
  xcodebuild build -project "$IOS/Snippet.xcodeproj" -scheme Snippet -configuration Debug \
    -destination "platform=iOS Simulator,id=$DEV" -quiet > "$OUT/build-app.log" 2>&1 || { tail -20 "$OUT/build-app.log"; exit 1; }
  APP_DIR=$(xcodebuild -project "$IOS/Snippet.xcodeproj" -scheme Snippet -configuration Debug \
    -destination "platform=iOS Simulator,id=$DEV" -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR = /{print $2; exit}')
  xcrun simctl install "$DEV" "$APP_DIR/Snippet.app"
fi

# 6. OCR 테스트 페이지를 사진 보관함 맨 앞에
if [ "$OCR" = 1 ]; then
  [ -f "$BUILD/ocr_page.png" ] || swift "$HERE/qa/ocr_page.swift" "$BUILD/ocr_page.png" >/dev/null
  xcrun simctl addmedia "$DEV" "$BUILD/ocr_page.png"
fi

# 7. UI 테스트 드라이버
step "build UI driver"
xcodebuild build-for-testing -project "$HERE/driver/DuoDriver.xcodeproj" -scheme DuoDriver \
  -destination "platform=iOS Simulator,id=$DEV" -derivedDataPath "$BUILD/driver" -quiet > "$OUT/build-driver.log" 2>&1 \
  || { tail -20 "$OUT/build-driver.log"; exit 1; }
XCTESTRUN=$(ls "$BUILD"/driver/Build/Products/*.xctestrun | head -1)

# 8. 호스트 브리지 (접기·펴기, 디스플레이별 캡처)
# 실행마다 따로 — 앞선 실행이 남긴 watcher가 같은 요청을 집어 가지 않도록
IPC="$BUILD/ipc/$RUN"; rm -rf "$IPC"; mkdir -p "$IPC"
"$HERE/scripts/watcher.sh" "$DEV" "$IPC" "$OUT_BASE" "$BUILD/duotool" > "$OUT/watcher.log" 2>&1 &
PIDS+=($!)

# 9. 순회
TESTS=(); LABEL=""
if [ "$TOUR" = 1 ]; then TESTS+=(-only-testing:DuoUITests/DuoTour/testTour); LABEL="$CONFIGS"; fi
if [ "$OCR" = 1 ]; then TESTS+=(-only-testing:DuoUITests/DuoTour/testOCRFold); LABEL="${LABEL:+$LABEL + }ocr"; fi
step "tour: $LABEL"
set +e
TEST_RUNNER_QA_EMAIL=qa@snippet.test TEST_RUNNER_QA_PASSWORD="$QA_PASSWORD" \
TEST_RUNNER_IPC_DIR="$IPC" TEST_RUNNER_TREE_DIR="$OUT/tree" TEST_RUNNER_RUN_ID="$RUN" TEST_RUNNER_TOUR_CONFIGS="$CONFIGS" \
xcodebuild test-without-building -xctestrun "$XCTESTRUN" -destination "platform=iOS Simulator,id=$DEV" "${TESTS[@]}" \
  -resultBundlePath "$OUT/result.xcresult" > "$OUT/test.log" 2>&1
STATUS=$?
set -e
grep -E "\[duo\] (missing|unknown)|Test Case .*(passed|failed)" "$OUT/test.log" || true

# 10. 자세별 모아보기
step "contact sheets"
[ -x "$BUILD/sheet" ] || swiftc -O "$HERE/scripts/sheet.swift" -o "$BUILD/sheet" >/dev/null 2>&1
mkdir -p "$OUT/sheets"
for prefix in $(ls "$OUT"/*.png 2>/dev/null | xargs -n1 basename | sed -E 's/_[0-9]{2}[a-z]?_.*//' | sort -u); do
  "$BUILD/sheet" "$OUT/sheets/$prefix.png" 300 4 "$OUT"/"${prefix}"_*.png >/dev/null
done
echo "결과: $OUT (화면별 PNG, tree/ 접근성 트리, sheets/ 모아보기)"
exit $STATUS
