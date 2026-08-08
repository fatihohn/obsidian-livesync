#!/bin/bash
set -euo pipefail

# 스크립트가 위치한 디렉토리의 상위 디렉토리 (프로젝트 루트)
PROJECT_ROOT=$(dirname "$(realpath "$0")")/..
BACKUP_DIR="$PROJECT_ROOT/backups"

# .env.backup 파일 로드
ENV_FILE="$PROJECT_ROOT/.env.backup"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
else
  echo "오류: $ENV_FILE 파일을 찾을 수 없습니다."
  exit 1
fi

if [ -z "${BACKUP_REMOTE_SERVER:-}" ] || [ -z "${BACKUP_REMOTE_DIR:-}" ]; then
  echo "오류: .env.backup 파일에 원격 서버 설정이 없습니다."
  exit 1
fi

REMOTE_TARGET="${BACKUP_REMOTE_SERVER}"
if [ -n "${BACKUP_REMOTE_USER:-}" ]; then
  REMOTE_TARGET="${BACKUP_REMOTE_USER}@${BACKUP_REMOTE_SERVER}"
fi
REMOTE_DIR="${BACKUP_REMOTE_DIR%/}"

echo "동기화 시작: 로컬(${BACKUP_DIR}) -> 원격(${REMOTE_TARGET}:${REMOTE_DIR})"

# rsync를 사용하여 NAS에 없는 파일만 전송 (진행률 표시)
if ! rsync -avz --ignore-existing --progress "$BACKUP_DIR"/backup-*.txt.gz "${REMOTE_TARGET}:${REMOTE_DIR}/"; then
  echo "오류: 동기화 도중 문제가 발생했습니다. NAS 상태를 확인해주세요."
  exit 1
fi

echo "동기화 완료. 로컬의 모든 최신 백업이 NAS에 전송되었습니다."
