# OSGARD R135 W22 — независимый контроль 19 оригинальных кадров

Этот контур необходим для проверки **выбираемых игроком** трёх
учебных сценариев и записей мастерства. Он не создаёт новых данных
об оборудовании, не обходит безопасный цикл диагностики и не меняет
действующий публичный release channel.

## Что должно быть подтверждено
1. На одной исходной SHA завершились **SUCCESS** нативная игровая QA
   `r135-w22-selectable-case-native-qa.yml` и настоящая desktop/Pixel WebGL
   QA `r135-web-optimized.yml`.
2. Игрок действительно выбирает охлаждение из трёх кейсов, через доступную
   scroll/touch/click кнопку, и получает исходный пятиэтапный симулированный
   цикл; во время активного сценария повторный выбор заблокирован.
3. 19 неизменённых исходных PNG со строгой CRC + SHA256:
   13 W19 + 2 W20 настройки + 2 W21 причины + 2 W22 replay/mastery.
4. ZIP WebGL, manifest и W10 browser evidence совпадают с SHA commit,
   Nginx правильно выдаёт precompressed WASM/PCK. Три симулированных кейса
   исходной игровой матрицы пройдены в обоих браузерных профилях.
5. Объявления о физическом GPU / AAA являются **ложными**, если основаны
   только на программном Chromium.

## Создание неутверждённого pin
```bash
python3 scripts/r135-w22-candidate-pin-draft.py \
  --artifact /path/to/original-extracted-actions-artifact \
  --source EXACT_40_CHAR_SOURCE_SHA \
  --run-id ACTUAL_SUCCESS_WEBGL_RUN_ID \
  --artifact-id ACTUAL_ARTIFACT_ID \
  --native-run-id ACTUAL_SUCCESS_NATIVE_RUN_ID \
  --output /tmp/r135-w22-pin-UNREVIEWED.json
```
Все флаги visual/manual approval по умолчанию `false`.
Только после просмотра настоящих кадров независимая ветка
`release/r135-w22-reviewed-artifact-20261025` может содержать
`scripts/r135-w22-release-pin.json` с подписанными проверенными
свойствами и запустить полный release gate.

Действующий W19/W20 production и старые W14/W18 backup не меняются
по факту слияния W22 gate. Для внешнего релиза понадобится **отдельная**
защищённая активация и live HTTPS-проверка после SSH.
