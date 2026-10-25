# OSGARD R135 W20 — независимая проверка обновления настроек

**Действующий релиз: W19.** W20 — отдельный кандидат Godot 4.4.1. Этот
документ не утверждает, что W20 опубликован или протестирован на физических
Android/iPhone.

## Что проверяется
- Тот же неизменяемый исходный коммит у **двух** успешных workflows:
  `r135-w20-preferences-native-qa.yml` и `r135-web-optimized.yml`.
- 15 оригинальных PNG, включая два кадра `w20-*-player-settings.png`
  с настоящего ПК и мобильного Chromium, а также все 13 кадров W19.
- Точные SHA-256 ZIP, JSON-манифеста и каждого PNG, CRC всех PNG, корректные
  размеры, отсутствие дубликатов. Три реальные (симулированные) неисправности
  в двух браузерных профилях.
- Работа настоящих Godot Control-сигналов настройки, переключение обеих
  сохранённых моделей HERO/ECO, reduced motion, локальный файл настроек,
  восстановление после перезапуска без порчи W14/W19 учебных сохранений.
- Безопасная распаковка полного Godot ZIP и WebAssembly/PCK через Nginx.
- Портретные реальные CSS-targets, отсутствие перекрытий, читаемые тексты.

## Как запустить проверку после зелёных двух исходных workflows

1. Скачать **точный** named Actions-артефакт
   `osgard-r135-optimized-web-qa` успешного W20 WebGL run.
2. Получить реальные `run_id`, `artifact_id`, `native_run_id`, 40-символьный
   source SHA; не выбирать «latest».
3. Запустить генератор чернового pin (флаги одобрения останутся FALSE):

```bash
python3 scripts/r135-w20-candidate-pin-draft.py \
  --artifact /path/to/extracted-actual-webgl-artifact \
  --source EXACT_40_CHAR_SHA \
  --run-id ACTUAL_WEBGL_SUCCESS_RUN_ID \
  --artifact-id ACTUAL_WEBGL_ARTIFACT_ID \
  --native-run-id ACTUAL_NATIVE_SUCCESS_RUN_ID \
  --output /tmp/r135-w20-UNREVIEWED-pin.json
```

4. Визуально осмотреть **оригинальные** скриншоты, а не генерации. Сверить
   подписи RU/EN, читаемость настроек, панели управления и отсутствие
   перекрытий.
5. Зафиксировать подтверждённые поля и полный pin в
   `scripts/r135-w20-release-pin.json` на отдельной ветке
   `release/r135-w20-reviewed-artifact-20261025`.
6. Дождаться успеха полного независимого gate, а затем выпуска неизменяемого
   **непубличного** GitHub Release
   `r135-player-settings-w20-reviewed-webgl-20261025`.

## Жёсткий запрет самопубликации

Объединение W20 source PR или этого gate PR **не** меняет действующий
`scripts/r135-active-release.json` (пока W19), SSH-ключи, VPS-состояние,
предыдущие бэкапы и целевые адреса сайта. Переход W20 на production — отдельное
решение и отдельная проверка точного pin и live HTTPS-байтов.

**Не сертифицированы:** физический FPS/нагрев/память Android и iPhone,
AAA-фотореализм, HDR/8K. Ни один программный тест SwiftShader этого не доказывает.
