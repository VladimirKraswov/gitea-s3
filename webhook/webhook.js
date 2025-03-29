// webhook.js
const express = require('express');
const bodyParser = require('body-parser');
const fs = require('fs');
const crypto = require('crypto');

const app = express();
app.use(bodyParser.json());

// Конфигурация (можно вынести в .env)
const PORT = 4000;
const SECRET = process.env.WEBHOOK_SECRET || 'your-secret-key'; // Укажите свой секрет
const LOG_FILE = 'webhook.log';

// Создаем поток для записи логов
const logStream = fs.createWriteStream(LOG_FILE, { flags: 'a' });

// Middleware для проверки подписи
const verifySignature = (req, res, next) => {
  const signature = req.headers['x-gitea-signature'];
  if (!SECRET) {
    console.warn("⚠️ Секретный ключ не настроен, проверка подписи отключена");
    return next();
  }
  if (!signature) {
    const errorMsg = "❌ Подпись не предоставлена";
    log(errorMsg);
    return res.status(403).send(errorMsg);
  }

  const computedSignature = crypto
    .createHmac('sha256', SECRET)
    .update(JSON.stringify(req.body))
    .digest('hex');

  if (signature !== computedSignature) {
    const errorMsg = "❌ Неверная подпись";
    log(errorMsg);
    return res.status(403).send(errorMsg);
  }
  next();
};

// Функция логирования
const log = (message) => {
  const timestamp = new Date().toISOString();
  const logMessage = `${timestamp} - ${message}\n`;
  console.log(logMessage.trim());
  logStream.write(logMessage);
};

app.post('/hook', verifySignature, (req, res) => {
  try {
    const repoName = req.body.repository?.full_name || 'Не указано';
    const pusher = req.body.pusher?.username || 'Не указано';
    const commits = req.body.commits || [];

    log("📦 Получен пуш в репозиторий:");
    log(`🔸 Репозиторий: ${repoName}`);
    log(`🔸 Автор пуша: ${pusher}`);
    log(`🔸 Коммитов: ${commits.length}`);

    if (commits.length > 0) {
      log("🔹 Детали коммитов:");
      commits.forEach((commit, index) => {
        log(`  ${index + 1}. ${commit.message} (автор: ${commit.author?.username || 'Не указано'})`);
      });
    }

    res.status(200).send('OK');
  } catch (error) {
    log(`❌ Ошибка обработки webhook: ${error.message}`);
    res.status(500).send('Internal Server Error');
  }
});

app.listen(PORT, () => {
  log(`🚀 Webhook сервер слушает на http://localhost:${PORT}/hook`);
});

// Обработка завершения процесса
process.on('SIGINT', () => {
  log("🛑 Остановка сервера...");
  logStream.end();
  process.exit(0);
});