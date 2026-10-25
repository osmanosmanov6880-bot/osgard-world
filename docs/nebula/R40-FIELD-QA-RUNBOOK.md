# OSGARD NEBULA — R40: аппаратная приёмка и безопасный финальный выпуск

**Проверено 25 октября 2026 года.** Действующий production остаётся на R38. R40 — отдельный проверенный игровой кандидат, пока не разрешённый к замене R38.

## Блок 1 — две настоящие HTTPS-версии

- R38 production: https://osgard.world/games/remix/arena-v2/nebula-3d/
- R40 staging для физических испытаний: https://osgard.world/games/remix/nebula-r40-qa/
- Лаборатория сравнения FPS (загруженные JSON обрабатываются локально): https://osgard.world/games/remix/arena-v2/nebula-3d/performance-report.html
- Финальный кандидат: PR #375 https://github.com/osmanosmanov6880-bot/osgard-world/pull/375
- Исходный успешный Godot/WebAssembly CI: https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40173218842
- Успешная staging-публикация по SSH: https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40175191370

GitHub подтвердил проверку контрольных сумм оригинального игрового пакета и успешную внутреннюю HTTP-проверку Nginx. Внешняя загрузка из каждой сети и на каждом телефоне этим не доказывается. Не используйте закрытые PR #342 или #371 вместо PR #375.

Ожидаемая маркировка JSON кандидата: build_variant = NEBULA_R40_BRIDGE_BATCH_3X32. Закреплённый исходный коммит R40: 9efb03c246a28a168886e2aa494872e907ea78cd.

## Блок 2 — полноценный цикл физических испытаний

Минимум три реальных устройства: один слабый Android, один средний/высокий Android и iPhone Safari.

На каждом устройстве:

1. Открыть обе версии по HTTPS и проверить настоящий игровой полёт, коллизии, светильники мостов, читаемость HUD и касания.
2. Для каждой версии, вертикального и горизонтального положения, ручного MAX/HIGH/ECO выполнить по три независимых 20-секундных измерения. Не использовать AUTO.
3. Повторять одинаковый игровой маршрут. Сравнивать при одинаковом разрешении, состоянии аккумулятора и сопоставимом нагреве. Не скрывать перегрев или сбои.
4. Сохранять исходные игровые JSON без переписывания чисел. Для R40 проверять метку сборки. Не подменять реальные данные Chromium/SwiftShader.
5. Сделать исходные снимки обеих версий в обеих ориентациях. Проверить, что нет исчезнувших светильников, неправильной геометрии, артефактов света и дефектов управления.
6. Ответственный инженер должен сохранить замечания и осмотреть результаты лично. Не собирать IMEI, точное местоположение и иные лишние персональные данные.

Минимум: 3 × 2 × 3 × 2 × 3 = **108 оригинальных JSON** и 3 × 2 × 2 = **12 настоящих снимков**.

## Блок 3 — проверка исходных доказательств без отправки файлов в интернет

Скопировать шаблон docs/nebula/R40-DEVICE-FIELD-MANIFEST.example.json в локальный защищённый каталог рядом с оригинальными файлами. Заполнить пути и заметки лишь после настоящего теста; поле field_work должно оставаться false до его окончания.

Запуск из корня репозитория:

    node scripts/nebula-r40-device-progress.mjs /private/NEBULA_QA/manifest.json
    node scripts/nebula-r40-field-release-gate.mjs /private/NEBULA_QA/manifest.json
    node scripts/nebula-r40-production-preflight.mjs /private/NEBULA_QA/manifest.json

Прогресс показывает отсутствующие файлы. Полный field gate требует уникальные JSON и изображения, исходную маркировку сборки, сопоставимые устройства/профили/разрешения, стабильные FPS, 1% Low, P95 и P99. Финальный preflight дополнительно вычисляет SHA-256-коммитмент содержимого всех источников без публикации самих файлов. Это удобная привязка к проверенному комплекту, **не цифровая подпись происхождения телефонов**.

Оба инструмента отказываются утверждать выпуск, если полевая матрица не прошла проверку. Даже при структурном PASS preflight возвращает статус HUMAN_RELEASE_APPROVAL_REQUIRED, а не разрешение на production.

## Блок 4 — обязательное независимое решение

Инженер отдельно подтверждает наличие физических устройств, подлинность исходных снимков, отсутствие визуальной/физической регрессии и сопоставимые условия теста. Итог фиксируется с точными source SHA и SHA-256-коммитментом приватных доказательств. Автоматические тесты не могут сами заменить этот человеческий допуск.

## Блок 5 — выпуск production с откатом

Только после выполненного блока 4:

1. В отдельном проверяемом релизном PR изменить production-allowlist на конкретные проверенные R40-байты, со ссылкой на закрытый протокол приёмки и человеческое заключение.
2. Повторить все проверки на актуальном master и сверить SHA-256 и Git-хеши WASM/PCK/JS/HTML; проверить резервные копии и свободное место.
3. Активировать новый релиз только через установленный SSH/Nginx workflow с механизмом отката.
4. Проверить HTTPS, настоящий запуск WebAssembly, пользовательские действия, лабораторию FPS и соседние игры. Провести короткий повтор на настоящих телефонах.
5. При регрессии немедленно откатиться к последней подтверждённой R38. Зафиксировать версию, журнал CI, серверный запуск, итог и ответственного.

На 25 октября 2026 года нет доступных подтверждений выполнения матрицы на реальных Android/iPhone. Значит, нельзя обещать аппаратные 60 FPS, финальный AAA-фотореализм или считать R40 production опубликованной.


## Private on-device QA starter kit (2026-10-25)

Generate a fresh private work directory OUTSIDE the Git repository:

    node scripts/nebula-r40-field-kit.mjs init /private/NEBULA_R40_DEVICE_QA

The kit creates `manifest.json`, an explicit 42-item collection checklist, private field notes, and empty `reports/` and `images/` directories. It does **not** generate measurements or photographs and refuses to overwrite an existing populated directory. Keep the directory private and do not upload it to the public repository.

    node scripts/nebula-r40-device-progress.mjs /private/NEBULA_R40_DEVICE_QA/manifest.json

The conservative inventory always expects at least **108 source JSONs and 12 source images**, even if a manifest row was accidentally removed. It detects duplicate file contents and never grants a production release. The strict field gate, independent physical-device reviewer and separately approved R40 promotion PR remain mandatory.
