Вот обновленная версия `README.md` с учетом текущего состояния проекта и исправлениями для большей ясности. Я также добавил раздел про проверку синхронизации с S3, как вы просили, и обновил структуру в соответствии с последними изменениями:

```markdown
## 📘 Gitea + S3 (s3fs) — приватный Git-сервер с S3-хранилищем

Этот проект разворачивает [Gitea](https://gitea.io) в Docker с **хранением всех Git-репозиториев в S3-бакете** через `s3fs`.

### 📦 Возможности:
- Автоматическая установка Gitea с привязкой к S3
- Репозитории хранятся в S3 как `bare .git`
- Веб-интерфейс для управления репозиториями
- Поддержка Debian и Ubuntu
- Дополнительные утилиты:
  - `check-sync.sh` — проверка синхронизации с S3
  - `backup.sh` — бэкап репозиториев
  - `webhook.js` — сервер для обработки событий Gitea

---

## 🛠️ Установка

> Требования: Linux-сервер (Debian/Ubuntu) с root-правами. Скрипт сам установит `docker`, `docker-compose` и `s3fs`, если их нет.

1. Клонируйте репозиторий:
```bash
git clone https://github.com/VladimirKraswov/gitea-s3.git
cd gitea-s3
```

2. Создайте файл `.env` с конфигурацией:
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

3. Создайте `docker-compose.yml`:
```yaml
version: "3"
services:
  gitea:
    image: gitea/gitea:latest
    container_name: gitea
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__server__DOMAIN=${GITEA_DOMAIN}
      - GITEA__server__HTTP_PORT=3000
      - GITEA__server__SSH_PORT=22
      - GITEA__repository__ROOT=${REPOS_PATH}
    ports:
      - "3000:3000"
      - "222:22"
    volumes:
      - /mnt/s3:/data/git/repositories
      - ./data:/data
    restart: unless-stopped
```

4. Запустите установку:
```bash
sudo bash install.sh
```

После установки Gitea будет доступна по адресу:
```
http://your-server-ip:3000
```

---

## 🧪 Проверка синхронизации с S3

1. Создайте тестовый репозиторий в Gitea:
   - Войдите в `http://your-server-ip:3000`.
   - Нажмите «+» → «New Repository» → создайте `test-repo`.

2. Проверьте локально:
```bash
ls -la /mnt/s3/<username>/test-repo.git
```
Ожидается структура Git-репозитория (`HEAD`, `config`, `objects`).

3. Проверьте в S3 (нужен `s3cmd`):
```bash
sudo apt-get install -y s3cmd
s3cmd --configure  # Укажите ключи и endpoint из .env
s3cmd ls s3://your-bucket-name/<username>/test-repo.git/
```
Ожидается наличие объектов репозитория.

4. Используйте `check-sync.sh`:
```bash
chmod +x check-sync.sh
./check-sync.sh
```
Скрипт проверит монтирование S3, работу Gitea и наличие репозиториев.

---

## 💾 Резервное копирование (`backup.sh`)

Архивирует содержимое S3 в `backups/gitea_repos_backup_<дата>.tar.gz`:
```bash
chmod +x backup.sh
./backup.sh
```

---

## 🔔 Webhook-сервер (`webhook.js`)

Уведомления при `git push`.

1. Установите зависимости:
```bash
cd webhook/
npm install
```

2. Запустите:
```bash
node webhook.js
```

3. Настройте в Gitea:
   - Репозиторий → Settings → Webhooks → Add Webhook
   - URL: `http://your-server-ip:4000/hook`
   - Тип: `application/json`
   - События: `Push Events`

---

## 📂 Структура проекта

```bash
gitea-s3/
├── install.sh             # Установщик
├── .env                   # Переменные окружения
├── docker-compose.yml     # Конфигурация Docker
├── data/                  # Данные Gitea
├── check-sync.sh          # Проверка синхронизации
├── backup.sh              # Бэкап
├── webhook/
│   ├── webhook.js         # Webhook-сервер
│   └── package.json
├── backups/               # Бэкапы (.tar.gz)
```

---

## 🔄 Обновление

```bash
cd gitea-s3
docker compose down
git pull
sudo bash install.sh
```

---

## 📌 Примечания

- `s3fs` монтирует S3 в `/mnt/s3`.
- Репозитории хранятся как bare `.git`-структуры.
- В UI S3 (например, Beget) видны только объекты Git, а не обычные файлы.
- Для тестов вне `.git` добавьте файлы вручную (например, `s3cmd put README.md s3://your-bucket-name/`).
```

### Что изменилось:
1. **Установка**: Добавлено создание `docker-compose.yml` как отдельный шаг, так как он больше не генерируется скриптом.
2. **Проверка синхронизации**: Добавлен новый раздел с инструкциями по проверке работы S3, включая использование `s3cmd` и `check-sync.sh`.
3. **Требования**: Уточнено, что скрипт поддерживает Debian и Ubuntu.
4. **Структура**: Обновлена в соответствии с последними изменениями проекта.
5. **Ясность**: Улучшены инструкции и форматирование.

Если у вас есть конкретные пожелания по добавлению или изменению чего-то в `README.md`, дайте знать!