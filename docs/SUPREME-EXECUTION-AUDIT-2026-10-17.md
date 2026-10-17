# OSGARD SUPREME DIRECTOR — EXECUTION / QUALITY AUDIT 2026-10-17

## Канонический baseline и ownership

- Репозиторий, реально доступный для изменения: `osmanosmanov6880-bot/osgard-world`.
- `master` до интеграции серии PR #103–115: `b11f138d196bdc98bb95a8778c87db1ffda6ea6f`.
- Интеграционная рабочая ветка: `hardening/release-quality-fixes-2026-10-17`, PR #115 поверх PR #114. Ранее PR #103–114 образуют **зависимую цепочку черновиков**; их зелёный CI не означает их слияние.
- В списке репозиториев, доступных подключённому аккаунту GitHub на дату аудита, отдельные canonical GitHub repositories `KRAKEN`, `DevSwarm` и `OSGARD Command` **не найдены**. Не выводить отсюда, что исходники вообще отсутствуют или находятся в других системах.
- Файл `DIRECTOR_MASTER_180.md` задаёт шесть команд × 30 задач. Данная итерация ограничена общими процедурами качества сайта, а **не** исполнением 30 пакетов TITAN.

## Фактически изменённые компоненты (текущий PR)

| Область | Реальное изменение | Проверка |
|---|---|---|
| Staging HTTP | Блокировка follow-redirect до сетевого запроса; запрет приватных IP-literal | `tests/test_staging_operations.py` |
| GitHub CI evidence | Запрет перенаправлений GitHub API во время проверки run metadata | `tests/test_github_release_evidence.py` |
| Игровой ZIP | Ограниченное чтение ZION HTML и worlds.json | `tests/test_game_archive.py` |
| ZIP → manifest | Ограничения файлов/размеров и проверка case-collisions | `tests/test_zip_manifest_binding.py` |
| Core backup | Уникальный временный путь, private host staging, отказ при дубликате, trap очистки, sha256 | `tests/test_backup_shell_contract.py` |
| Cross-module CI | Единая проверка десяти основных семейств и тестов backup shell | `.github/workflows/integrated-quality-suite.yml` |

Инженерный статус перечисленного: `READY_FOR_REVIEW` при успешном CI, **не** `VERIFIED` и не `DEPLOYED`. Не выполнялись production deployment, реальные платежи, интеграционные операции на VPS, обработка настоящих резервных файлов пользователя.

## Разделение следующих задач по зависимости

### A — доступные и независимые внутри OSGARD WORLD
- Offline quality gates, negative/security regressions, исходный Vite build, проверка архива/маршрутов, static CI и документация.
- Модули этой ветки не вызывают production API или SSH; CI исполняется на тестовых фикстурах и публично проверяемых исходниках.

### B — требуют законченного A, управляемого staging и ответственного релиза
- Доверенное происхождение релизного ZIP, подписанная attestation, staging HTTP/браузерная E2E приёмка 19 игр, реальная проверка Core API и контроль отката.
- Слияние существующей цепочки PR по зависимостям только после проверки side effects: push в `master` может запустить собственные deploy workflows.

### C — заблокированные upstream
- `TITAN-X01…TITAN-X30`: нужны canonical source baseline KRAKEN, DevSwarm и Command и границы ownership. Не записывать OSGARD WORLD release-check код как исполнение Titan контрактов identity/tenant mapping, scheduler, sandbox, no-AI builder и т.д.
- Реальный Core backup/restore drill: требуется авторизованный тестовый Docker host и отдельная тестовая база.
- Production rollout и платежи: независимое утверждение и права исполнителя отсутствуют в этой итерации.

## QA и откат
- Команды: `python -m unittest discover -s tests -p test_backup_shell_contract.py -v`; `python -m unittest discover -s tests -p test_game_archive.py -v`; `python -m unittest discover -s tests -p test_zip_manifest_binding.py -v`; `python -m unittest discover -s tests -p test_staging_operations.py -v`.
- Workflow CI: `OSGARD Integrated Quality Suite`, `OSGARD Full Source Release Acceptance`, `OSGARD game archive contract`, `OSGARD verified release evidence`, `OSGARD ZIP manifest binding`, `OSGARD staging operations safety suite`. Реальные conclusions смотреть для точного head SHA, не переносить из других коммитов.
- Откат изменений данной ветки: не сливать PR; после merge — отдельный контролируемый revert merge-commit с проверкой CI. **Не** запускать слепой rollback действующей базы.
- Ротация ранее раскрытого SSH-ключа — отдельный P0 процесс с владельцем доступа. Не хранить его в исходниках, отчётах или CI.
