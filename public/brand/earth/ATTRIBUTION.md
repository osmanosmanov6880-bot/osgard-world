# OSGARD WORLD — данные изображения Земли

Глобус использует **исторические спутниковые композиты NASA**, а не карту
поверхности или метеоданные в режиме реального времени.

## Первичные источники

- **NASA Blue Marble: Next Generation, July 2004**, глобальная карта 5400×2700:
  https://science.nasa.gov/earth/earth-observatory/blue-marble-next-generation/base-map/
  Исходник: https://assets.science.nasa.gov/content/dam/science/esd/eo/images/bmng/bmng-base/july/world.200407.3x5400x2700.jpg
- **NASA Black Marble, 2016**, глобальные ночные огни 3600×1800:
  https://science.nasa.gov/earth/earth-observatory/earth-at-night/maps/
  Исходник: https://assets.science.nasa.gov/content/dam/science/esd/eo/images/imagerecords/144000/144898/BlackMarble_2016_01deg.jpg
- **Natural Earth 1:110m coastlines** — public domain, для маски отражения океана и резервной процедурной карты.

**Атрибуция:** NASA Earth Observatory, Reto Stöckli, Robert Simmon; NASA MODIS и VIIRS teams. Изображения на сайте используются по общим правилам использования медиа NASA. NASA не спонсирует и не одобряет OSGARD; логотип и фирменная символика NASA не используются.

Файлы `blue-marble-{512,1024,2048,4096}.webp`,
`black-marble-lights-2048.webp` и `earth-roughness-2048.webp`
получены из исходников скриптом `scripts/prepare_nasa_earth.py`.
Исходные и результирующие SHA-256, размеры и суммарный вес сохранены в
`manifest.json`. В сборке нет внешних runtime-запросов к NASA.

## Важные ограничения

- Время поверхности: июль 2004. Ночные огни: композит 2016 года.
- Слой облаков искусственно сгенерирован; **это не прогноз погоды**.
- Атмосферное рассеивание приближённое, в реальном времени.
- Режим Ultra использует текстуру 4096×2048, но это не офлайн 4K-видеоролик
  и не физически точная AAA-сцена.
- При недоступности изображений сохраняется резервная карта Natural Earth,
  а при отсутствии WebGL2 — лёгкая CSS-сфера.
