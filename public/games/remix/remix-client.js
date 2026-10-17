import { CORE_TOKEN, RULESET, challengeURL, compatibleService, dailyChallenge, resultCardLines, summarizeResult } from './remix-contract.mjs';

const $ = selector => document.querySelector(selector);
const arena = $('#arena');
const ctx = arena.getContext('2d');
const SESSION = 'osgard:remix-client:v1';
const PENDING = 'osgard:remix-pending:v1';
const directions = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] };
const keyDirections = { ArrowUp: 'up', w: 'up', W: 'up', ArrowDown: 'down', s: 'down', S: 'down', ArrowLeft: 'left', a: 'left', A: 'left', ArrowRight: 'right', d: 'right', D: 'right' };
const day = dailyChallenge();
const incoming = new URL(location.href).searchParams.get('challenge');
let token = '', actor = null, service = null, challenge = null, state = null, result = null, replay = null;
let pending = null, busy = 0, loadingResult = false, lastDirection = 'right', incomingConsumed = false;
let restoring = false, restoreNeeded = false, polling = false;

function readStorage(key) { try { return sessionStorage.getItem(key) || ''; } catch { return ''; } }
function writeStorage(key, value) { try { if (value === null) sessionStorage.removeItem(key); else sessionStorage.setItem(key, value); } catch {} }
function savedObject(key) { try { const raw = readStorage(key); return raw.length <= 65536 ? JSON.parse(raw || 'null') : null; } catch { return null; } }
function remember() {
  // Restore is atomic with respect to the saved challenge/match reference.
  // A loaded challenge followed by a failed state read cannot erase matchId.
  if (actor && !restoring) writeStorage(SESSION, JSON.stringify({ actorId: actor.id, challengeId: challenge?.id || null, matchId: state?.id || null }));
}
function setStatus(message) { $('#match-status').textContent = message; }
function id(value) { return typeof value === 'string' && /^[a-f0-9]{32}$/.test(value); }

class RequestError extends Error {
  constructor(message, status = 0, code = 'network') { super(message); this.status = status; this.code = code; }
}

async function request(path, { body, key, anonymous = false, core = false } = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15000);
  try {
    const headers = { Accept: 'application/json' };
    if (!anonymous && token) headers.Authorization = 'Bearer ' + token;
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    if (key) headers['Idempotency-Key'] = key;
    const response = await fetch((core ? '/api/core/' : '/api/remix/v1/') + path, { method: body === undefined ? 'GET' : 'POST', credentials: 'omit', headers, body: body === undefined ? undefined : JSON.stringify(body), signal: controller.signal });
    if (!response.headers.get('content-type')?.includes('application/json')) throw new RequestError('Сервис вернул страницу вместо ответа API.', response.status, 'unsupported_response');
    const data = await response.json();
    if (!response.ok) {
      const message = typeof data.error?.message === 'string' ? data.error.message : typeof data.message === 'string' ? data.message : 'Запрос отклонён сервером.';
      throw new RequestError(message.slice(0, 300), response.status, data.error?.code || data.error || 'request_failed');
    }
    return data;
  } catch (error) {
    if (error instanceof RequestError) throw error;
    throw new RequestError('Нет подтверждения от сервера. Проверьте соединение и повторите действие.');
  } finally { clearTimeout(timer); }
}

