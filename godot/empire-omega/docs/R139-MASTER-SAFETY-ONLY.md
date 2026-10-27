# EMPIRE Ω R139 — защитное исправление ПРОДАКШН-workflows без изменения игры

Дата: 27 октября 2026. **Объём этого PR: исключительно конфигурация релиза, проверочный код и этот документ.**

## Причина

В реальном `master` предыдущая `.github/workflows/omega-godot-web.yml` автоматически запускалась при `push` в `godot/empire-omega/**`, компилировала игру и могла записать новый WASM/PCK в публичный `master`. Второй исходный workflow `omega-web-direct-deploy.yml` реагировал на `workflow_run` frontend/Omega и мог загружать игру по SSH. Хотя новые условия GO появились в R138 на неопубликованной R90, **в самом действующем master старые workflow ещё не были устранены**.

## Что делает R139

- Дословно переносит уже прошедшие CI код и два workflow из R138 на отдельную ветку, основанную на текущем `master`. Новые `omega-godot-web.yml` и `omega-web-direct-deploy.yml` имеют **только `workflow_dispatch`**; никакого `push` или `workflow_run` для игры и SSH.
- Оба workflow вызывают один `scripts/omega-r138-manual-release-guard.py` **до** экспорта, установки ключа, сетевого соединения и записи в `master`. Для будущего ручного GO нужны одновременно `I_AUTHORIZE_OMEGA_PRODUCTION`, source SHA проверяемого `master`, отдельный ticket и независимо заданные администратором переменные `OMEGA_RELEASE_ENABLED=true`, `OMEGA_RELEASE_APPROVED_SHA`, `OMEGA_RELEASE_APPROVED_TICKET`, `OMEGA_RELEASE_ART_GO=APPROVED`, `OMEGA_RELEASE_GAMEPLAY_GO=APPROVED`, `OMEGA_RELEASE_PHYSICAL_GO=APPROVED`, `OMEGA_RELEASE_ROLLBACK_GO=APPROVED`. **Сейчас никакие переменные GO намеренно не создаются и не изменяются.**
- `scripts/test_omega_r138_release_lock.py` проверяет отказ в 21 отрицательном случае и отсутствие автоматических triggers; `.github/workflows/omega-r139-master-release-lock-qa.yml` дополнительно проверяет, что изменения затрагивают только 8 перечисленных путей и что `release.json` всё ещё содержит 7 точных SHA-256 оригинальной R87.

## R139: исправление устаревшего CI без ослабления безопасности

Исходная проверка `.github/workflows/omega-source-freshness-qa.yml` требовала автоматический SSH после изменения `omega-build-freshness.py`; на настоящем PR она завершилась ошибкой `no auto-trigger after guard correction`. Это не неисправность новой защиты: сам тест требовал устаревшего небезопасного поведения. Теперь он проверяет противоположное — **отсутствие** `push` и `workflow_run` в обоих выпускных workflows, выполнение R138 ручного guard до установки Godot/SSH, исходный runtime fingerprint, запрет при устаревшей сборке и отсутствие права случайного релиза. Код игры и `omega-build-freshness.py` не меняются. Новый защитный diff состоит ровно из **8** разрешённых файлов.

Второй оригинальный `OSGARD Omega R10` CI на реальном PR обнаружил два прежних утверждения в `scripts/omega-direct-publish.contract.test.mjs`: что экспорт всегда автоматически активирует SSH и что автоматический `workflow_run` является условием безопасности. Теперь вместо этого тестируются оба ручных `workflow_dispatch` с одинаковым исходным SHA, четырьмя независимыми отзывами, запретом запуска до проверки R138 и сохранёнными исходными SHA/SSH rollback контрактами. Код продукта и актуальные Godot сцены **не меняются**.

## Запреты и границы

1. **Не заменяются** `public/games/omega-3d-preview/index.html`, `index.js`, `index.pck`, `index.wasm` и остальные три файла; original source `43ae041e8df52418ca74c02405de9c196b59bd37`, оригинальные семь хешей и действующий public HTTPS R87 не должны измениться.
2. Никакой `master` игровой `Godot` source не переносится из черновика R90. Главный [PR #500](https://github.com/osmanosmanov6880-bot/osgard-world/pull/500) остаётся **DRAFT**.
3. После слияния защитного PR необходимо убедиться, что новый GitHub Actions `R139 MASTER hotfix safety` прошёл на точном SHA в master, что оба native/SSH workflow запускаются теперь **только вручную** и что публичный HTTPS readback по прежнему совпадает с R87. Полноценный hardware art/game/rollback GO сейчас не пройден.
4. Этот PR не является публикацией новой игры и не санкционирует ручной `workflow_dispatch`: ни одно из четырёх внешних доказательств не должно быть подменено самотестами CI. Нет разрешения использовать SSH, устанавливать production release flags или изменять VPS.

## Состояние последующих блоков

- B1 GAME: три настоящих независимых прохода на 15–20 минут и человеческая запись результатов сорока миссий.
- B2 ART: сравнение двух ранее утверждённых изображений с оригинальными скриншотами Godot на идентичных условиях, человеческое одобрение.
- B3 PHYSICAL: 36 оригинальных физических испытаний ПК/Android/iPhone с настоящими p50/p95/p99.
- B4 RELEASE: HTTPS origin/staging откат и независимый операторский GO после успешных B1–B3.

**Принцип:** меняется только способ будущей публикации; в данный момент игра для посетителей остаётся R87.
