## 📘 Gitea + S3 (s3fs) — приватный Git-сервер с S3-хранилищем

Этот проект разворачивает [Gitea](https://gitea.io) в Docker с **хранением всех Git‑репозиториев в S3-бакете** (через `s3fs`).

### 📦 Возможности:
- Автоматическая установка Gitea с привязкой к S3
- Репозитории хранятся в S3 как `bare .git`
- Веб-интерфейс для управления репозиториями
- Дополнительные утилиты:
  - `check-sync.sh` — проверка синхронизации
  - `backup.sh` — бэкап репозиториев
  - `webhook.js` — сервер для обработки событий Gitea

---

## 🛠️ Установка

> Требования: Linux-сервер с root правами, все остальное `docker`, `docker-compose`, `s3fs` устанавливается скриптом

1. Клонируй репозиторий:

```bash
git clone https://github.com/your-user/gitea-s3.git
cd gitea-s3
```

2. Создай файл `.env` с конфигурацией:

```env
# S3 доступ
S3_BUCKET=your-bucket-name
S3_ENDPOINT=https://s3.your-storage-provider.com
S3_ACCESS_KEY=your-access-key
S3_SECRET_KEY=your-secret-key

# Пути
MOUNT_PATH=/mnt/s3
REPOS_PATH=/data/git/repositories
DATA_VOLUME=./data

# Gitea
GITEA_DOMAIN=your-server-ip-or-domain
GITEA_HTTP_PORT=3000
GITEA_SSH_PORT=222
SERVICE_NAME=gitea
```

3. Запусти установку:

```bash
sudo bash install.sh
```

После установки Gitea будет доступна по адресу:
```
http://your-server-ip:3000
```

---

## 🧪 Проверка синхронизации (`check-sync.sh`)

Проверяет:
- Смонтирован ли S3
- Запущен ли контейнер Gitea
- Существуют ли `.git`-репозитории в бакете

```bash
chmod +x check-sync.sh
./check-sync.sh
```

---

## 💾 Резервное копирование (`backup.sh`)

Архивирует содержимое S3 в `backups/gitea_repos_backup_<дата>.tar.gz`:

```bash
chmod +x backup.sh
./backup.sh
```

---

## 🔔 Webhook-сервер (`webhook.js`)

Уведомления при каждом `git push`.

1. Установи зависимости:

```bash
cd webhook/
npm install
```

2. Запусти:

```bash
node webhook.js
```

3. Добавь в Gitea UI:
- Репозиторий → Settings → Webhooks → Add Webhook
- URL: `http://your-server-ip:4000/hook`
- Тип: `application/json`
- События: `Push Events`

---

## 📂 Структура проекта

```bash
gitea-s3/
├── install.sh             # Главный установщик
├── .env                   # Переменные окружения
├── docker-compose.yml     # Автоматически генерируется
├── data/                  # Область данных Gitea
├── check-sync.sh          # Проверка работы и синхронизации
├── backup.sh              # Бэкап репозиториев
├── webhook/
│   ├── webhook.js         # Webhook сервер
│   └── package.json
├── backups/               # Сюда кладутся .tar.gz бэкапы
```

---

## 🔄 Обновление

```bash
docker compose down
git pull
sudo bash install.sh
```

---

## 📌 Примечания

- `s3fs` используется для монтирования S3 в файловую систему.
- Репозитории представлены в виде bare `.git`-структуры.
- Из-за особенностей Git-объектов вы не увидите обычные `.txt` в UI Beget — только папки с объектами.
- Для просмотра в UI добавьте в бакет обычные файлы вручную (например, `README.md` вне `.git`).