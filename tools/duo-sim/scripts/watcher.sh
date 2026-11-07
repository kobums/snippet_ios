#!/bin/bash
# UI 테스트 ↔ 호스트 브리지: req 파일을 읽어 duotool 화면 전환과 디스플레이별 스크린샷만 수행한다.
DEV="$1"; IPC="$2"; SHOTS="$3"; TOOL="$4"
mkdir -p "$IPC" "$SHOTS"
while true; do
  for req in "$IPC"/req-*.txt; do
    [ -e "$req" ] || continue
    id=$(basename "$req" .txt); id=${id#req-}
    cmd=$(cat "$req"); rm -f "$req"
    verb=${cmd%% *}; args=${cmd#* }
    if [[ ! "$args" =~ ^[-A-Za-z0-9=._\ 가-힣]+$ ]]; then out="rejected"
    else
      case "$verb" in
        swap) out=$(xcrun simctl spawn "$DEV" "$TOOL" swap $args 2>&1 | tail -1) ;;
        shot) set -- $args; mkdir -p "$SHOTS/$2"; out=$(xcrun simctl io "$DEV" screenshot --display="$1" "$SHOTS/$2/$3.png" 2>&1 | tail -1) ;;
        *) out="unknown: $verb" ;;
      esac
    fi
    echo "$out" > "$IPC/done-$id.tmp" && mv "$IPC/done-$id.tmp" "$IPC/done-$id.txt"
    echo "$(date +%H:%M:%S) $cmd => $out"
  done
  sleep 0.2
done
