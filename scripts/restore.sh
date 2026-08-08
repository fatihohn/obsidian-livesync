#!/bin/bash
set -euo pipefail

# 스크립트가 위치한 디렉토리의 상위 디렉토리 (프로젝트 루트)
PROJECT_ROOT=$(dirname "$(realpath "$0")")/..
export PATH="$PROJECT_ROOT/node_modules/.bin:$PATH"

# .env 파일 로드
ENV_FILE="$PROJECT_ROOT/.env.backup"
if [ -f "$ENV_FILE" ]; then
  set -a # Automatically export all variables
  source "$ENV_FILE"
  set +a
else
  echo "오류: $ENV_FILE 파일을 찾을 수 없습니다."
  echo ".env.example 파일을 복사하여 .env 파일을 생성하고, 접속 정보를 입력해주세요."
  exit 1
fi

# 필수 변수 확인
: "${COUCHDB_USER?COUCHDB_USER 변수를 .env 파일에 설정해주세요.}"
: "${COUCHDB_PASSWORD?COUCHDB_PASSWORD 변수를 .env 파일에 설정해주세요.}"
: "${COUCHDB_HOST?COUCHDB_HOST 변수를 .env 파일에 설정해주세요.}"
: "${COUCHDB_PORT?COUCHDB_PORT 변수를 .env 파일에 설정해주세요.}"
: "${COUCHDB_DATABASE?COUCHDB_DATABASE 변수를 .env 파일에 설정해주세요.}"

# Node.js 바이너리 경로 보강 (필요 시 NODE_BIN_DIR 환경변수 사용)
ensure_node() {
  if command -v node >/dev/null 2>&1; then
    return 0
  fi
  if [ -n "${NODE_BIN_DIR:-}" ] && [ -x "${NODE_BIN_DIR}/node" ]; then
    export PATH="${NODE_BIN_DIR}:$PATH"
  elif [ -n "${NVM_DIR:-}" ] && [ -s "${NVM_DIR}/nvm.sh" ]; then
    # shellcheck disable=SC1090
    source "${NVM_DIR}/nvm.sh"
    if command -v nvm >/dev/null 2>&1 && [ -n "${NVM_DEFAULT_VERSION:-}" ]; then
      nvm use "${NVM_DEFAULT_VERSION}" >/dev/null
    fi
  fi

  if ! command -v node >/dev/null 2>&1; then
    echo "오류: node 명령을 찾을 수 없습니다. NODE_BIN_DIR 혹은 NVM 관련 변수를 설정해주세요."
    exit 1
  fi
}

ensure_node

# --- 설정 ---
DB_URL="http://${COUCHDB_USER}:${COUCHDB_PASSWORD}@${COUCHDB_HOST}:${COUCHDB_PORT}"
DB_NAME="${COUCHDB_DATABASE}"
# --- 설정 끝 ---

# couchrestore 실행 바이너리 자동 감지 (환경변수 → PATH → 로컬 번들 → npx 순서)
declare -a COUCHRESTORE_CMD
if [ -n "${COUCHRESTORE_BIN:-}" ]; then
  if command -v "$COUCHRESTORE_BIN" >/dev/null 2>&1 || [ -x "$COUCHRESTORE_BIN" ]; then
    COUCHRESTORE_CMD=("$COUCHRESTORE_BIN")
  else
    echo "오류: 지정한 COUCHRESTORE_BIN('$COUCHRESTORE_BIN') 명령을 찾을 수 없습니다."
    exit 1
  fi
elif command -v couchrestore >/dev/null 2>&1; then
  COUCHRESTORE_CMD=(couchrestore)
elif [ -x "$PROJECT_ROOT/node_modules/.bin/couchrestore" ]; then
  COUCHRESTORE_CMD=("$PROJECT_ROOT/node_modules/.bin/couchrestore")
elif command -v npx >/dev/null 2>&1; then
  COUCHRESTORE_CMD=(npx --yes -p @cloudant/couchbackup couchrestore)
  echo "알림: npx를 사용하여 @cloudant/couchbackup 패키지를 임시 실행합니다."
else
  echo "오류: couchrestore 명령을 찾을 수 없습니다. 'npm install -g @cloudant/couchbackup' 또는 프로젝트에 의존성을 추가해주세요."
  exit 1
fi

# 복원할 백업 파일 경로를 첫 번째 인자로 받음
BACKUP_FILE=$1

if [ -z "$BACKUP_FILE" ]; then
  echo "오류: 복원할 백업 파일의 경로를 입력하세요."
  echo "사용법: ./restore.sh <백업 파일 경로>"
  exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "오류: 파일을 찾을 수 없습니다 - $BACKUP_FILE"
    exit 1
fi

echo "복원 시작: $BACKUP_FILE -> $DB_NAME"
echo "경고: 5초 후에 데이터베이스를 덮어씁니다. 중지하려면 Ctrl+C를 누르세요."
sleep 5

# Reset database so couchrestore can import into a clean target
echo "데이터베이스 초기화 중: $DB_NAME"
if curl -fs "$DB_URL/$DB_NAME" > /dev/null; then
  echo "기존 데이터베이스를 삭제합니다..."
  if ! curl -fs -X DELETE "$DB_URL/$DB_NAME" > /dev/null; then
    echo "오류: 기존 데이터베이스 삭제에 실패했습니다."
    exit 1
  fi
fi

echo "빈 데이터베이스를 생성합니다..."
if ! curl -fs -X PUT "$DB_URL/$DB_NAME" > /dev/null; then
  echo "오류: 새 데이터베이스 생성에 실패했습니다."
  exit 1
fi
# couchrestore 실행
gunzip -c "$BACKUP_FILE" | "${COUCHRESTORE_CMD[@]}" --url "$DB_URL" --db "$DB_NAME" --buffer-size 50

echo "복원 완료."
