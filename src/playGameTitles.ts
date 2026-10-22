/** Lightweight breadcrumb labels. Full game mechanics are loaded only on Play routes.
 * scripts/brand-route-schema-smoke.mjs checks all 19 titles against redesignCatalog.ts. */
export const playGameTitles: Readonly<Record<string, string>> = {
  "null-shift": "NULL//SHIFT",
  "time": "Империя времени",
  "empire-orbit": "Империя времени: Орбита",
  "swarm": "SWARM",
  "inherit": "INHERIT",
  "remix": "REMIX",
  "vector-zero": "VECTOR//ZERO",
  "afterimage-run": "AFTERIMAGE//RUN",
  "zion-020": "Базальтовая колыбель",
  "zion-021": "Тихий архив",
  "zion-022": "Стеклянный сад",
  "zion-023": "Последний приливный механизм",
  "zion-024": "Бархатная частота",
  "zion-025": "Бледное уравнение",
  "zion-026": "Север сна",
  "zion-027": "Бронзовый час",
  "zion-028": "Зеркальная погода",
  "zion-029": "Синий интервал",
  "zion-030": "Теневой протокол",
}
export const getPlayGameTitle = (id: string): string | undefined =>
  Object.hasOwn(playGameTitles, id) ? playGameTitles[id] : undefined
