#!/usr/bin/env bash
set -euo pipefail

DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="./backups"
BACKUP_FILE="${BACKUP_DIR}/gitea_repos_backup_${DATE}.tar.gz"

mkdir -p "${BACKUP_DIR}"

echo "=== 💾 Бэкап всех .git репозиториев в ${BACKUP_FILE} ==="

tar -czf "${BACKUP_FILE}" -C /mnt/s3 .

echo "✅ Бэкап завершён!"
