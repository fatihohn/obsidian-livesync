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
BACKUP_DIR="${PROJECT_ROOT}/backups"
# --- 설정 끝 ---

# couchbackup 실행 바이너리 자동 감지 (환경변수 → PATH → 로컬 번들 → npx 순서)
declare -a COUCHBACKUP_CMD
if [ -n "${COUCHBACKUP_BIN:-}" ]; then
  if command -v "$COUCHBACKUP_BIN" >/dev/null 2>&1 || [ -x "$COUCHBACKUP_BIN" ]; then
    COUCHBACKUP_CMD=("$COUCHBACKUP_BIN")
  else
    echo "오류: 지정한 COUCHBACKUP_BIN('$COUCHBACKUP_BIN') 명령을 찾을 수 없습니다."
    exit 1
  fi
elif command -v couchbackup >/dev/null 2>&1; then
  COUCHBACKUP_CMD=(couchbackup)
elif [ -x "$PROJECT_ROOT/node_modules/.bin/couchbackup" ]; then
  COUCHBACKUP_CMD=("$PROJECT_ROOT/node_modules/.bin/couchbackup")
elif command -v npx >/dev/null 2>&1; then
  COUCHBACKUP_CMD=(npx --yes -p @cloudant/couchbackup couchbackup)
  echo "알림: npx를 사용하여 @cloudant/couchbackup 패키지를 임시 실행합니다."
else
  echo "오류: couchbackup 명령을 찾을 수 없습니다. 'npm install -g @cloudant/couchbackup' 또는 프로젝트에 의존성을 추가해주세요."
  exit 1
fi

# 백업 디렉토리 생성
mkdir -p "$BACKUP_DIR"

# 파일 이름에 타임스탬프 추가 (타임존은 .env.backup의 BACKUP_TIMEZONE 사용)
: "${BACKUP_TIMEZONE?BACKUP_TIMEZONE 변수를 .env.backup 파일에 설정해주세요.}"
TIMESTAMP=$(TZ="$BACKUP_TIMEZONE" date +"%Y%m%d-%H%M%S")
BACKUP_FILE="$BACKUP_DIR/backup-$TIMESTAMP.txt.gz"

echo "백업 시작: $DB_NAME -> $BACKUP_FILE"

# couchbackup 실행
"${COUCHBACKUP_CMD[@]}" --url "$DB_URL" --db "$DB_NAME" | gzip > "$BACKUP_FILE"

echo "백업 완료."