function syncControls() {
  const restoringRun = restoring || restoreNeeded;
  const playing = Boolean(service && actor && state?.phase === 'PLAYING' && !busy && !pending && !replay && !restoringRun);
  document.querySelectorAll('[data-remix-move],[data-remix-jump]').forEach(button => { button.disabled = !playing; });
  $('#start-match').disabled = !service || !actor || Boolean(busy || pending || restoringRun || state?.phase === 'PLAYING');
  $('#start-match').textContent = state?.phase === 'PLAYING' ? 'Заезд идёт' : challenge ? 'Начать заезд' : 'Создать испытание';
  $('#new-challenge').disabled = Boolean(busy || pending || restoringRun || state?.phase === 'PLAYING');
  $('#challenge-name').disabled = Boolean(challenge || busy || pending || restoringRun);
  $('#challenge-seed').disabled = Boolean(challenge || busy || pending || restoringRun);
  for (const selector of ['#rematch-challenge', '#publish-challenge', '#remix-challenge', '#show-replay']) $(selector).disabled = Boolean(busy || pending || restoringRun);
  $('#retry-operation').hidden = !pending;
  $('#retry-operation').disabled = Boolean(busy || restoringRun || !actor || !service);
  $('#retry-restore').hidden = !restoreNeeded;
  $('#retry-restore').disabled = Boolean(busy || restoring || !actor || !service);
  $('#auth-form').querySelectorAll('button').forEach(button => { button.disabled = Boolean(busy || !service); });
}

function draw(level = state?.arena, position = state?.position) {
  ctx.clearRect(0, 0, arena.width, arena.height);
  const width = level?.width || 12, height = level?.height || 7;
  const cellX = arena.width / width, cellY = arena.height / height;
  ctx.strokeStyle = '#d1e2cf18'; ctx.lineWidth = 1;
  for (let x = 0; x <= width; x++) { ctx.beginPath(); ctx.moveTo(x * cellX, 0); ctx.lineTo(x * cellX, arena.height); ctx.stroke(); }
  for (let y = 0; y <= height; y++) { ctx.beginPath(); ctx.moveTo(0, y * cellY); ctx.lineTo(arena.width, y * cellY); ctx.stroke(); }
  if (!level) {
    ctx.fillStyle = '#b2c3b5'; ctx.font = '18px system-ui'; ctx.textAlign = 'center'; ctx.fillText('Поле появится после запуска заезда', arena.width / 2, arena.height / 2); return;
  }
  for (const object of level.objects) {
    const x = object.x * cellX, y = object.y * cellY;
    ctx.fillStyle = { platform: '#52695d', hazard: '#ee8c7f', goal: '#8be0b1' }[object.kind];
    if (object.kind === 'platform') ctx.fillRect(x + 4, y + 4, cellX - 8, cellY - 8);
    else if (object.kind === 'hazard') { ctx.beginPath(); ctx.moveTo(x + cellX / 2, y + 8); ctx.lineTo(x + cellX - 6, y + cellY - 7); ctx.lineTo(x + 6, y + cellY - 7); ctx.closePath(); ctx.fill(); }
    else { ctx.beginPath(); ctx.arc(x + cellX / 2, y + cellY / 2, cellX * .3, 0, 2 * Math.PI); ctx.fill(); ctx.fillStyle = '#07110f'; ctx.font = 'bold 20px system-ui'; ctx.textAlign = 'center'; ctx.fillText('✓', x + cellX / 2, y + cellY / 2 + 7); }
  }
  if (position) { ctx.fillStyle = '#e7c778'; ctx.beginPath(); ctx.arc((position[0] + .5) * cellX, (position[1] + .5) * cellY, cellX * .21, 0, 2 * Math.PI); ctx.fill(); ctx.strokeStyle = '#fff6d2'; ctx.lineWidth = 2; ctx.stroke(); }
}

function validArena(level) {
  return level?.ruleset === RULESET && level.width === 12 && level.height === 7 && Array.isArray(level.objects) && level.objects.length <= 40 && level.objects.every(object => ['platform', 'hazard', 'goal'].includes(object.kind) && Number.isInteger(object.x) && object.x >= 0 && object.x < 12 && Number.isInteger(object.y) && object.y >= 0 && object.y < 7);
}

