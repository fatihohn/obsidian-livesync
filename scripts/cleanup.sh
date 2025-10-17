#!/bin/bash

# 스크립트가 위치한 디렉토리의 상위 디렉토리 (프로젝트 루트)
PROJECT_ROOT=$(dirname "$(realpath "$0")")/..
BACKUP_DIR="${PROJECT_ROOT}/backups"

# 최대 용량 설정 (GB)
MAX_SIZE_GB=10
# GB를 바이트로 변환
MAX_SIZE_BYTES=$((MAX_SIZE_GB * 1024 * 1024 * 1024))

# 현재 사용량 확인 (바이트 단위)
CURRENT_SIZE=$(du -s "$BACKUP_DIR" | awk '{print $1}')
# du -s는 킬로바이트 단위일 수 있으므로, 1024를 곱해 바이트 단위로 근사
CURRENT_SIZE_BYTES=$((CURRENT_SIZE * 1024))

echo "백업 디렉토리: $BACKUP_DIR"
echo "최대 허용 용량: ${MAX_SIZE_GB}GB"
echo "현재 사용 용량: $(du -sh "$BACKUP_DIR" | awk '{print $1}')"

# 현재 사용량이 최대 용량을 초과하는 경우
while [ "$CURRENT_SIZE_BYTES" -gt "$MAX_SIZE_BYTES" ]; do
  # 가장 오래된 백업 파일 찾기 (이름순으로 정렬)
  OLDEST_FILE=$(ls -1 "$BACKUP_DIR"/backup-*.txt.gz | head -n 1)

  if [ -n "$OLDEST_FILE" ]; then
    echo "용량 초과. 가장 오래된 백업 파일 삭제: $OLDEST_FILE"
    rm "$OLDEST_FILE"
    
    # 현재 사용량 다시 계산
    CURRENT_SIZE=$(du -s "$BACKUP_DIR" | awk '{print $1}')
    CURRENT_SIZE_BYTES=$((CURRENT_SIZE * 1024))
  else
    echo "삭제할 백업 파일이 더 이상 없습니다."
    break
  fi
done

echo "백업 정리 완료."
