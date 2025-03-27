#!/usr/bin/env bash
set -euo pipefail

echo "=== 🚀 Запуск установщика Gitea + S3 (s3fs) ==="

# 1. Проверка наличия файла .env и загрузка переменных
if [ ! -f .env ]; then
  echo "❌ Файл .env не найден! Создайте файл .env с необходимыми переменными."
  exit 1
fi
source .env

echo "📦 Загружена конфигурация:"
echo "  S3_BUCKET       = ${S3_BUCKET}"
echo "  S3_ENDPOINT     = ${S3_ENDPOINT}"
echo "  MOUNT_PATH      = ${MOUNT_PATH}"
echo "  GITEA_DOMAIN    = ${GITEA_DOMAIN}"
echo "  GITEA_HTTP_PORT = ${GITEA_HTTP_PORT}"
echo "  GITEA_SSH_PORT  = ${GITEA_SSH_PORT}"
echo "  SERVICE_NAME    = ${SERVICE_NAME}"
echo "  DATA_VOLUME     = ${DATA_VOLUME}"
echo "  REPOS_PATH      = ${REPOS_PATH}"
echo

# 2. Установка необходимых пакетов
echo "> 🛠️ Устанавливаем необходимые пакеты..."
apt-get update -y
apt-get install -y apparmor-utils s3fs docker.io docker-compose

# 3. Настройка /etc/passwd-s3fs
echo "> 🔐 Настраиваем /etc/passwd-s3fs..."
echo "${S3_ACCESS_KEY}:${S3_SECRET_KEY}" > /etc/passwd-s3fs
chmod 600 /etc/passwd-s3fs

# 4. Монтирование S3
echo "> ⏏ Отмонтируем ${MOUNT_PATH} (если уже смонтировано)..."
umount "${MOUNT_PATH}" 2>/dev/null || true

echo "> 📁 Создаём каталог монтирования ${MOUNT_PATH}..."
mkdir -p "${MOUNT_PATH}"

echo "> 🔗 Монтируем S3-бакет ${S3_BUCKET} в ${MOUNT_PATH}..."
s3fs "${S3_BUCKET}" "${MOUNT_PATH}" \
  -o passwd_file=/etc/passwd-s3fs \
  -o url="${S3_ENDPOINT}" \
  -o use_path_request_style \
  -o allow_other \
  -o nonempty \
  -o uid=1000 \
  -o gid=1000 \
  -o umask=0002

if mount | grep -q "on ${MOUNT_PATH} type fuse.s3fs"; then
  echo "> ✅ S3 успешно смонтировано в ${MOUNT_PATH}."
else
  echo "❌ Ошибка: S3 не смонтировано. Проверьте лог выше."
  exit 1
fi

# 5. Удаление локальной директории, перекрывающей volume
HOST_REPOS_DIR="${DATA_VOLUME}/$(basename ${REPOS_PATH})"
if [ -d "${HOST_REPOS_DIR}" ]; then
  echo "> ⚠️ Удаляем локальную директорию, которая может перекрыть volume: ${HOST_REPOS_DIR}"
  rm -rf "${HOST_REPOS_DIR}"
fi

# 6. Генерация docker-compose.yml
echo "> 🧾 Генерируем docker-compose.yml..."
cat <<EOF > docker-compose.yml
version: "3"

services:
  ${SERVICE_NAME}:
    image: gitea/gitea:latest
    container_name: ${SERVICE_NAME}
    environment:
      - USER_UID=1000
      - USER_GID=1000
    ports:
      - "${GITEA_HTTP_PORT}:3000"
      - "${GITEA_SSH_PORT}:22"
    volumes:
      - ${MOUNT_PATH}:${REPOS_PATH}
      - ${DATA_VOLUME}:/data
EOF

echo "> 📄 Содержимое docker-compose.yml:"
cat docker-compose.yml
echo

# 7. Остановка и удаление предыдущего контейнера (если есть)
if docker ps -a --format '{{.Names}}' | grep -q "^${SERVICE_NAME}$"; then
  echo "> 🧹 Удаляем предыдущий контейнер ${SERVICE_NAME}..."
  docker compose down || docker rm -f "${SERVICE_NAME}"
fi

# 8. Запуск
echo "> 🚀 Запускаем Gitea..."
docker compose up -d

echo
echo "=== ✅ Установка завершена! ==="
echo "🌐 Открой: http://${GITEA_DOMAIN}:${GITEA_HTTP_PORT}"
echo "📁 Репозитории будут храниться в ${REPOS_PATH}, смонтированном на ${MOUNT_PATH} (S3)"
echo
echo "🔧 Убедись, что в настройках Gitea 'Repository Root Path' = ${REPOS_PATH}"
echo "🧪 Проверка: ls -la ${MOUNT_PATH}"
