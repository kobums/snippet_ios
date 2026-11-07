#!/bin/bash
# 로컬 QA 백엔드 — 시뮬레이터 Debug 빌드가 붙는 localhost:8008을 Docker로 띄운다. 운영 서버·운영 DB와 무관.
#   backend.sh up      DB·백엔드 컨테이너 기동 (처음이면 비밀값 생성)
#   backend.sh seed    QA 계정 생성 + 테스트 데이터 (이미 있으면 건너뜀)
#   backend.sh down    컨테이너 중지 (데이터 유지)
#   backend.sh reset   컨테이너·네트워크·비밀값 삭제
# 비밀값(DB/JWT/QA 계정 비밀번호)은 매번 무작위로 만들어 tools/duo-sim/.qa.env에만 둔다 (gitignore).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
ENV_FILE="$ROOT/.qa.env"
NET=snippet-qa DB=snippet-qa-db BACK=snippet-qa-back
DB_IMAGE=mariadb:10.11
BACK_IMAGE="${SNIPPET_BACK_IMAGE:-kobums/snippetback:latest}"

exists() { docker ps -a --format '{{.Names}}' | grep -qx "$1"; }

load_env() { set -a; . "$ENV_FILE"; set +a; }

up() {
  docker image inspect "$BACK_IMAGE" >/dev/null 2>&1 || { echo "백엔드 이미지 $BACK_IMAGE 없음 — deploy.sh로 빌드하거나 SNIPPET_BACK_IMAGE를 지정하세요" >&2; exit 1; }
  if [ ! -f "$ENV_FILE" ]; then
    # 비밀값이 바뀌면 기존 컨테이너와 맞지 않으므로 새로 만든다
    docker rm -f "$BACK" "$DB" >/dev/null 2>&1 || true
    ( umask 077
      printf 'DB_PASSWORD=%s\nDB_ROOT_PASSWORD=%s\nJWT_SECRET=%s\nQA_PASSWORD=Qa%s\nWRITER_PASSWORD=Wr%s\n' \
        "$(openssl rand -hex 16)" "$(openssl rand -hex 16)" "$(openssl rand -base64 48 | tr -d '\n')" \
        "$(openssl rand -hex 8)" "$(openssl rand -hex 8)" > "$ENV_FILE" )
  fi
  load_env
  docker network inspect "$NET" >/dev/null 2>&1 || docker network create "$NET" >/dev/null
  if exists "$DB"; then docker start "$DB" >/dev/null; else
    docker run -d --name "$DB" --network "$NET" -p 127.0.0.1:3307:3306 -e TZ=Asia/Seoul \
      -e MARIADB_DATABASE=snippet -e MARIADB_USER=snippet -e MARIADB_PASSWORD="$DB_PASSWORD" -e MARIADB_ROOT_PASSWORD="$DB_ROOT_PASSWORD" \
      "$DB_IMAGE" --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci >/dev/null
  fi
  until [ "$(docker logs "$DB" 2>&1 | grep -c 'ready for connections')" -ge 2 ]; do sleep 1; done
  if exists "$BACK"; then docker start "$BACK" >/dev/null; else
    # ADMIN_EMAILS: 시드가 책을 만들 수 있게 QA 계정만 관리자로. ALADIN_TTB_KEY는 크롤러 기동용 더미.
    docker run -d --name "$BACK" --network "$NET" -p 127.0.0.1:8008:8008 \
      -e DB_URL="jdbc:mariadb://$DB:3306/snippet" -e DB_USERNAME=snippet -e DB_PASSWORD="$DB_PASSWORD" \
      -e JWT_SECRET="$JWT_SECRET" -e ALADIN_TTB_KEY=qa-dummy -e ADMIN_EMAILS=qa@snippet.test \
      -e CORS_ALLOWED_ORIGINS=http://localhost:3000 --platform linux/amd64 "$BACK_IMAGE" >/dev/null
  fi
  for _ in $(seq 1 120); do
    curl -sf -o /dev/null "http://localhost:8008/api/appversion?platform=ios&version=1.0.0" && { echo "QA backend ready: http://localhost:8008"; return; }
    sleep 2
  done
  echo "백엔드가 뜨지 않음 — docker logs $BACK 확인" >&2; exit 1
}

seed() {
  load_env
  sql() { docker exec -i -e MYSQL_PWD="$DB_PASSWORD" "$DB" mariadb -usnippet -N snippet "$@"; }
  hash() { htpasswd -bnBC 10 "" "$1" | tr -d ':\n' | sed 's/^\$2y\$/$2a$/'; }
  # QA 계정은 비밀번호를 .qa.env 값으로 맞춘다 (가입 API는 메일 인증이 필요해서 DB에 직접 넣는다)
  printf "INSERT INTO user_tb (u_email,u_password,u_name) VALUES ('qa@snippet.test','%s','QA 테스터'),('writer@snippet.test','%s','문장 수집가') ON DUPLICATE KEY UPDATE u_password=VALUES(u_password);\n" \
    "$(hash "$QA_PASSWORD")" "$(hash "$WRITER_PASSWORD")" | sql
  python3 -I "$HERE/seed.py" "$HERE/books.json"   # 이미 서재가 있으면 seed.py가 건너뛴다
}

down() { docker stop "$BACK" "$DB" >/dev/null 2>&1 || true; echo "stopped"; }

reset() {
  docker rm -f "$BACK" "$DB" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
  rm -f "$ENV_FILE"; echo "reset"
}

case "${1:-}" in
  up) up ;; seed) seed ;; down) down ;; reset) reset ;;
  *) echo "usage: $0 up|seed|down|reset" >&2; exit 1 ;;
esac
