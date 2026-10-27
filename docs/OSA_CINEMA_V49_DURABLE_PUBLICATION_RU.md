# OSA CINEMA V49 — постоянное хранилище и протокол премьеры

**27 октября 2026.** Основа: V48.1, PR #565, master merge `14b47857a907e25be220e9a34da28ede5b8e6aef`.

## Реализовано

- Будущий URL: `https://osgard.world/osa-cinema/premiere/`.
- Четыре MP4 и четыре WebVTT находятся **вне GitHub и вне постоянно заменяемого /usr/share/nginx/html**.
- В `docker-compose.production.yml` добавлен bind mount `${OSA_CINEMA_MEDIA_ROOT:-/srv/osgard-cinema-media}:/var/lib/osgard-cinema-media:ro`. Для активации уже запущенного контейнера требуется контролируемое пересоздание (обычный restart новый volume не подключает).
- `nginx.conf` обрабатывает URL, MIME `video/mp4` и `text/vtt`, Range 206/416; отсутствующие видео возвращают 404, а не React SPA HTML.
- `scripts/osa-cinema-v49-publisher.py`: проверка SHA-256 относительно восьми pins в GitHub, защита от подмены и symlink, immutable staging, явная активация и атомарный rollback.
- `scripts/osa-cinema-v49-public-verify.py`: полный HTTPS-аудит всех 185 899 405 байт медиа, GET 200 / Range 206 / 416 и MIME.
- `scripts/osa-cinema-v49-finalize.py`: runtime-маркер создаётся только после НАСТОЯЩИХ HTTP и браузерных протоколов и явного издательского решения. Автоматические субтитры не выдаются за дословно проверенные.
- `src/OSACinemaPremiereLink.tsx`: ссылка появляется лишь при действительном маркере `release.json` и успешной HEAD-проверке реального 87 МБ MP4. Восемь интерактивных сцен не тронуты.

- V49.1 усиливает защиту от подмены HTML: независимые неизменяемые SHA-256 для `index.html`, `manifest.json`, `assets/osa-premiere-poster.jpg` закреплены непосредственно в издательском скрипте. Изменение HTML вместе с `SHA256SUMS.txt` теперь блокируется отдельным тестом.

## Реальные локальные проверки

- 16/16 Python-тестов: PASS; включая отказ при подмене SHA, неверном источнике HTTPS, фиктивном браузерном PASS, symlink и duplicate release.
- Настоящий Nginx на локальной машине: /premiere/ → 200 HTML; MP4 → 200 video/mp4, VTT → 200 text/vtt, Range → 206, неправильный Range → 416, отсутствующий файл → 404.
- Полный локальный потоковый прогон: все 4 MP4 + 4 VTT, 185 899 405 байт, SHA-256 полностью совпали.
- **Это LOCAL PASS, а не подтверждение интернет-премьеры**.

## Блок A — один раз подготовить VPS

Распаковать существующий архив `OSA_CINEMA_V48_1_BEYOND_THE_MODEL_PREMIERE_CANDIDATE_20261027.zip` в закрытый staging-каталог на VPS. Не загружать MP4 в Git, в public/ или во временный контейнер. Внутри нужны `index.html`, `assets/`, `manifest.json`, `SHA256SUMS.txt`, `captions/`, `masters/`.

Из корня актуального репозитория выполнить:

```bash
sudo mkdir -p /srv/osgard-cinema-media
sudo chmod 755 /srv/osgard-cinema-media
python3 scripts/osa-cinema-v49-publisher.py verify \
  --source /path/to/unpacked/V48_1 \
  --pin docs/OSA_CINEMA_V48_LOCAL_MEDIA_CANDIDATE_20261027.json
python3 scripts/osa-cinema-v49-publisher.py stage \
  --source /path/to/unpacked/V48_1 \
  --pin docs/OSA_CINEMA_V48_LOCAL_MEDIA_CANDIDATE_20261027.json \
  --root /srv/osgard-cinema-media \
  --release-id osa-v49-cinema-20261027
```

Ожидается `STAGED_NOT_PUBLIC`: содержимое под `/srv/osgard-cinema-media/releases/` ещё НЕ публично.

## Блок B — подключить неизменяемый медиа-mount

Инфраструктурный инженер должен безопасно применить новый `volumes` к уже существующему контейнеру. Не делать слепой `docker compose up --force-recreate` без защиты текущего образа и других приложений. Проверка:

```bash
docker inspect osgard-world --format '{{range .Mounts}}{{println .Destination .Source .RW}}{{end}}'
docker exec osgard-world nginx -t
```

Нужен путь `/var/lib/osgard-cinema-media` в действительном контейнере с `RW=false`, а Nginx должен использовать новую конфигурацию. Frontend activation продолжает заменять только `/usr/share/nginx/html`.

## Блок C — активировать и проверить HTTPS

После реальной проверки mount:

```bash
python3 scripts/osa-cinema-v49-publisher.py activate \
  --pin docs/OSA_CINEMA_V48_LOCAL_MEDIA_CANDIDATE_20261027.json \
  --root /srv/osgard-cinema-media \
  --release-id osa-v49-cinema-20261027

python3 scripts/osa-cinema-v49-public-verify.py \
  --report /path/to/private/production-http.json
```

Если публичная проверка не прошла — немедленно откатить:

```bash
python3 scripts/osa-cinema-v49-publisher.py rollback \
  --root /srv/osgard-cinema-media
```

## Блок D — настоящая браузерная приёмка и публикационный маркер

После HTTP PASS вручную запустить GitHub Actions workflow `osa-cinema-v49-live-acceptance.yml` на **master**. Он проверяет действительное Chrome/Chromium воспроизведение на ПК и 390px, RU/EN, seek, VTT и трейлер. Из успешного CI забрать `production-browser.json`, из HTTP QA — `production-http.json`, хранить оба вне публичного репозитория.

После изучения доказательств издатель подтверждает конкретную публикацию:

```bash
python3 scripts/osa-cinema-v49-finalize.py \
  --root /srv/osgard-cinema-media \
  --release-id osa-v49-cinema-20261027 \
  --pin docs/OSA_CINEMA_V48_LOCAL_MEDIA_CANDIDATE_20261027.json \
  --http-report /path/to/private/production-http.json \
  --browser-report /path/to/private/production-browser.json \
  --publisher-acknowledgment I_APPROVE_THE_PUBLIC_OSA_FILM
```

Только тогда появится `release.json` с документированным runtime-статусом и главная страница сможет показать ссылку на фильм.

## Неисправляемые текстом ограничения

- Пользователь сообщил, что владеет фильмом и создал все материалы; это заявление владельца, а не независимая юридическая экспертиза.
- WebVTT — автоматические редакторские субтитры, **не дословно подтверждённые**; плеер честно сообщает об этом.
- Никаких оплат, checkout, скрытой публикации чужих материалов или передачи ключей. Историческая V20-политика остаётся прежней.
- В текущем агентском окружении нет SSH-доступа к VPS или возможности передать большой бинарный архив через Github connector. GitHub merge **не заменяет** реальную доставку четырёх MP4 и новый Docker mount.
