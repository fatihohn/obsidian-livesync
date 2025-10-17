#!/bin/bash

# 스크립트가 위치한 디렉토리의 상위 디렉토리 (프로젝트 루트)
PROJECT_ROOT=$(dirname "$(realpath "$0")")/..

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

# 백업 디렉토리 생성
mkdir -p "$BACKUP_DIR"

# 파일 이름에 타임스탬프 추가
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
BACKUP_FILE="$BACKUP_DIR/backup-$TIMESTAMP.txt.gz"

echo "백업 시작: $DB_NAME -> $BACKUP_FILE"

# npx를 사용하여 couchbackup 실행
npx @cloudant/couchbackup --url "$DB_URL" --db "$DB_NAME" | gzip > "$BACKUP_FILE"

echo "백업 완료."
