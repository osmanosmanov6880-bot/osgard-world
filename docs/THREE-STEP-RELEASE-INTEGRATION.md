# Трёхэтапная интеграционная приёмка OSGARD — 17 октября 2026

## Шаг 1. Проверенная карта зависимостей PR
Базовый `master` на момент проверки: `b11f138d196bdc98bb95a8778c87db1ffda6ea6f`. Открыты PR #103–117. 

- #103 pilot scorecard, #104 backup recovery, #105 ZIP safety, #106 release evidence — независимые PR от `master`.
- #107 — копия исходников #103–106 в одну интеграционную ветку. **Не сливать #103–106 поверх #107 без review дублей.**
- #108 → #109 → #110 → #111 → #112 → #113 → #114 → #115 → #116 → #117 — последовательные stacked PR. Каждый основан на head предыдущего, кроме #108, который основан на #107.
- Текущая ветка — последующий интеграционный шаг после #117. Изменения ещё не приняты в `master`.

## Шаг 2. Устранение двойного запуска проверок в релизе
Общий инструмент `scripts/staging-release-acceptance.py` проверяет:
1. настройки готового `dist` через существующий audit;
2. ZIP и манифест через уже проверенный bundle validator;
3. 19 игровых точек входа через существующий валидатор.

В `full-source-release-acceptance.yml` ранее отдельные вызовы config и game-archive объединены в **один контролируемый шаг**, отдельный ранний ZIP→manifest validation оставлен для диагностируемости. Инструменты не дублируются новыми реализациями, повторно используются прежние исходники.

## Шаг 3. Реальная staging-приёмка до публикации
Workflow выполняет `npm ci` → `npm run build` → ZION source QA → выпуск приватного временного ZIP+манифеста → две независимые проверки → единый offline staging admission. Все запуски происходят на GitHub runner без изменения DNS, Core production database или Cloudflare.

Команда для локальной приёмки после сборки:
```sh
python3 scripts/staging-release-acceptance.py --dist dist --zip /private/osgard-release.zip --manifest /private/manifest.json
python3 -m unittest discover -s tests -p test_staging_release_acceptance.py -v
```

**Нельзя утверждать live staging PASS:** реальный staging URL не был опубликован этим workflow; проверка 19 игровых entrypoints не равна браузерным проверкам на устройствах, а SHA коммита в манифесте не криптографическая attestation.

## Production safety / merge audit
В `.github/workflows/deploy-frontend.yml` есть `push: master` с фильтром путей. Среди триггеров: `scripts/core-*.py`, `server/**`, `public/games/**`, `src/**`, множество docs/website paths. Даже merge «без релиза» может вызвать публикацию, если затронуты эти пути. В `.github/workflows/cloudflare-pages.yml` push в `master` запускает сборку; публикация Pages там отдельно требует `workflow_dispatch`, но это не гарантия безопасности других workflow.

Следующий этап — независимый review полного diff против master, политика branch protection, целевой staging URL и ручное решение релизного оператора. Критерий `ready_for_staging_review` **не означает** `production_approved`.
