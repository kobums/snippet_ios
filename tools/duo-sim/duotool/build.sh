#!/bin/bash
# duotool 빌드 — iOS 시뮬레이터용. 엔타이틀먼트는 코드서명이 아니라 __TEXT 섹션에 넣는다
# (시뮬레이터 서비스는 섹션에서 읽고, 코드서명에 넣으면 macOS가 실행을 막는다).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$HERE/../build/duotool}"
mkdir -p "$(dirname "$OUT")"
DER="$(dirname "$OUT")/duotool-entitlements.der"
derq query -f xml -i "$HERE/entitlements.plist" -o "$DER" --raw
xcrun -sdk iphonesimulator clang -arch arm64 -mios-simulator-version-min=27.0 -fobjc-arc \
  -framework Foundation "$HERE/duotool.m" -o "$OUT" \
  -Wl,-sectcreate,__TEXT,__entitlements,"$HERE/entitlements.plist" \
  -Wl,-sectcreate,__TEXT,__ents_der,"$DER"
codesign -s - -f "$OUT" >/dev/null 2>&1
echo "$OUT"
