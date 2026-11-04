# NEBULA R42 — owner-directed exact binary release

**Дата:** 2026-11-04  
**Статус:** ПРОИЗВОДСТВЕННАЯ ПУБЛИКАЦИЯ ПРОШЛА: GitHub SSH workflow #41847979367, независимый публичный HTTPS SHA parity #41848297900.  
**Аппаратный QA:** NOT PERFORMED. Испытаний на реальных iPhone/Android не было; эмуляция Chromium ими не является.

## Цель

Публикация R42 (три бесплатных капитана Ада/Кай/Лея с действующими бонусами физики/награды и сохранением выбора). R43 (система поражения) в этот выпуск **не включена**.

## Исходный и бинарный артефакты

- Ревью и изменения: PR #720: https://github.com/osmanosmanov6880-bot/osgard-world/pull/720
- Нативный Godot, браузерный полёт, мобильная эмуляция с реальной физикой: https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41844286188 — success.
- Merge исходников: `c7b63eb041eea9e36d84a6d69af6406666e4e0d0`.
- Godot Web экспорт на master: https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41845777254 — success.
- Коммит Web экспорта: `449eb944fcbcadbb0622ef402157fad16fb9149e`.

| Файл | Git blob SHA-1 | Размер из GitHub |
|---|---|---|
| index.html | 213ec7ed214cc27f865f9e0408ec7a30ca80a165 | 13995 |
| index.js | c84b7de50f26f0dd21bd4b2885de851a3ea6ff39 | 279815 |
| index.wasm | 8f900d00d644a698bbce67439bf6daf73bdfa4b7 | 39514754 |
| index.pck | 8ed3d65816f87139ed2a742097d764c0a4973686 | 5765640 |

Файлы сравнивает `scripts/nebula-production-artifact-guard.mjs` перед SSH-копированием. Нельзя подменять его проверку удачным статусом тестов без совпадения байтов.

## Допуск и ограничения

- Владелец поручил продолжать разработку и публиковать игру напрямую (R39/R41 по той же процедуре); физический риск принят как `owner_directed_release`, но это **не** сертификат R40.
- R40 продолжает требовать отдельные подтверждения человека и физические журналы устройств; gate для R40 не ослаблен.
- Новый generic GitHub Actions workflow `.github/workflows/nebula-public-release-parity.yml` автоматически проверяет четыре файла с публичного HTTPS после успешного SSH-деплоя, помимо внутреннего Nginx.
- Не затронуты денежные права Stripe и остальная система OSGARD.
- При ошибке deployment workflow должен остановиться/откатить, а версия R41 должна остаться рабочей.

## Фактический выпуск

Пока не заполнен: CI релизного PR, SSH запуск, HTTPS parity и проверка на аппаратных устройствах фиксируются отдельно.

## Зафиксированные факты после выпуска

- PR релизной политики #725 merged to master: `bb03d23633388f64ad9f6f654eea7addf63f9c57`.
- Production asset guard CI: https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41847978875 — **success**.
- Изолированный SSH deploy, проверка Nginx и уборка rollback staging: https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41847979367 — **success**.
- Первоначальная post-deploy проверка HTTPS #41848113621 завершилась неудачей по причине ошибки скрипта проверки: не был включён идентификатор R42 в белый список вариантов. **Это не было несовпадением хешей файлов**. Исправлено в коммите `a51ccdb1e3650a628dbb95df085ca92cf29017f5`.
- Повторный независимый публичный HTTPS паритет четырёх реальных файлов: https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41848297900 — **success**, все четыре Git blob identities совпали с опубликованным R42 allowlist.
- **Физические Android/iPhone:** NOT PERFORMED. В CI использовался настоящий Godot/WebGL в Chromium с программным renderer/touch emulation, это не аппаратный device test.
- R43 ship-failure/retry **не включён** в R42 и остаётся в отдельном PR #723, который требует своего CI и нового точного выпуска.
