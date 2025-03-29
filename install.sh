#!/usr/bin/env/bash
set -eo pipefail  # Убираем -u, чтобы не завершаться на unbound variables

echo "=== 🚀 Запуск установщика Gitea + S3 (s3fs) ==="

# Определение дистрибутива
if grep -qi "debian" /etc/os-release; then
  DISTRO="debian"
  CODENAME=$(grep -oP '(?<=VERSION_CODENAME=).+' /etc/os-release)
elif grep -qi "ubuntu" /etc/os-release; then
  DISTRO="ubuntu"
  CODENAME=$(grep -oP '(?<=VERSION_CODENAME=).+' /etc/os-release)
else
  echo "❌ Этот скрипт поддерживает только Debian и Ubuntu."
  exit 1
fi
echo "> 🖥️ Обнаружен дистрибутив: ${DISTRO} (${CODENAME})"

# 1. Проверка наличия файла .env и загрузка переменных
if [ ! -f .env ]; then
  echo "❌ Файл .env не найден! Создайте файл .env с необходимыми переменными."
  exit 1
fi
source .env

# Проверка обязательных параметров
for var in S3_BUCKET S3_ENDPOINT S3_ACCESS_KEY S3_SECRET_KEY MOUNT_PATH GITEA_DOMAIN GITEA_HTTP_PORT GITEA_SSH_PORT SERVICE_NAME DATA_VOLUME REPOS_PATH GITEA_ADMIN_USERNAME GITEA_ADMIN_PASSWORD GITEA_ADMIN_EMAIL; do
  eval "value=\$$var"  # Используем eval для получения значения переменной
  if [ -z "$value" ]; then
    echo "❌ Ошибка: Переменная ${var} не задана в .env."
    exit 1
  fi
done

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
echo "  GITEA_ADMIN_USERNAME = ${GITEA_ADMIN_USERNAME}"
echo "  GITEA_ADMIN_EMAIL   = ${GITEA_ADMIN_EMAIL}"
echo

# Остальной код остается без изменений...
# 2. Настройка репозитория Docker
echo "> 📦 Настраиваем репозиторий Docker для ${DISTRO}..."
if [ -f /etc/apt/sources.list.d/docker.list ]; then
  echo "> 🧹 Удаляем старый репозиторий Docker..."
  rm -f /etc/apt/sources.list.d/docker.list
fi
apt-get update -y
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
if [ "$DISTRO" = "debian" ]; then
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
elif [ "$DISTRO" = "ubuntu" ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
fi
apt-get update -y

# 3. Проверка и установка необходимых инструментов
echo "> 🛠️ Проверяем и устанавливаем необходимые инструменты..."
MISSING_TOOLS=""
command -v docker >/dev/null 2>&1 || MISSING_TOOLS="${MISSING_TOOLS} docker.io"
command -v docker-compose >/dev/null 2>&1 || MISSING_TOOLS="${MISSING_TOOLS} docker-compose"
command -v s3fs >/dev/null 2>&1 || MISSING_TOOLS="${MISSING_TOOLS} s3fs"

if [ -n "$MISSING_TOOLS" ]; then
  echo "⚠️ Отсутствуют инструменты:${MISSING_TOOLS}"
  echo "> 📦 Устанавливаем их..."
  apt-get install -y apparmor-utils $MISSING_TOOLS
else
  echo "> ✅ Все необходимые инструменты (docker, docker-compose, s3fs) уже установлены."
fi

# 4. Настройка /etc/passwd-s3fs
echo "> 🔐 Настраиваем /etc/passwd-s3fs..."
echo "${S3_ACCESS_KEY}:${S3_SECRET_KEY}" > /etc/passwd-s3fs
chmod 600 /etc/passwd-s3fs

# 5. Монтирование S3
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

# 6. Удаление локальной директории, перекрывающей volume
HOST_REPOS_DIR="${DATA_VOLUME}/$(basename ${REPOS_PATH})"
if [ -d "${HOST_REPOS_DIR}" ]; then
  echo "> ⚠️ Удаляем локальную директорию, которая может перекрыть volume: ${HOST_REPOS_DIR}"
  rm -rf "${HOST_REPOS_DIR}"
fi

# 7. Остановка и удаление предыдущего контейнера (если есть)
if docker ps -a --format '{{.Names}}' | grep -q "^${SERVICE_NAME}$"; then
  echo "> 🧹 Удаляем предыдущий контейнер ${SERVICE_NAME}..."
  if [ -f docker-compose.yml ]; then
    docker compose down || docker rm -f "${SERVICE_NAME}"
  else
    docker rm -f "${SERVICE_NAME}"
  fi
fi

# 8. Проверка наличия docker-compose.yml
if [ ! -f docker-compose.yml ]; then
  echo "❌ Ошибка: файл docker-compose.yml не найден в текущей директории."
  exit 1
fi

# 9. Запуск через существующий docker-compose.yml
echo "> 🚀 Запускаем Gitea..."
docker compose up -d

echo
echo "=== ✅ Установка завершена! ==="
echo "🌐 Открой: http://${GITEA_DOMAIN}:${GITEA_HTTP_PORT}"
echo "📁 Репозитории будут храниться в ${REPOS_PATH}, смонтированном на ${MOUNT_PATH} (S3)"
echo "👤 Админ: ${GITEA_ADMIN_USERNAME} (${GITEA_ADMIN_EMAIL})"
if [ "${GITEA_DISABLE_REGISTRATION}" = "true" ]; then
  echo "🔒 Регистрация отключена. Новые пользователи добавляются через админ-панель."
else
  echo "🔓 Регистрация включена."
fi
echo
echo "🔧 Настройки Gitea автоматически установлены через переменные окружения"
echo "🧪 Проверка: ls -la ${MOUNT_PATH}"