function setChallenge(value) {
  if (value?.schemaVersion !== 1 || value.ruleset !== RULESET || !id(value.id) || !id(value.creatorId) || !['DRAFT', 'VALIDATED', 'PUBLISHED'].includes(value.status) || !validArena(value.arena) || !Number.isSafeInteger(value.seed) || typeof value.title !== 'string') throw Error('Сервис вернул неподдерживаемое испытание.');
  challenge = value;
  $('#challenge-name').value = value.title;
  $('#challenge-seed').value = String(value.seed);
  $('#challenge-mode').textContent = value.parentId ? 'Ремикс опубликованного поля' : value.creatorId === actor?.id ? 'Твоё испытание' : 'Испытание другого игрока';
  $('#challenge-copy').textContent = value.status === 'PUBLISHED' ? 'Опубликовано. Каждый игрок получает тот же набор объектов и собственный заезд.' : 'Черновик. Достигни цели в проверочном заезде, затем подтверди публикацию.';
  updatePassport(); remember(); syncControls();
}

function resetResult() {
  result = replay = null;
  for (const selector of ['#result-panel', '#result-card-actions', '#sponsor-slot', '#replay-panel', '#growth-panel', '#publish-challenge', '#remix-challenge', '#rematch-challenge']) $(selector).hidden = true;
  $('#leaderboard').replaceChildren();
  delete $('#result-panel').dataset.result;
}

async function applyState(value) {
  if (value?.schemaVersion !== 1 || value.ruleset !== RULESET || !id(value.id) || value.playerId !== actor?.id || value.challengeId !== challenge?.id || !validArena(value.arena) || !['PLAYING', 'RESULTS'].includes(value.phase) || !Number.isInteger(value.sequence) || value.sequence < 0 || value.sequence > 256 || !Array.isArray(value.position) || value.position.length !== 2 || !value.position.every(Number.isInteger)) throw Error('Сервис вернул неподдерживаемое состояние заезда.');
  if (state?.id === value.id && state.sequence > value.sequence) return;
  const changedMatch = state?.id !== value.id;
  if (changedMatch) { resetResult(); lastDirection = 'right'; }
  state = value;
  // A read-only view of the last confirmed server response, also useful for support.
  arena.dataset.state = JSON.stringify(value);
  $('#match-title').textContent = (value.purpose === 'creator-proof' ? 'Проверочный заезд' : 'Заезд испытания') + ' · ' + value.id.slice(0, 8);
  $('#position-label').textContent = `Клетка ${value.position[0] + 1}, ${value.position[1] + 1} · ход ${value.sequence}/256 · падений ${value.falls} · ${value.timeMs} мс`;
  $('#match-meter i').style.width = (value.phase === 'RESULTS' ? 100 : value.sequence / 256 * 100) + '%';
  if (!replay) draw();
  remember(); syncControls();
  if (value.phase === 'RESULTS') await loadResult();
  else if (!pending) setStatus('Заезд активен. Выбирай направление; клетка меняется после ответа сервера.');
  if (changedMatch) { arena.focus({ preventScroll: true }); lifecycle('started'); }
}

function updatePassport() {
  const published = challenge?.status === 'PUBLISHED';
  $('#growth-panel').hidden = !published || !result;
  $('#remix-challenge').hidden = !published || !result;
  $('#publish-challenge').hidden = !result?.won || state?.purpose !== 'creator-proof' || challenge?.creatorId !== actor?.id || published;
  if (!published) return;
  $('#challenge-code').textContent = 'CHALLENGE / ' + challenge.id;
  $('#challenge-link').value = challengeURL(location.href, challenge.id, challenge.seed, actor.id.slice(0, 12));
  $('#growth-badge').textContent = 'Опубликованное испытание · seed ' + challenge.seed;
}

async function loadResult() {
  if (loadingResult || result?.matchId === state?.id) return;
  loadingResult = true;
  const matchId = state.id;
  try {
    const value = await request('matches/' + matchId + '/result');
    const summary = summarizeResult(value);
    if (state?.id !== matchId) return;
    if (value.matchId !== matchId || value.challengeId !== challenge.id || value.playerId !== actor.id || value.purpose !== state.purpose || value.steps !== state.sequence) throw Error('Результат не относится к этому заезду.');
    result = value;
    $('#result-panel').dataset.result = JSON.stringify(value);
    $('#result-summary').textContent = summary;
    $('#result-detail').textContent = `${value.timeMs} мс игрового времени · падений ${value.falls} · прыжков ${value.jumps} · повтор ${value.replayHash}`;
    for (const selector of ['#result-panel', '#result-card-actions', '#sponsor-slot', '#rematch-challenge']) $(selector).hidden = false;
    updatePassport();
    setStatus('RESULTS · ' + summary);
    lifecycle('completed');
    reportEvent('game_session_completed', { challengeId: challenge.id, seed: challenge.seed, score: value.score, ruleset: RULESET });
    await loadLeaderboard();
  } finally { loadingResult = false; syncControls(); }
}

