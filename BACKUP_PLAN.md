# Obsidian LiveSync 데이터 백업 및 복원 계획

## 1. 개요

이 문서는 `obsidian-livesync`의 데이터(CouchDB 데이터베이스)를 안전하게 백업하고 필요할 때 복원하는 절차를 설명합니다. `@ibm-cloud/couchbackup` 라이브러리를 사용하여 데이터베이스의 전체 덤프를 파일로 생성하고, 이 파일을 사용하여 복원합니다.

- **백업**: 데이터베이스의 스냅샷을 `.txt.gz` 압축 파일로 저장합니다.
- **복원**: 백업 파일을 사용하여 데이터베이스를 특정 시점으로 복원합니다.
- **보안**: 데이터베이스 접속 정보는 `.env` 파일을 통해 안전하게 관리합니다.

## 2. 사전 준비

### 2.1. 백업 도구 설치
백업 및 복원 스크립트를 실행하기 위해 `node.js`와 `npm`이 설치되어 있어야 합니다. 다음 명령어를 실행하여 백업/복원 도구를 전역으로 설치합니다.

```bash
npm install -g @ibm-cloud/couchbackup
```

### 2.2. 접속 정보 설정 (.env)
프로젝트 루트 경로에 `.env.example` 파일을 복사하여 `.env` 파일을 생성합니다. 그리고 파일 내용을 자신의 CouchDB 환경에 맞게 수정합니다.

```bash
cp .env.example .env
```

`.env` 파일 내용 예시:
```
# CouchDB Credentials
COUCHDB_USER=admin
COUCHDB_PASSWORD=password
COUCHDB_HOST=127.0.0.1
COUCHDB_PORT=5984
COUCHDB_DATABASE=obsidian-livesync
```

## 3. 백업 방법

### 3.1. 백업 스크립트
`scripts/backup.sh` 스크립트는 프로젝트 루트의 `.env` 파일에서 접속 정보를 읽어와 백업을 수행합니다. 백업 파일은 `backups` 폴더에 저장됩니다.

### 3.2. 스크립트 실행 권한 부여
스크립트를 실행할 수 있도록 권한을 부여합니다.
```bash
chmod +x scripts/backup.sh
```

### 3.3. 백업 실행
```bash
./scripts/backup.sh
```

### 3.4. 정기적인 백업 설정 (Cron)
`cron`을 사용하여 백업 스크립트를 주기적으로 자동 실행할 수 있습니다. 예를 들어, 매일 새벽 2시에 백업을 실행하려면 `crontab -e`를 실행하고 다음 줄을 추가합니다.

```
0 2 * * * /home/opc/work/obsidian-livesync/scripts/backup.sh
```
*(스크립트의 절대 경로를 사용해야 합니다.)*

## 4. 복원 방법

**경고**: 복원은 데이터베이스를 백업 파일의 상태로 덮어씁니다. 복원하기 전에 현재 상태를 백업하는 것을 강력히 권장합니다.

### 4.1. 복원 스크립트
`scripts/restore.sh` 스크립트는 복원할 백업 파일의 경로를 인자로 받아 복원을 진행합니다.

### 4.2. 스크립트 실행 권한 부여
```bash
chmod +x scripts/restore.sh
```

### 4.3. 복원 실행
필요할 때 다음 명령어를 실행하여 데이터를 복원합니다.
```bash
./scripts/restore.sh /home/opc/work/obsidian-livesync/backups/backup-YYYYMMDD-HHMMSS.txt.gz
```
*(복원하려는 백업 파일의 실제 경로를 입력하세요.)*

## 5. 결론

위 스크립트와 절차를 통해 `obsidian-livesync`의 데이터를 안정적으로 관리할 수 있습니다. 정기적으로 백업이 잘 생성되는지 확인하고, 만일의 사태를 대비해 복원 절차를 미리 테스트해보는 것이 좋습니다.