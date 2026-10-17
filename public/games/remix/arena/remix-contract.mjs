export const RULESET = 'remix-arena-v1';
export const CORE_TOKEN = 'osgard:core-session:v1';

export function dailyChallenge(date = new Date()) {
  const day = date.toISOString().slice(0, 10);
  return { day, seed: Number(day.replaceAll('-', '')) };
}

export function challengeURL(base, challengeId, seed, referral) {
  if (typeof challengeId !== 'string' || !challengeId || challengeId.length > 128 || !Number.isSafeInteger(seed) || seed < 1) throw Error('Испытание ещё не подтверждено сервером.');
  const url = new URL(base);
  url.search = '';
  url.hash = '';
  for (const [key, value] of Object.entries({ challenge: challengeId, seed, ref: referral || '', utm_source: 'osgard_remix', utm_medium: 'friend_challenge', utm_campaign: 'daily_challenge', utm_content: challengeId })) url.searchParams.set(key, String(value));
  return url.href;
}

export function compatibleService(value) {
  return value?.schemaVersion === 1 && value.service === 'osgard-remix-arena' && value.ruleset === RULESET && value.auth === 'osgard-core-bearer-v1' && value.playersPerMatch === 1 && value.resultAuthority === 'server-input-journal';
}

export function summarizeResult(value) {
  if (value?.schemaVersion !== 1 || value.ruleset !== RULESET || typeof value.won !== 'boolean' || !Number.isSafeInteger(value.score) || value.score < 0 || !value.won && value.score !== 0 || !Number.isSafeInteger(value.steps) || value.steps < 1 || value.steps > 256 || !Number.isSafeInteger(value.timeMs) || value.timeMs < 100 || !/^[a-f0-9]{64}$/.test(value.replayHash || '')) throw Error('Сервис вернул неподдерживаемый результат.');
  return value.won ? `Цель достигнута · ${value.steps} ходов · ${value.score} очков` : `Лимит ходов · ${value.steps} ходов · 0 очков`;
}

export function resultCardLines(summary, challengeId, seed, won = true) {
  if (!summary || !challengeId || !Number.isSafeInteger(seed)) throw Error('Сначала получите результат заезда.');
  return ['OSGARD WORLD / REMIX', won ? 'ИСПЫТАНИЕ ПРОЙДЕНО' : 'ЛИМИТ ХОДОВ', `SEED ${seed}`, summary, `CHALLENGE ${challengeId.slice(0, 24)}`, 'Повтори маршрут. Найди более короткий путь.'];
}
