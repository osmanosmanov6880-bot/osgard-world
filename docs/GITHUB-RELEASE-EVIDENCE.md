# Проверка свидетельств GitHub Actions — OSGARD

Модуль `scripts/verify-github-release-evidence.py` проверяет предоставленные результаты CI по GitHub API: точный repository, workflow name, head SHA, run ID, финальный статус и conclusion=success. Пять отдельных проверок обязательны. Результат `verified` **не означает разрешения на публикацию**.

Использование после настоящей сборки и внешней проверки архива:

```sh
python3 scripts/verify-github-release-evidence.py /private/evidence.json --repository osmanosmanov6880-bot/osgard-world --workflows /private/workflows.json
python3 -m unittest discover -s tests -p test_github_release_evidence.py -v
```

`workflows.json` содержит ключи `code_ci`, `frontend_ci`, `archive`, `backup_restore`, `smoke` и точные названия реальных workflow GitHub. Устанавливает ответственный аудитор по релизу. Не загружайте настоящие секреты или персональные данные в Git.

Проверяются live сведения GitHub о workflow run, но **не** результаты отдельных job, provenance артефакта, доверенность runner, статус GitHub environment approval, подписи или независимое восстановление производства. API может ответить rate limit; это блокировка, а не разрешение на выпуск. Нужен отдельный этап связывания CI-артефакта с неизменяемым SHA, а также защита от переписанного workflow. Тесты используют только локальный фальшивый GitHub API и не используют токены. Production API, DNS, платежи, сервер, ключи и базу не меняем.

Важно: PR #107 ещё не объединён с master. Данный модуль — дополнительная проверка в интеграционной ветке, а не самостоятельный real-world release.