async function loadLeaderboard() {
  if (challenge?.status !== 'PUBLISHED') return;
  const value = await request('challenges/' + challenge.id + '/leaderboard');
  if (value.ruleset !== RULESET || value.challengeId !== challenge.id || !Array.isArray(value.scores) || value.scores.length > 20) throw Error('Неподдерживаемая таблица результатов.');
  $('#leaderboard').replaceChildren(...value.scores.map(item => {
    const element = document.createElement('li');
    element.textContent = `${item.playerId === actor.id ? 'Ты' : 'Игрок ' + item.playerId.slice(0, 8)} · ${item.score} очков · ${item.timeMs} мс`;
    return element;
  }));
}

function validPending(value) {
  return value?.actorId === actor?.id && ['create', 'match', 'input', 'validate', 'publish', 'remix'].includes(value.kind) && typeof value.path === 'string' && /^(?:challenges|matches|matches\/[a-f0-9]{32}\/input|challenges\/[a-f0-9]{32}\/(?:validate|publish|remix))$/.test(value.path) && /^[A-Za-z0-9_-]{16,100}$/.test(value.key) && value.body && typeof value.body === 'object' && !Array.isArray(value.body);
}

async function operation(kind, path, body, reuse = null) {
  if (!actor || !service) throw Error('Сначала войдите в доступный сервис.');
  if (restoring || restoreNeeded) throw Error('Сначала восстановите сохранённый заезд.');
  if (pending && reuse !== pending) throw Error('Сначала повторите неподтверждённое действие.');
  const current = reuse || { actorId: actor.id, kind, path, body, key: crypto.randomUUID() };
  pending = current; writeStorage(PENDING, JSON.stringify(current)); syncControls();
  let value;
  try { value = await request(path, { body, key: current.key }); }
  catch (error) {
    // A lost response may follow a committed transaction. Preserve the exact key
    // and payload until the server acknowledges the same operation on retry.
    // Authentication may expire after an earlier attempt committed. A 401 only
    // rejects this retry; preserve its key until the same actor signs in again.
    if (error.status >= 400 && error.status < 500 && error.status !== 401) { pending = null; writeStorage(PENDING, null); }
    syncControls(); throw error;
  }
  pending = null; writeStorage(PENDING, null);
  if (kind === 'create' || kind === 'remix') {
    state = null; resetResult(); setChallenge(value);
    reportEvent('challenge_created', { challengeId: value.id, seed: value.seed, parentId: value.parentId });
    await operation('match', 'matches', { challengeId: value.id, maxPlayers: 1 });
  } else if (kind === 'match') await applyState(value);
  else if (kind === 'input') {
    if (!value.accepted || value.sequence !== body.sequence) throw Error('Сервер не подтвердил этот ход.');
    await applyState(value.state);
  } else if (kind === 'validate') {
    setChallenge(value); await operation('publish', 'challenges/' + value.id + '/publish', {});
  } else if (kind === 'publish') {
    setChallenge(value); await loadLeaderboard(); setStatus('Испытание опубликовано. Отправь ссылку другому игроку или пройди заезд для таблицы результатов.');
  }
  syncControls(); return value;
}

async function act(action) {
  if (busy) return;
  busy++; syncControls();
  try { await action(); }
  catch (error) {
    setStatus(error.message || 'Действие не подтверждено.');
    if (error.status === 401) expireSession();
    if (error.code === 'sequence_conflict' && state) { try { await refresh(); } catch {} }
  } finally { busy--; syncControls(); }
}

