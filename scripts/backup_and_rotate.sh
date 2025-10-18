#!/bin/bash
set -euo pipefail

# 스크립트가 위치한 디렉토리의 상위 디렉토리 (프로젝트 루트)
PROJECT_ROOT=$(dirname "$(realpath "$0")")/..

BACKUP_DIR="$PROJECT_ROOT/backups"
MAX_SIZE_GB=10
MAX_SIZE_BYTES=$((MAX_SIZE_GB * 1024 * 1024 * 1024))

ENV_FILE="$PROJECT_ROOT/.env.backup"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
else
  echo "오류: $ENV_FILE 파일을 찾을 수 없습니다."
  exit 1
fi

echo "Starting backup and rotation process..."

# 1. backup.sh 실행
echo "Running backup.sh..."
"$PROJECT_ROOT/scripts/backup.sh"

echo "Backup completed. Checking directory size for rotation..."

# 2. 백업 디렉토리 용량 확인 및 로테이션
CURRENT_SIZE=$(du -sb "$BACKUP_DIR" | awk '{print $1}')

echo "Current backup directory size: $(echo "scale=2; $CURRENT_SIZE / (1024*1024*1024)" | bc) GB (Max: $MAX_SIZE_GB GB)"

if [ "$CURRENT_SIZE" -gt "$MAX_SIZE_BYTES" ]; then
  echo "Backup directory size exceeds ${MAX_SIZE_GB}GB. Starting rotation..."
  # 오래된 파일부터 삭제
  find "$BACKUP_DIR" -type f -name "backup-*.txt.gz" -printf '%T@ %p\n' | sort -n | head -n -1 | awk '{print $2}' | while read -r OLD_FILE; do
    if [ "$CURRENT_SIZE" -gt "$MAX_SIZE_BYTES" ]; then
      echo "Deleting old backup: $OLD_FILE"
      rm "$OLD_FILE"
      CURRENT_SIZE=$(du -sb "$BACKUP_DIR" | awk '{print $1}')
      echo "New backup directory size: $(echo "scale=2; $CURRENT_SIZE / (1024*1024*1024)" | bc) GB"
    else
      break
    fi
  done
  echo "Rotation complete."
else
  echo "Backup directory size is within limits. No rotation needed."
fi

# 3. 로테이션 이후 원격 서버로 최신 백업 전송
LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/backup-*.txt.gz 2>/dev/null | head -n 1 || true)

if [ -z "$LATEST_BACKUP" ]; then
  echo "경고: 전송할 백업 파일을 찾을 수 없습니다."
else
  if [ -n "${BACKUP_REMOTE_SERVER:-}" ] && [ -n "${BACKUP_REMOTE_DIR:-}" ]; then
    REMOTE_TARGET="${BACKUP_REMOTE_SERVER}"
    if [ -n "${BACKUP_REMOTE_USER:-}" ]; then
      REMOTE_TARGET="${BACKUP_REMOTE_USER}@${BACKUP_REMOTE_SERVER}"
    fi
    REMOTE_DIR="${BACKUP_REMOTE_DIR%/}"
    if [ -z "$REMOTE_DIR" ]; then
      REMOTE_DIR="/"
    fi

    echo "원격 서버로 최신 백업 전송: ${REMOTE_TARGET}:${REMOTE_DIR}"

    if ! ssh "$REMOTE_TARGET" "mkdir -p \"${REMOTE_DIR}\""; then
      echo "오류: 원격 디렉터리 생성에 실패했습니다 (${REMOTE_TARGET}:${REMOTE_DIR})" >&2
      exit 1
    fi

    if ! scp "$LATEST_BACKUP" "${REMOTE_TARGET}:${REMOTE_DIR}/"; then
      echo "오류: 원격 서버로 백업 파일 전송에 실패했습니다 (${REMOTE_TARGET}:${REMOTE_DIR})" >&2
      exit 1
    fi

    echo "원격 서버 전송 완료."
  else
    echo "원격 전송 설정이 비어 있어 로컬 백업만 유지합니다."
  fi
fi

echo "Backup and rotation process finished."
