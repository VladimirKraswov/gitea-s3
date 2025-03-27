// webhook.js
const express = require('express');
const bodyParser = require('body-parser');

const app = express();
app.use(bodyParser.json());

app.post('/hook', (req, res) => {
  console.log("📦 Получен пуш в репозиторий:");
  console.log(`🔸 Репозиторий: ${req.body.repository?.full_name}`);
  console.log(`🔸 Автор: ${req.body.pusher?.username}`);
  console.log(`🔸 Коммитов: ${req.body.commits?.length}`);
  res.status(200).send('OK');
});

app.listen(4000, () => {
  console.log("🚀 Webhook сервер слушает на http://localhost:4000/hook");
});