async function start() {
  if (restoring || restoreNeeded) throw Error('Сначала восстановите сохранённый заезд.');
  if (challenge) {
    resetResult();
    await operation('match', 'matches', { challengeId: challenge.id, maxPlayers: 1 });
    if (challenge.creatorId !== actor.id) reportEvent('challenge_invite_accepted', { challengeId: challenge.id, seed: challenge.seed });
    return;
  }
  const seed = Number($('#challenge-seed').value), title = $('#challenge-name').value.trim();
  if (!Number.isSafeInteger(seed) || seed < 1 || seed > 2147483647 || title.length < 2 || title.length > 100) throw Error('Введите название от 2 до 100 символов и целый seed от 1 до 2147483647.');
  await operation('create', 'challenges', { creatorId: actor.id, title, seed, mode: 'speed', visibility: 'public' });
}

async function move(direction, jump = false) {
  if (!state || state.phase !== 'PLAYING' || pending || busy || replay || restoring || restoreNeeded) return;
  lastDirection = direction;
  const [moveX, moveY] = directions[direction];
  await act(() => operation('input', 'matches/' + state.id + '/input', { sequence: state.sequence + 1, moveX, moveY, jump, playerId: actor.id }));
}

async function refresh() {
  if (!state || !actor || !service) return;
  const matchId = state.id, actorId = actor.id, sessionToken = token;
  const stillCurrent = () => state?.id === matchId && actor?.id === actorId && token === sessionToken && !restoring && !restoreNeeded;
  try {
    const value = await request('matches/' + matchId + '/state');
    // A read may finish after a move, rematch or reauthentication. applyState
    // already rejects older sequences; this guard also binds the response to
    // the currently displayed run and authenticated session.
    if (stillCurrent()) await applyState(value);
  } catch (error) {
    if (stillCurrent()) throw error;
  }
}

async function pollState() {
  if (!actor || !service || !state || busy || pending || replay || restoring || restoreNeeded || polling || state.phase === 'RESULTS' && result) return;
  const matchId = state.id, actorId = actor.id, sessionToken = token;
  polling = true;
  try { await refresh(); }
  catch (error) {
    if (!busy && !pending && !restoring && !restoreNeeded && state?.id === matchId && actor?.id === actorId && token === sessionToken) {
      setStatus(error.message || 'Не удалось обновить состояние.');
      if (error.status === 401) expireSession();
    }
  } finally { polling = false; syncControls(); }
}

async function restoreSession() {
  if (restoring) return;
  restoring = true; restoreNeeded = true; syncControls();
  try {
    pending = null; state = null; challenge = null; resetResult(); delete arena.dataset.state; draw();
    setStatus('Восстанавливаем сохранённый заезд…');
    const storedPending = savedObject(PENDING);
    if (validPending(storedPending)) pending = storedPending;
    else writeStorage(PENDING, null);
    const saved = savedObject(SESSION);
    const requested = !pending && !incomingConsumed && id(incoming) ? incoming : null;
    incomingConsumed = true;
    const challengeId = requested || (saved?.actorId === actor.id && id(saved.challengeId) ? saved.challengeId : null);
    if (challengeId) {
      setChallenge(await request('challenges/' + challengeId));
      if (saved?.actorId === actor.id && saved.challengeId === challengeId && id(saved.matchId)) await applyState(await request('matches/' + saved.matchId + '/state'));
    }
    if (pending) setStatus('Есть неподтверждённое действие. Повтор сохранит его номер и ключ, поэтому второй ход не будет создан.');
    else if (!state) setStatus(challenge ? 'Испытание загружено с сервера. Начни свой заезд.' : 'Сервис готов. Создай испытание и пройди маршрут.');
    restoreNeeded = false;
  } catch (error) {
    error.message = 'Не удалось восстановить заезд: ' + error.message;
    throw error;
  } finally {
    restoring = false;
    if (!restoreNeeded) remember();
    syncControls();
  }
}

