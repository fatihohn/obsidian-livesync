# 백업 및 로테이션 설정 가이드

이 문서는 `obsidian-livesync` 프로젝트의 CouchDB 백업을 주기적으로 수행하고, 백업 파일의 용량을 관리(로테이션)하는 방법을 설명합니다. 백업 디렉토리의 총 용량이 10GB를 초과하지 않도록 가장 오래된 백업 파일을 자동으로 삭제합니다.

## 1. 백업 및 로테이션 스크립트 생성

`scripts/backup_and_rotate.sh` 파일을 생성하고 다음 내용을 추가합니다. 이 스크립트는 기존 `backup.sh`를 실행한 후, 백업 디렉토리의 용량을 확인하여 로테이션을 수행합니다.

```bash
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
```

## 2. 스크립트 실행 권한 부여

생성한 스크립트가 실행될 수 있도록 권한을 부여합니다.

```bash
chmod +x /home/opc/work/obsidian-livesync/scripts/backup_and_rotate.sh
```

## 3. Cron Job 설정

`crontab`에 주기적인 백업 및 로테이션 작업을 추가합니다.

1.  터미널에서 다음 명령어를 실행하여 `crontab` 편집기를 엽니다.
    ```bash
    crontab -e
    ```

2.  파일의 마지막에 다음 줄을 추가합니다. 이 설정은 매일 새벽 2시에 스크립트를 실행하도록 합니다.
    ```cron
    0 2 * * * /home/opc/work/obsidian-livesync/scripts/backup_and_rotate.sh >> /home/opc/work/obsidian-livesync/backups/backup.log 2>&1
    ```
    *   `0 2 * * *`: `분 시 일 월 요일` 순서입니다. `0 2`는 새벽 2시 0분을 의미합니다. 필요에 따라 실행 시간을 변경할 수 있습니다.
    *   `/home/opc/work/obsidian-livesync/scripts/backup_and_rotate.sh`: 생성한 스크립트의 절대 경로입니다.
    *   `>> /home/opc/work/obsidian-livesync/backups/backup.log 2>&1`: 스크립트의 모든 출력(표준 출력 및 에러 출력)을 `/home/opc/work/obsidian-livesync/backups/backup.log` 파일에 추가합니다. 이를 통해 백업 작업의 성공 여부 및 로테이션 과정을 확인할 수 있습니다.

3.  파일을 저장하고 편집기를 종료합니다.

## 4. 로그 확인

크론 작업이 제대로 실행되는지 확인하려면 `backups/backup.log` 파일을 주기적으로 확인하십시오.

```bash
tail -f /home/opc/work/obsidian-livesync/backups/backup.log
```
