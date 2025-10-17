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
# --- 설정 끝 ---

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

# couchrestore 실행
gunzip -c "$BACKUP_FILE" | npx @cloudant/couchbackup --url "$DB_URL" --db "$DB_NAME"

echo "복원 완료."
