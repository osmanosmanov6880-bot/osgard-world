# OSGARD R135 W25 — проверяемые физические устройства, без фиктивных FPS

**Статус:** инструменты сбора и проверки доказательств. Никакие реальные
Android/iPhone ещё не измерены этим PR. «Честная физическая приёмка» означает
протокол на устройстве с оригинальными файлами, а не успешный CI SwiftShader.

## Зачем это важно
Ранее `r135-device-evidence.mjs` имел значения W11 по умолчанию. Они
стали устаревшими после W19/W20 и будут неверны для W21+. Новый безопасный
запуск `r135-w25-physical-capture.mjs` подставляет `source_commit`,
`manifest_sha256` и `version` **из текущего source-controlled
`r135-active-release.json` и точного reviewed pin**.

## Android Chrome: локальный USB-отладчик

Только на собственном или явно разрешённом телефоне:
1. Разрешить USB debugging, открыть опубликованную игру в Chrome,
   выполнить `adb devices` и подтвердить подключение.
2. Выполнить `adb forward tcp:9222 localabstract:chrome_devtools_remote`.
   **Никогда** не открывать CDP-порт в Интернет.
3. В репозитории запустить:

```bash
node scripts/r135-w25-physical-capture.mjs \
  --platform android-chrome \
  --orientation portrait \
  --mode ECO \
  --cdp http://127.0.0.1:9222 \
  --seconds 60 \
  --out my-android-portrait-eco.json \
  --physical-device-attested
```

4. Сохранить созданные реальный PNG и JSON локально. Повторить при HERO
   и landscape, на двух независимых физических сессиях для каждого
   сочетания. Вручную проверить касания, читаемость люка, камеру и
   блокировку небезопасного действия.
5. Завершить командой `adb forward --remove tcp:9222`.

## iPhone Safari

Android CDP не подходит для iOS. iPhone требует реального Safari Web
Inspector, независимой локальной записи и отдельно проверенного
происхождения устройства. Новая команда преднамеренно **отказывается**
собирать iPhone Safari через эмуляцию Android/Chromium.

## Когда станет допустим выпуск
Нужны минимум **16 подлинных сессий** (Android/iPhone × portrait/landscape
× ECO/HERO × 2), оригинальные проверенные PNG, измерения браузера и
подтверждение независимого испытателя. `node scripts/r135-hardware-matrix.mjs
<reviewed-pin> <original-sessions.json>` только проверяет структуру и
согласованность доказательств. User-Agent, ручная отметка «физическое
устройство», rAF callback pacing и sampled FPS **не доказывают GPU frame
time, термальную стабильность или энергопотребление**.

**Сейчас статус W25 = HOLD_DEVICE_EVIDENCE_MISSING.** Любая попытка
объявить его физически сертифицированным без устройств будет отклонена.