function expireSession() {
  token = ''; actor = null; writeStorage(CORE_TOKEN, null); $('#auth-panel').hidden = false;
  $('#session-state').textContent = pending ? 'Сессия истекла. Для сохранённого действия войдите тем же аккаунтом.' : 'Сессия истекла. Войдите снова.';
}

async function authenticate(mode) {
  const form = $('#auth-form');
  if (!form.reportValidity()) return;
  $('#auth-status').textContent = mode === 'register' ? 'Создаём аккаунт…' : 'Проверяем вход…';
  let value;
  try { value = await request('auth/' + mode, { core: true, anonymous: true, body: { username: $('#remix-username').value.trim(), password: $('#remix-password').value } }); }
  catch (error) { $('#auth-status').textContent = error.message; throw error; }
  $('#remix-password').value = '';
  if (typeof value.token !== 'string' || !id(value.user?.id)) throw Error('Сервис входа вернул неподдерживаемую сессию.');
  token = value.token; actor = value.user; writeStorage(CORE_TOKEN, token);
  $('#auth-status').textContent = ''; $('#auth-panel').hidden = true;
  $('#session-state').textContent = 'Игрок: ' + actor.username;
  await restoreSession();
}

function canonical(value) {
  if (Array.isArray(value)) return '[' + value.map(canonical).join(',') + ']';
  if (value !== null && typeof value === 'object') return '{' + Object.keys(value).sort().map(key => JSON.stringify(key) + ':' + canonical(value[key])).join(',') + '}';
  return JSON.stringify(value);
}

async function openReplay() {
  if (!result) return;
  const value = await request('matches/' + result.matchId + '/replay');
  if (value.gameVersion !== RULESET || value.matchId !== result.matchId || value.challengeId !== challenge.id || value.playerId !== actor.id || value.purpose !== result.purpose || value.hash !== result.replayHash || !Array.isArray(value.inputs) || value.inputs.length !== result.steps || !Array.isArray(value.checkpoints) || value.checkpoints.length !== value.inputs.length || !validArena(value.arena)) throw Error('Повтор не соответствует этому результату.');
  const content = Object.fromEntries(Object.entries(value).filter(([key]) => key !== 'hash'));
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(canonical(content)));
  const hash = [...new Uint8Array(digest)].map(byte => byte.toString(16).padStart(2, '0')).join('');
  if (hash !== value.hash) throw Error('Контрольный хеш повтора не совпадает.');
  replay = value;
  $('#replay-step').max = String(value.inputs.length); $('#replay-step').value = '0';
  $('#replay-panel').hidden = false;
  showReplayFrame(); syncControls();
}

function showReplayFrame() {
  if (!replay) return;
  const index = Number($('#replay-step').value);
  const frame = index === 0 ? replay.initialState : replay.checkpoints[index - 1]?.state;
  if (!frame) return;
  draw(replay.arena, frame.position);
  $('#replay-status').textContent = `Серверный повтор · ход ${index}/${replay.inputs.length} · клетка ${frame.position[0] + 1}, ${frame.position[1] + 1} · ${frame.timeMs} мс`;
  $('#replay-panel').dataset.frame = JSON.stringify(frame);
}

function lifecycle(value) {
  try { if (window.parent !== window) window.parent.postMessage({ type: 'osgard:game-lifecycle', game: 'remix', state: value, challengeId: challenge.id, at: Date.now() }, location.origin); } catch {}
}

function reportEvent(name, payload) {
  // Preserve the existing optional analytics session; Core bearer credentials
  // are never forwarded to the independent player-events API.
  let analyticsToken = '';
  try { analyticsToken = localStorage.getItem('osgard.auth.accessToken') || ''; } catch { return; }
  if (!analyticsToken) return;
  const event = { id: crypto.randomUUID(), name, game: 'remix', payload, occurredAt: new Date().toISOString(), schemaVersion: 1 };
  fetch('/api/v1/player/events', { method: 'POST', credentials: 'same-origin', headers: { authorization: 'Bearer ' + analyticsToken, 'content-type': 'application/json' }, body: JSON.stringify({ event }) }).catch(() => {});
}

