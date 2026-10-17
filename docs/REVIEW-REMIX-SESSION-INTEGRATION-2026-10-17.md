# Интеграция PR #130: отдельные контракты REMIX и финальная приёмка

Дата: 17 октября 2026 года. Документ продолжает [приёмку Godot, REMIX и Core](GODOT-REMIX-CORE-ACCEPTANCE-2026-10-17.md) и [проверенное объединение с PR #129](REVIEW-MASTER-INTEGRATION-2026-10-17.md).

## Основание

Объединение с master `d7336b8e` прошло 324 Python-теста, raw/Pages матрицы 40/40 и 58 browser journeys. Его точный tree `708262663853766d0d63d52b39635484a60f35b3` сохранён коммитом `fbc7e1047504c4466684f2e9e352895241d0cbc0`, родители — `079d7bbe` и `d7336b8e`.

Непосредственно перед записью review-ветки проверка Git refs обнаружила новый master: `a92c764a4f5d5dd141246489d0dfa7531d85e7d7`, включающий [PR #130](https://github.com/osmanosmanov6880-bot/osgard-world/pull/130). Его изменения legacy REMIX, Unity quarantine и восстановления активации объединены с сохранённым кандидатом. Точный SHA, tree, соответствующий CI checkout и принятые artifacts фиксируются в [draft PR #128](https://github.com/osmanosmanov6880-bot/osgard-world/pull/128).

После завершения проверок master продвинулся до `3ce8041af080c66af5ce7e488f79622fa041b919` ([PR #131](https://github.com/osmanosmanov6880-bot/osgard-world/pull/131)). Дельта содержит только три документа о ранее опубликованном `a92c764a`; исходники, тесты, workflows и принятые dist/Pages snapshots не меняются. Эти записи сохранены как доказательства отдельного legacy-выпуска. Они не означают публикацию текущей Core-арены. Итоговое объединение включает эту документацию и сохраняет раздельные команды Core unit tests и настоящего HTTP recovery drill.

## Решение для REMIX

Старая консоль и новая арена первоначально использовали одинаковый `/api/remix/v1/`, но передавали разные данные и опирались на разные правила авторизации, ввода и результата. Направление этого prefix в один из сервисов нарушало бы другой контракт. Публичные адреса существующей консоли сохранены; новая арена получила собственный путь внутри Core.

| Продукт | UI | API и гарантии |
| --- | --- | --- |
| Существующая матч-консоль | `/games/remix/` | `/api/remix/` → `remix-guard:8081` → legacy `remix-api:8080`. Сохранены старые приглашения, восстановление сессии и проверка полученных DTO; guard фиксирует первые наблюдённые terminal state/result в отдельной SQLite. |
| Новая игровая арена | `/games/remix/arena/` | `/api/core/remix/v1/` → существующий Core proxy. Core bearer, обязательный проверочный заезд, публикация, идемпотентные операции и повторное вычисление результата по журналу ввода. Один игрок на заезд; сопоставляются отдельные попытки. |
| Unity | `/games/remix/player/` | Обычный маршрут показывает недоступность и не загружает движок. `?diagnostic=1` сохраняет исследовательский запуск с прежними ограничениями. Unity-приглашения возвращаются в существующую консоль. |

Все шесть файлов арены перенесены в `public/games/remix/arena/`. Её `remix-client.js` отличается от проверенного checkpoint только заменой API-prefix. Контроллер существующей консоли совпадает с PR #130; добавлен переход к игровой арене. Неиспользуемые прежние root-файлы арены удалены. Каталог, JSON-LD, обычный реестр запуска и lifecycle fallback/sharing ведут на один новый адрес.

На обеих страницах доступны понятные переходы между реализациями и к статусу Unity. Каталог описывает фактические четыре направления движения, прыжок и серверную проверку результата арены. Успешный запуск Unity engine не представлен как доступный игровой процесс.

### Граница HTTP

Существующий `location ^~ /api/core/` уже передаёт URI в Core без rewrite. Новый proxy или выбор upstream по наличию bearer не нужен. В Core сохранены host/origin guards, opt-in проверка до capabilities и проверка сессии до операций. Запросы к зарезервированным legacy-путям получают JSON 404 и не создают arena challenge даже при корректном Core bearer.

Core auth продолжает использовать `/api/core/auth/*`. Диагностическое поле арены read-only и не влияет на routing; Core credential не передаётся legacy API или analytics. `--remix`/`enable_remix` по умолчанию выключены, Compose и activation script не включают арену автоматически.

## CI и восстановление активации

Frontend/deploy validation сохраняют оба набора проверок: Core unittest, отдельный настоящий Core HTTP drill, Godot/binding, browser acceptance, а также incoming legacy session/guard/contract, activation recovery и Nginx delivery/guard. Integrated Quality Suite включает все 23 Python test families. Production deploy steps этих workflows не выполняются на событии `pull_request`.

Первый общий Python discovery обнаружил два сбоя SIGHUP в тестовой фикстуре активации. Среда передавала Python и Bash игнорирование HUP; Bash, запущенный с таким disposition, не устанавливал ожидаемый trap. Явный ignored-HUP родитель воспроизвёл те же два сбоя. Исправлен только тестовый launcher: свежий Python child восстанавливает HUP/INT/TERM перед `exec` Bash, сохраняя session/PID и реальные production traps. Таймауты и assertions сохранены; disposition основного runner не меняется, `preexec_fn` не используется. Добавлен отдельный сценарий запуска из ignored-HUP родителя. Production activation script сохранён из PR #130.

### Проверка единого PR после продвижения master

Первый свежий CI объединённого коммита `c726de890fd0060a6cd38b15651d9aa574f7ad71` прошёл все 376 Python-тестов, но Integrated Quality Suite остановился на старом live-аудите: PR #107 теперь конфликтует при самостоятельном объединении с master. Повторный GitHub API подтвердил `mergeable: false`; это не временный `null`. При этом реальные текущие head SHA всех 21 PR #107–127 уже входят в проверенный кандидат, что отдельно подтверждено по полной Git-истории.

Добавлен явный режим `--consolidated-pr 128` для единого draft review. Он проверяет канонические repo/refs, open/draft/mergeable кандидата, точный head из PR event, актуальный master ref и включение всех живых dependency heads. Проверки Git отвергают shallow/подменённую историю, отсутствующие commit и несовпадение дерева checkout. Повторно читаются все dependency PR, кандидат и master; наблюдаемое движение блокирует аудит. Две совпавшие выборки не являются атомарным snapshot всех GitHub refs. Default-политика самостоятельной цепочки сохранена и по-прежнему блокирует конфликтующий PR #107; результат нового режима называется отдельно `ready_for_consolidated_review`. Ни один режим не разрешает merge или deploy. Подробности и команды — в [контракте live-аудита](LIVE-RELEASE-PR-AUDIT.md).

Исправление аудита меняет только read-only audit, его тесты, Integrated workflow и документацию. Старый policy-файл сохранён побайтово; отдельные 38 live-audit tests, включая 7 исходных, и 9 legacy-policy tests прошли. Общий discovery после изменения содержит 407 успешных тестов. Свежий итоговый CI и artifact provenance фиксируются в PR #128; успешные проверки промежуточного `c726de89` не подменяют их.

### Сохранение последующего PR #132

Перед записью финального коммита master продвинулся до `5ee54cd9533db62c67c7b64cd1086cadf0a1e19b` ([PR #132](https://github.com/osmanosmanov6880-bot/osgard-world/pull/132)). Шесть incoming-файлов автоматически объединились без конфликтов. Новый последний `postbuild`-шаг объединяет полные стили SkillCred и порталов в прежнем каскадном порядке и убирает один отдельный CSS-запрос только на странице SkillCred. Сохранены новые OSA5 browser assertions и честное незакрытое требование Lighthouse Performance 100.

Повторный `npm run build` и свежая Pages-копия прошли binding/preflight. Полный SHA-256 inventory до/после подтвердил ровно два изменённых output-файла: `skillcred/index.html` и `skillcred/styles.css`; добавленных/удалённых файлов нет. Все остальные 427 файлов, включая игры, их движки, общие assets и REMIX, побайтово сохранены в raw и Pages вариантах. Поэтому предыдущие локальные игровые проверки сохраняют свой предмет проверки; точные итоговые полные матрицы и новые артефакты проверяются свежим CI финального SHA.

## Проверки объединённого кандидата

| Проверка | Результат |
| --- | --- |
| Общий Python discovery | **407 passed**, все 23 test families, **42,330 с**; отдельный финальный live-audit subset **38/38** |
| Core regression subset | 82 случая из предыдущего набора; входят в общий discovery |
| Core arena HTTP/simulation | **25/25 passed**, включая отрицательный namespace case |
| Legacy guard HTTP/SQLite | **24/24 passed** на loopback mutable fixture |
| Legacy service contract | **13/13 passed** |
| Activation recovery | **14/14 passed** при inherited ignored HUP; сигнальный subset **3/3** в обычной среде |
| Node game interface / arena growth / legacy session | **18/18**, **14/14**, **24/24 passed** |
| Legacy redirects/catalog integrity | **7/7 passed** |
| TypeScript + Vite + Godot binding + frontend/Pages preflight + build budgets | Passed |
| Общие redesign/navigation/OSA/deploy/ecosystem QA | **5/5 passed** |
| SkillCred после PR #132 | **3 targeted QA passed**; весь OSA5 browser suite: **26 маршрутов × 3 viewport**, **81 PNG**, `problems=[]`; один CSS-запрос/применённый stylesheet и mobile menu закрыто→открыто→закрыто |
| Arena auth/response-loss/restore/polling UI | **10/10 passed** на новых UI/API-путях, с настоящими HTTP faults и SQLite assertions |
| Локальная raw full game matrix | **40 passed, 0 failed, 0 blocked; totalAccepted=true**, 84 PNG; игровые байты сохранены после PR #132 |
| Локальная Pages full game matrix | **40 passed, 0 failed, 0 blocked; totalAccepted=true**, 84 PNG; игровые байты сохранены после PR #132 |
| Ecosystem browser journeys | **70 passed / 6 предусмотренных project skips**, 76 всего, **1,3 мин**, retries=0; включены incoming legacy-console scenarios |
| Core HTTP → WAL backup → restored HTTP process | **11/11 групп passed**, полный цикл **1 147,3 мс** |

Полные игровые матрицы используют настоящий временный Core/SQLite service, два аккаунта и реальные keyboard/touch inputs. Успешные игровые ответы не подменяются. Legacy browser scenarios отдельно используют контролируемые ответы для проверки своей клиентской state machine; HTTP/SQLite guard проверяется отдельными loopback tests. Эти виды доказательств не смешиваются.

Итоговая сборка после PR #132 содержит **429 файлов / 67 358 864 байт**. Точная Pages-копия после gzip упаковки содержит **429 файлов / 37 998 189 байт**. Все статические REMIX-файлы dist побайтово совпадают с замороженными исходниками. Godot source fingerprint остаётся `3c8e511873600c48963752ac6bfb2e807ca0a486a93d83f5271a6122c861509f`; новый перенос REMIX и bundling SkillCred не меняют его исходники. Связь PCK/WASM с `build-info.json` проверена в обоих вариантах доставки.

Повторный Core drill восстановил 503 808 байт и 44 таблицы. Подтверждены три аккаунта, один проект и участник, шесть ревизий, ассет, завершённое задание и запись затрат. Ревизия 6 включена в snapshot, последующая ревизия 7 исключена. Password/session auth, ACL, idempotent retry, новая HTTP-запись и окончательные SQLite integrity/FK прошли. Для публикации подходит только JSON-отчёт, без приватного work-dir.

## Воспроизведение

```sh
npm ci
npm run build:games
npm run qa:godot-export
python3 -m unittest discover -s tests -v
npm run qa:game-interface
npm run qa:remix-growth
npm run qa:remix-session
npm run qa:remix-legacy
python3 scripts/games-local-acceptance.py --dist dist --out test-results/pr130-raw
python3 scripts/remix-ui-acceptance.py --dist dist --out test-results/pr130-remix-ui
npx playwright test --config playwright.ecosystem.config.mjs --retries=0
npm run qa:core-recovery -- --work-dir /tmp/osgard-core-final-review --report /tmp/osgard-core-final-review.json
```

Для Pages создаётся отдельная копия dist, выполняются `compress-pages-wasm.mjs`, явная проверка Godot export и Pages preflight по пути этой копии, затем `games-local-acceptance.py --dist <pages-copy> --cloudflare-headers`. Принятый snapshot упаковывается с точным Git SHA. ZIP/manifest проверяются независимо, сравниваются две упаковки одного snapshot и выполняется `staging-release-acceptance.py`; состояние готовности — `ready_for_staging_review`. Это детерминизм упаковки в одной среде, а не утверждение об одинаковом PCK независимых rebuild.

## Границы результата

Кандидат остаётся в draft review. Master, production deployment, платежи и рабочие базы этой приёмкой не активируются. Core arena opt-in, legacy guard и Unity availability имеют самостоятельные состояния. Guard не заявляет Core-аутентификацию игроков, восстановление активных Go-матчей или проверенный полный replay. Core recovery drill не покрывает отдельную `osgard-remix-guard-data` volume и не измеряет production RTO/RPO. Локальная мобильная эмуляция не заменяет физические устройства. Nginx/Unity launcher checks выполняются в свежем CI; его точный checkout и artifacts проверяются отдельно от старых успешных runs.
