#!/usr/bin/env bash
set -euo pipefail

echo "=== 🔍 Проверка синхронизации Gitea и S3 ==="

# Проверка монтирования
if mount | grep -q '/mnt/s3'; then
  echo "✅ S3 смонтировано в /mnt/s3"
else
  echo "❌ S3 не смонтировано!"
  exit 1
fi

# Проверка, что контейнер Gitea запущен
if docker ps --format '{{.Names}}' | grep -q '^gitea$'; then
  echo "✅ Контейнер Gitea запущен"
else
  echo "❌ Контейнер Gitea не запущен!"
  exit 1
fi

# Поиск всех .git репозиториев в S3
echo "🔍 Репозитории в /mnt/s3:"
find /mnt/s3 -type d -name "*.git" | while read -r repo; do
  echo "🗂️ Найден: $repo"
  ls -1 "$repo" | grep -E 'HEAD|objects|refs' || echo "⚠️ Внимание: $repo может быть неполным"
done

echo "✅ Проверка завершена."