async function copyChallengeLink() {
  if (challenge?.status !== 'PUBLISHED' || !result) return;
  const link = $('#challenge-link').value;
  try { await navigator.clipboard.writeText(link); setStatus('Ссылка скопирована. Другой игрок сможет открыть это же испытание.'); reportEvent('share_link_copied', { challengeId: challenge.id, medium: 'friend_challenge' }); }
  catch { $('#challenge-link').focus(); $('#challenge-link').select(); setStatus('Ссылка выделена. Скопируйте её из поля.'); }
}

async function shareChallenge() {
  if (challenge?.status !== 'PUBLISHED' || !result) return;
  if (navigator.share) {
    try { await navigator.share({ title: 'REMIX — пройди испытание', text: 'Найди более короткий путь. Seed ' + challenge.seed, url: $('#challenge-link').value }); reportEvent('share_dialog_opened', { challengeId: challenge.id, medium: 'native_share' }); return; }
    catch (error) { if (error.name === 'AbortError') return; }
  }
  await copyChallengeLink();
}

async function createResultCardBlob() {
  const summary = summarizeResult(result);
  const lines = resultCardLines(summary, challenge.id, challenge.seed, result.won);
  const canvas = document.createElement('canvas'); canvas.width = 1200; canvas.height = 630;
  const context = canvas.getContext('2d');
  const background = context.createLinearGradient(0, 0, 1200, 630); background.addColorStop(0, '#173d30'); background.addColorStop(1, '#07110f');
  context.fillStyle = background; context.fillRect(0, 0, 1200, 630);
  context.strokeStyle = '#e7c778'; context.lineWidth = 2; context.strokeRect(26, 26, 1148, 578);
  lines.forEach((line, index) => { context.fillStyle = index === 1 || index === 3 ? '#e7c778' : '#d8e3d9'; context.font = index === 1 ? 'bold 52px Georgia' : index === 3 ? '32px system-ui' : '24px system-ui'; context.fillText(line, 70, 100 + index * 82, 1060); });
  return new Promise((resolve, reject) => canvas.toBlob(blob => blob ? resolve(blob) : reject(Error('Не удалось создать PNG результата.')), 'image/png'));
}

function downloadBlob(blob, filename) {
  const url = URL.createObjectURL(blob), link = document.createElement('a');
  link.href = url; link.download = filename; link.click(); setTimeout(() => URL.revokeObjectURL(url), 10000);
}

async function exportResult(share) {
  const blob = await createResultCardBlob();
  const filename = 'osgard-remix-challenge-' + challenge.seed + '.png';
  const file = new File([blob], filename, { type: 'image/png' });
  if (share && navigator.canShare?.({ files: [file] })) {
    try { await navigator.share({ title: 'REMIX — результат заезда', text: summarizeResult(result), files: [file] }); reportEvent('result_card_shared', { challengeId: challenge.id }); return; }
    catch (error) { if (error.name === 'AbortError') return; }
  }
  downloadBlob(blob, filename); reportEvent('result_card_exported', { challengeId: challenge.id });
  setStatus(share ? 'Браузер не передал файл напрямую. Карточка PNG скачана.' : 'Карточка с серверным результатом скачана.');
}

