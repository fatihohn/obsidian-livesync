#!/bin/bash

# 스크립트가 위치한 디렉토리의 상위 디렉토리 (프로젝트 루트)
PROJECT_ROOT=$(dirname "$(realpath "$0")")/..

BACKUP_DIR="$PROJECT_ROOT/backups"
MAX_SIZE_GB=10
MAX_SIZE_BYTES=$((MAX_SIZE_GB * 1024 * 1024 * 1024))

echo "Starting backup and rotation process..."

# 1. backup.sh 실행
echo "Running backup.sh..."
"$PROJECT_ROOT/scripts/backup.sh"
BACKUP_STATUS=$?

if [ $BACKUP_STATUS -ne 0 ]; then
  echo "backup.sh failed. Exiting rotation process."
  exit $BACKUP_STATUS
fi

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

echo "Backup and rotation process finished."
