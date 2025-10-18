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

# 선택적으로 원격 서버로 백업 파일 전송
if [ -n "${BACKUP_REMOTE_SERVER:-}" ] && [ -n "${BACKUP_REMOTE_DIR:-}" ]; then
  REMOTE_TARGET="${BACKUP_REMOTE_SERVER}"
  if [ -n "${BACKUP_REMOTE_USER:-}" ]; then
    REMOTE_TARGET="${BACKUP_REMOTE_USER}@${BACKUP_REMOTE_SERVER}"
  fi
  REMOTE_DIR="${BACKUP_REMOTE_DIR%/}"
  if [ -z "$REMOTE_DIR" ]; then
    REMOTE_DIR="/"
  fi

  echo "원격 서버로 전송 준비: ${REMOTE_TARGET}:${REMOTE_DIR}"

  if ! ssh "$REMOTE_TARGET" "mkdir -p \"${REMOTE_DIR}\""; then
    echo "오류: 원격 디렉터리 생성에 실패했습니다 (${REMOTE_TARGET}:${REMOTE_DIR})" >&2
    exit 1
  fi

  if ! scp "$BACKUP_FILE" "${REMOTE_TARGET}:${REMOTE_DIR}/"; then
    echo "오류: 원격 서버로 백업 파일 전송에 실패했습니다 (${REMOTE_TARGET}:${REMOTE_DIR})" >&2
    exit 1
  fi

  echo "원격 서버 전송 완료."
else
  echo "원격 전송 설정이 비어 있어 로컬 백업만 수행했습니다."
fi