$('#start-match').addEventListener('click', () => act(start));
$('#rematch-challenge').addEventListener('click', () => act(start));
$('#publish-challenge').addEventListener('click', () => act(() => operation('validate', 'challenges/' + challenge.id + '/validate', { matchId: state.id })));
$('#remix-challenge').addEventListener('click', () => act(() => operation('remix', 'challenges/' + challenge.id + '/remix', { title: ('Мой ремикс / ' + challenge.title).slice(0, 100) })));
$('#retry-operation').addEventListener('click', () => { if (pending) act(() => operation(pending.kind, pending.path, pending.body, pending)); });
$('#retry-restore').addEventListener('click', () => act(restoreSession));
$('#show-replay').addEventListener('click', () => act(openReplay));
$('#replay-step').addEventListener('input', showReplayFrame);
$('#close-replay').addEventListener('click', () => { replay = null; $('#replay-panel').hidden = true; draw(); syncControls(); });
$('#new-challenge').addEventListener('click', () => {
  if (busy || pending || restoring || restoreNeeded || state?.phase === 'PLAYING') return;
  state = challenge = null; resetResult(); writeStorage(SESSION, null); delete arena.dataset.state;
  const url = new URL(location.href); url.search = ''; url.hash = ''; history.replaceState({}, '', url);
  $('#challenge-name').value = 'Испытание дня / ' + day.day; $('#challenge-seed').value = String(day.seed);
  $('#challenge-mode').textContent = 'Новое испытание'; $('#challenge-copy').textContent = 'Черновики доступны только автору.';
  $('#position-label').textContent = 'Ожидаем подтверждённое сервером поле'; $('#match-title').textContent = 'Поле испытания'; $('#match-meter i').style.width = '0';
  draw(); setStatus('Выбери название и seed следующего поля.'); syncControls();
});
for (const [name] of Object.entries(directions)) $('[data-remix-move="' + name + '"]').addEventListener('click', () => move(name));
$('[data-remix-jump]').addEventListener('click', () => move(lastDirection, true));
document.addEventListener('keydown', event => {
  if (event.ctrlKey || event.altKey || event.metaKey || event.target.closest('input,textarea,select,[contenteditable=true]') || state?.phase !== 'PLAYING' || replay) return;
  const direction = keyDirections[event.key];
  if (direction || event.code === 'Space') { event.preventDefault(); if (!event.repeat) move(direction || lastDirection, event.code === 'Space'); }
});
$('#auth-form').addEventListener('submit', event => { event.preventDefault(); act(() => authenticate('login')); });
$('#register-player').addEventListener('click', () => act(() => authenticate('register')));
$('#copy-challenge').addEventListener('click', copyChallengeLink);
$('#share-challenge').addEventListener('click', shareChallenge);
$('#share-result-card').addEventListener('click', () => act(() => exportResult(true)));
$('#download-result-card').addEventListener('click', () => act(() => exportResult(false)));
$('#sponsor-cta').addEventListener('click', () => reportEvent('partner_cta_clicked', { challengeId: challenge?.id, medium: 'post_session' }));

async function boot() {
  $('#challenge-name').value = 'Испытание дня / ' + day.day; $('#challenge-seed').value = String(day.seed); draw();
  try {
    const value = await request('capabilities', { anonymous: true });
    if (!compatibleService(value)) throw Error('Подключённый backend не объявляет совместимую арену remix-arena-v1. Этот режим здесь недоступен.');
    service = value; $('#service-state').textContent = 'Серверная арена доступна'; $('#service-state').dataset.status = 'ready';
    token = readStorage(CORE_TOKEN);
    if (token) {
      try { const current = await request('auth/me', { core: true }); actor = current.user; if (!id(actor?.id)) throw Error('Неверный формат сессии.'); }
      catch (error) { if (error.status !== 401) throw error; token = ''; writeStorage(CORE_TOKEN, null); }
    }
    if (actor) { $('#session-state').textContent = 'Игрок: ' + actor.username; await restoreSession(); }
    else { $('#session-state').textContent = 'Для сохранения заезда нужен вход'; $('#auth-panel').hidden = false; setStatus('Войдите в OSGARD Core или создайте аккаунт, чтобы начать заезд.'); }
  } catch (error) {
    if (!service) { $('#service-state').textContent = 'Серверная арена недоступна'; $('#service-state').dataset.status = 'unavailable'; setStatus(error.status === 404 ? 'На этом сайте сервис REMIX arena не включён. Создание заездов недоступно.' : error.message); }
    else { if (error.status === 401) expireSession(); setStatus(error.message); }
  }
  syncControls();
}

// Read-only synchronization must not disable a button between native touchstart
// and touchend. User mutations remain serialized by act/pending/idempotency.
setInterval(pollState, 2500);
boot();
