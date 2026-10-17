# Интеграция нового master в release candidate OSGARD

Дата: 17 октября 2026 года. Этот отчёт продолжает [приёмку Godot, REMIX и Core](GODOT-REMIX-CORE-ACCEPTANCE-2026-10-17.md) и описывает объединение с изменениями [PR #129](https://github.com/osmanosmanov6880-bot/osgard-world/pull/129).

## Основание и идентичность кандидата

Проверенный implementation commit — `079d7bbe415a32d1229963c5b3372b96c101c10f`, tree `23de63c61d9149b5813c92d35c1d8e8d7efdc9ca`. Во время работы фактический `refs/heads/master` продвинулся до `d7336b8e0b43b027fadf4ad2ce2e0b218bc558fa` после PR #129. Ответ API карточки PR #128 продолжал показывать прежний base SHA `b11f138…`; отдельная проверка Git refs и локальное сравнение обнаружили расхождение на четыре master-коммита и девять конфликтных файлов. Для `079d7bbe` новые Actions runs отсутствовали, PR имел состояние `dirty`.

Объединение выполнено в отдельном checkout review-ветки. Родители интеграционного коммита: `079d7bbe` и `d7336b8e`. Ref `master` эта работа не меняет. Точный SHA результата, его tree, свежие CI runs и контрольные суммы принятого ZIP фиксируются в [draft PR #128](https://github.com/osmanosmanov6880-bot/osgard-world/pull/128). Результаты прежних SHA не считаются результатами этого коммита.

## Решения при объединении

| Область | Итоговое поведение |
| --- | --- |
| INHERIT | Сохранены восстановление локального мира, same-origin API, история, RU/EN guide и действительно скрытые закрытые панели. Один обработчик острова обслуживает стрелки, Enter и Space; просмотр прошлого и системные сочетания не размещают след. |
| REMIX | Единственный authoritative `remix-client.js` сохраняет Core auth, pending operation, idempotency, восстановление заезда, проверку результата/повтора и защиту от старого polling response. Новый `interface.js` отвечает за представление RU/EN. |
| Unity | Сохранены отдельный launcher, кнопки/focus/error recovery и точные адреса экспортных `.wasm`, `.framework.js`, `.data`. Переход к Unity доступен в верхней навигации REMIX. |
| Core | Offline verifier проверяет Core schema по умолчанию; generic SQLite доступен только явно. Manifest binding, online WAL backup, изолированное восстановление и настоящий HTTP drill сохранены. |
| Pilot | Схема CSV v2 заменяет раннюю v1: парные отношения полного времени, валюта/сложность, pre/post на новых заданиях, затраты непарных провалов, происхождение входного файла. Численные критерии не означают разрешение масштабирования. |
| Общие страницы | Сохранены исправления холодных fragment-ссылок, синхронизации фильтров с навигацией, фокуса после удаления карточки и прогресса OSA при позднем отказе storage. |
| Доставка | Сохранены Nginx priority/gzip/MIME для Unity и JSON 404 для неизвестных API. В CI проверяются настоящие адреса загрузчика на отдельном Nginx-контейнере. |

### Конфликты поведения, которые не решаются выбором одной версии файла

Автоматическое объединение `package.json` создало два одинаковых ключа `qa:core-recovery`: один незаметно перекрывал другой. Теперь `qa:core-recovery-tests` запускает все Core unittest families, а `qa:core-recovery` — полный HTTP drill с обязательным новым `--work-dir`. Frontend/deploy validation вызывают оба; dedicated Core workflow сохраняет только безопасный JSON.

В INHERIT одновременно оставались два keyboard handlers. Один Enter мог создать два следа. Дублирующий inline handler удалён; Space, replay guard и ARIA перенесены в новый интерфейс. Service worker обновлён до `inherit-shell-v7`, сохраняет interface assets и очищает только старые кэши своего продукта.

Входящий REMIX interface зависел от прежних `send`/`apiInput` и добавлял вторые элементы управления. Он переработан в слой представления вокруг существующей арены. Keyboard handler привязан к фокусу canvas; перемещение по остальной странице сохраняет обычное поведение. Диагностическое поле endpoint закрыто по умолчанию и read-only. Исполнение настоящих `request()` и `reportEvent()` проверяет, что даже подмена его DOM-значения не меняет origin запроса и не передаёт Core credential в analytics.

Визуальная проверка промежуточного desktop INHERIT выявила перекрытие истории и инструментов: flex-колонка инструментов сжималась при длинных названиях и нескольких соседних действиях. Раскладка исправлена; browser regression проверяет реальные прямоугольники видимых элементов управления. Отрицательная проверка на прежнем dist воспроизвела дефект: край кнопки `More traces +6` находился на 339,75 px при допустимой границе группы 309,03 px. Исправленная сборка прошла проверку containment, отсутствия пересечений и минимального размера 44×44 px для RU/EN на desktop/mobile. Промежуточная игровая матрица могла пройти функциональные действия при этом дефекте, поэтому окончательная приёмка использует сборку после исправления геометрии.

### Совместимость Core и измерений

`verify-core-backup.py` поддерживает `--sha256`, `--manifest`, прежний `--require-core` и новый `--sqlite-only`; противоречивые режимы отклоняются. Python API сохраняет явный `require_core=False` для generic-диагностики. Наличие manifest всегда включает проверку Core. Отчёт сохраняет оба набора полей и не заявляет запуск приложения, RTO или RPO от простого чтения SQLite.

Единый Core schema contract включает необходимые Commerce columns/FKs, в том числе время начала refund operation. Источник открывается через descriptors родительских каталогов с `O_NOFOLLOW`. Сохраняются ограничения размера/времени, запрет перезаписи, проверка sidecars, целостности, связей и metadata, а также очистка только собственных файлов. Входящие тесты восстановления Checkout/Refund, webhook и внутренних build/release операций выполняются отдельно с FakeProvider; реальных платежей они не проводят.

Pilot CSV v1 не преобразуется в v2 подстановкой вымышленных нулей. Полное время учитывает непересекающиеся категории выполнения, исправлений и помощи; 20 пар — предлагаемое значение протокола, доступное через `--minimum-pairs`. `numeric_targets_met`/`ready_for_review` сообщают вычисляемый результат; `ready_for_scale_decision` остаётся false. Данные тестов синтетические.

## Приёмка объединённого кандидата

| Проверка | Результат |
| --- | --- |
| Общий Python suite | **324 passed**, 20 семейств, без ошибок/пропусков; 9,757 секунды |
| Core regression subset | **82/82**: 57 backup recovery, 5 restored operations, 15 shell contract, 5 HTTP; входят в 324 |
| Pilot v2 | **17/17**, входят в 324 |
| TypeScript, сборка, Godot binding, frontend preflight | Passed |
| Целевые npm QA | **10/10**: redesign, ZION, navigation, OSA progress, game interface, REMIX growth, deploy workflow, build budgets, games portal, ecosystem |
| Game interface / REMIX growth | **14/14** и **14/14**, с исполнением реальных обработчиков |
| REMIX lost-response/auth/restore/polling UI | **10/10**; SQLite counts и исходные идентификаторы подтверждены |
| Raw full game matrix | **40/40 passed, 0 failed, 0 blocked**, `totalAccepted=true`; 243,894 секунды |
| Exact Pages package game matrix | **40/40 passed, 0 failed, 0 blocked**, `totalAccepted=true`; 239,228 секунды |
| Ecosystem browser journeys | **58 passed, 6 skipped**, 56,8 секунды; без повторов. Шесть пропусков обусловлены отдельными desktop-only/mobile-only профилями |
| Core HTTP → WAL backup → restored HTTP process | **11/11 групп**, источник продолжает работать, новая запись в восстановленном процессе сохраняется |

Общий Python suite и REMIX UI выполнены на замороженных исходниках соответствующих подсистем. Последующая визуальная правка относится только к INHERIT CSS и его browser assertion. Окончательные raw/Pages матрицы и journeys используют сборку с этой правкой.

Каждая полная матрица включает 38 catalog cases (19 игр × desktop/mobile) и два дополнительных lightweight cases, сохраняет 84 PNG и отдельные JSON результатов. Перед ней на временном настоящем Core/REMIX HTTP-сервере проходят 16 API-проверок. Запросы к прочим origin блокируются и отражаются отдельно. Завершение финальных матриц: raw — 10:37:46 UTC, Pages — 10:37:57 UTC; desktop/mobile journeys — 58 прошедших сценариев без retries. Реальный Godot runtime прошёл во всех четырёх сочетаниях профиля доставки и устройства, без page errors, console errors и failed resources.

В финальном raw dist **426 файлов / 67 273 717 байт**; в его Pages-копии — **426 файлов / 37 913 042 байта**. Проверены build/source binding и Pages preflight. Локальная среда: Node 24.19.0, Python 3.12.14, zlib 1.3.2. Full Source CI использует Node 22, Cloudflare CI — Node 20. Детерминизм двух упаковок одного snapshot не означает побайтовую идентичность независимых rebuild в этих разных средах.

Godot собран штатным checksum-pinned helper в отдельном checkout; native runtime smoke и source/artifact binding прошли. Исходные 21 файл имеют SHA-256 `3c8e511873600c48963752ac6bfb2e807ca0a486a93d83f5271a6122c861509f`. Каждый новый PCK проверяется по своему `build-info.json`; побайтовая тождественность PCK между разными checkout здесь не заявляется. Raw WASM — 39 514 754 байта, gzip — 10 153 810 байт с подтверждённым обратным преобразованием.

Отдельный Core drill создал три аккаунта, проект, участника, шесть ревизий, ассет, завершённое задание и запись затрат. Snapshot — 503 808 байт, 44 таблицы. Восстановлена ревизия 6; более поздняя ревизия 7 источника исключена. Подтверждены password/session auth, owner/viewer/outsider/anonymous ACL, связи данных, idempotent retry и новая HTTP-запись. Полный локальный цикл занял 1 133,51 мс; это измерение на новых тестовых данных. Для артефактов используется только JSON, без баз и сессий.

## Воспроизведение

Из корня checkout с Node 22, Python 3.12 и Chromium из locked Playwright:

```sh
npm ci
npm run build:games
npm run qa:godot-export
python3 -m unittest discover -s tests -v
npm run qa:game-interface
npm run qa:remix-growth
npm run qa:games-local -- --out test-results/master-final-raw
npm run qa:remix-ui -- --out test-results/master-final-remix-ui
npx playwright test --config playwright.ecosystem.config.mjs
npm run qa:core-recovery -- --work-dir /tmp/osgard-core-review --report /tmp/osgard-core-review.json
```

Для Pages проверяют отдельную копию того же `dist`, выполняют `node scripts/compress-pages-wasm.mjs <pages-copy>`, затем `python3 scripts/build-null-shift-godot.py --verify-export <pages-copy>/games/null-shift-godot`, `node scripts/cloudflare-pages-preflight.mjs <pages-copy>` и `python3 scripts/games-local-acceptance.py --dist <pages-copy> --cloudflare-headers --out <evidence-dir>`. Пути к копии указываются явно: npm shortcuts по умолчанию читают `dist`. Bundle создаётся с точным Git SHA и независимо проверяется по manifest/ZIP; результат должен иметь `ready_for_staging_review`. Nginx delivery gate требует Docker и выполняется в CI.

## Границы результата

Этот кандидат предназначен для review. Он не сливает PR #128 в master, не запускает production deploy, не включает оплаты и не восстанавливает рабочую базу. Существующий внешний Unity backend остаётся отдельной интеграцией; новый opt-in REMIX ruleset его не сертифицирует. INHERIT shared-world и необязательные analytics сохраняют собственные unavailable/not-tested статусы в отчётах, когда соответствующий сервис не доступен. Published staging, реальные устройства и drill с production-backup требуют отдельных свидетельств.
