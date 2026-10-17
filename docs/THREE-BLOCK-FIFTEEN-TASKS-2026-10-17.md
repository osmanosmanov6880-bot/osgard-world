# OSGARD — три инженерных блока × пять задач, 17.10.2026

Baseline: `osmanosmanov6880-bot/osgard-world`, stacked on PR #118 at `ee0f74342de2e6ed99340519cf7db2595ca47edd`. Target: `engineering/three-block-fifteen-tasks-2026-10-17`. Scope: **релизный контур OSGARD WORLD**, не отдельный KRAKEN/DevSwarm repository.

## Блок A — проверяемая release policy
1. Заменить простой список PASS на versioned schema v2 в `scripts/release-matrix.py`.
2. Требовать валидный commit SHA для релизного кандидата.
3. Требовать валидный SHA-256 релизного файла.
4. Привязать каждый обязательный сигнал к exact commit и ZIP SHA.
5. Требовать подтверждаемую ссылку GitHub Actions и запрещать лишние gate keys, живые платежи и auto-approval.

Реализовано в исходнике и в `tests/test_staging_operations.py`. **Ограничение:** проверка URL носит синтаксический характер. Подлинность GitHub API запуска проверяется отдельным `verify-github-release-evidence.py`; release matrix сама не обращается в сеть.

## Блок B — безопасность rollback
6. Rollback evidence переведён на schema v2.
7. Требуется отдельный current commit и previous commit, причём они должны различаться.
8. Контролируются previous ZIP digest и backup digest.
9. Требуются пять положительных организационных подтверждений восстановления, окна, оператора и доступности предыдущего релиза.
10. Оплаты обязательно выключены; `rollback_executed` может быть только false, результат не вызывает операцию восстановления.

Реализовано в `scripts/rollback-readiness.py`; negative cases добавлены в `tests/test_staging_operations.py`. Это проверка предоставленных attestations, не настоящий production rollback.

## Блок C — проверка реального dist
11. Проверка отсутствующего или symlink-root `dist`.
12. Проверка существования обязательных `_headers`, `_redirects`, `robots.txt`, без symlink.
13. Fail-closed проверка читаемости `_headers` и наличия двух базовых security headers.
14. Рекурсивное обнаружение secret-like файлов **и директорий** (`.env.*`, `.ssh`, `.git`).
15. Блокировка symlinks и специальных файлов в собранной структуре; negative tests на nested secrets и linked root.

Реализовано в `scripts/release-config-audit.py`, `tests/test_staging_operations.py`, используется существующим `.github/workflows/full-source-release-acceptance.yml` при сборке настоящего frontend.

## Приёмка / откат

Запуск:
```sh
python3 -m unittest discover -s tests -p test_staging_operations.py -v
python3 -m unittest discover -s tests -p test_staging_release_acceptance.py -v
python3 scripts/release-config-audit.py dist
```

Тестировать до merge в CI. Нет production deploy, DNS-изменений, файлов заказчиков или активных платежей. Откат — оставить draft PR unmerged или сделать controlled revert самого PR после независимого review. Для обоснованного релиза дополнительно нужны staging URL, browser E2E и восстановление Core на изолированном хосте.

Статусы по пакету: изменения кодовой базы `READY_FOR_REVIEW` после успешного CI; «реальная публикация» `NOT_DONE`.
