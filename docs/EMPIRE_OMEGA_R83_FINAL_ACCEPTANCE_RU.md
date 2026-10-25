# EMPIRE Ω R83 — итоговая независимая приёмка после настоящей публикации

**Дата:** 25 октября 2026. **Продукт:** опубликованная 3D Web-игра Godot 4.4.1.

## 1. Что действительно выполнено

- Реальные изменения игры R76/R79/R81 объединены в [PR #459](https://github.com/osmanosmanov6880-bot/osgard-world/pull/459): **53 успешные проверки**, одна пропущенная по условиям CI и ни одной ошибки.
- Оригинальный Web-экспорт Godot с source_commit **d192aaab54273580324a5736622c19bb8b53ce54** — [build #40221149499](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40221149499), SUCCESS.
- Серверная активация оригинальной игры и публичные **7/7 SHA-256** — [SSH #40221556739](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40221556739), SUCCESS.
- Первый post-SSH браузерный R50 **провалился** на desktop Chromium — [#40221654150](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40221654150). Это не замалчивается; тестовая нестабильность исправлена в отдельном R82.
- Новый независимый R50 — [#40222384305](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40222384305): настоящие desktop/touch Chromium PASS, семь публичных файлов SHA PASS, архив оригиналов [#12610261399](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40222384305/artifacts/12610261399). Отдельный R11 desktop/touch PASS — [#40222384287](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40222384287).
- R55 программно проверил 40 миссий и сохранения. **Это не доказательство, что сорок миссий прошёл человек.**

**Текущий подтверждённый продуктовый статус — PLAYABLE WEB TECH PREVIEW, НЕ «AAA RELEASE».**

## 2. Шесть ворот финальной приёмки

| Ворота | Машинное доказательство | Человеческая проверка |
| --- | --- | --- |
| 1. Истинная Web-сборка | R50: семь исходных бинарников, 7/7 HTTP SHA, desktop/touch Godot, ноль flaky | Проверить, что кадр относится к настоящей игре |
| 2. Кампания | R73/R75: 40 миссий, 43 декодируемых PNG, видео, сохранения 6/20/40 | Просмотреть непрерывное прохождение и игровые результаты |
| 3. Android | R80: оригинальный 20-секундный Godot JSON + SHA и видео | Свидетель реального телефона, ОС и версии игры |
| 4. iPhone | R80: отдельный Godot JSON + SHA и видео | Проверить настоящий iPhone, а не эмуляцию |
| 5. Игроки | 20 уникальных сессий с согласиями, отзывами и разными записями | Проверить реальных участников и понятность игры |
| 6. Арт и лицензии | PNG четырёх оригинальных viewport + перечень лицензий | Оценить модели, свет, материалы, интерфейс и права |

Невыполненные пункты нельзя закрыть синтетическими данными CI, скриншотом заставки Godot или красивым макетом.

## 3. Исходные данные

**Web:** скачайте настоящий архив R50 [#12610261399](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40222384305/artifacts/12610261399). Нужны файлы omega-r50-evidence/live-integrity.json и omega-r50-evidence/playwright.json вместе с семью файлами оригинальной опубликованной игры.

**Кампания:** следуйте docs/EMPIRE_OMEGA_R73_FIELD_ACCEPTANCE.md. Снимите один непрерывный проход, реальные победы и отдельное восстановление сохранений после 6, 20 и 40 миссий.

**Телефоны:** следуйте docs/EMPIRE_OMEGA_R80_PHONE_FPS_EVIDENCE_RU.md. В самой игре откройте диагностику, нажмите «ЗАМЕР 20 С», затем «СКАЧАТЬ JSON». Приложите оригинальную запись устройства. Android и iPhone проверяются раздельно. Черновик R80 намеренно содержит physical_device=false до проверки реальным тестировщиком.

**20 пользователей:** JSON с schema="empire-omega-r83-20-sessions-v1", source_commit и ровно 20 объектами в sessions. Для каждого: уникальные session_id и participant_code, observer, recording_consent=true, actually_played=true, captured_utc UTC, duration_s, outcome (completed/failed/abandoned), feedback, recording_file, recording_sha256. Двадцать разных оригинальных WebM/MP4 должны находиться рядом с JSON. **Не загружайте приватное видео пользователей в общедоступный GitHub.** Используйте закрытый QA-каталог.

**Арт и лицензии:** JSON с schema="empire-omega-r83-original-art-v1", source_commit, reviewer, real_godot_frames_reviewed=true, assets (asset_id, origin, licence, review_notes) и screenshots (viewport, file, sha256). Обязательные viewport: 1366x768, 390x844, 320x568, 844x390. Для desktop допускаются настоящие уменьшенные CDP-пиксели в пределах оригинального соотношения сторон. Это не автоматическая оценка AAA.

## 4. Единый контроль локально в закрытом QA-каталоге

~~~bash
python3 scripts/omega_r83_release_gate.py \
  --r50-live /private/r50/omega-r50-evidence/live-integrity.json \
  --r50-browser /private/r50/omega-r50-evidence/playwright.json \
  --campaign /private/campaign/campaign-session.json \
  --campaign-dir /private/campaign \
  --android /private/android/android.json \
  --ios /private/ios/ios.json \
  --sessions /private/sessions/twenty-sessions.json \
  --art /private/art/art-review.json \
  --output /private/review/final-evidence.json
~~~

Без аргументов программа создаёт **HOLD** с перечнем отсутствующих доказательств и точным source_commit. Флаг --require-all-field-evidence даёт ненулевой код при неполном комплекте.

Даже если все материалы проходят форматные проверки, результат — **READY_FOR_INDEPENDENT_HUMAN_SIGNOFF**, production_go=false. Он не подтверждает реальное участие людей, личность телефона, целостность видеосюжета, полноту лицензий или AAA-качество.

## 5. Что осталось

**Техническая Web-публикация R81 завершена.** Остались реальные Android/iPhone, человеческое прохождение 40 миссий, 20 сессий пользователей, аудит художественного качества и лицензий. После их независимой проверки ответственный человек решает вопрос о полноценном коммерческом релизе. R83 не запускает SSH и никогда не выдаёт GO автоматически.
