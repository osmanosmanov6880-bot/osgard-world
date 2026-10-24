import { LAST_WORLD_KEY, createLastWorld, parseLastWorld, gameRouteFromCard } from './player-session-core.mjs'

// UX intentionally stops at the portal boundary: engines own their save files and controls.
const $ = selector => document.querySelector(selector)
const dialog = $('#player-dialog')
const panel = $('#player-help-panel')
const toggle = $('#player-help-toggle')
const help = $('#player-help-content')
const resume = $('#last-session')
const resumeLink = $('#last-session-link')
const resumeLabel = $('#last-session-game')
const resumeClear = $('#last-session-clear')
const connection = $('#player-connection-status')
const cards = new Map([...document.querySelectorAll('#games-grid article.card[data-game]')].map(card => [card.dataset.game, card]))
const allowedIds = new Set(cards.keys())
let lastRecord = null

function readStorage() {
  try { return localStorage.getItem(LAST_WORLD_KEY) } catch { return null }
}
function saveStorage(value) {
  try { localStorage.setItem(LAST_WORLD_KEY, value) } catch { /* Private browsing can reject writes. */ }
}
function clearStorage() {
  try { localStorage.removeItem(LAST_WORLD_KEY) } catch { /* Keep local UI usable. */ }
}
function renderLastWorld() {
  const record = parseLastWorld(readStorage(), allowedIds)
  const card = record && cards.get(record.id)
  const route = card && gameRouteFromCard(card, location.href)
  if (!card || !route) {
    lastRecord = null
    if (resume) resume.hidden = true
    return
  }
  lastRecord = record
  resumeLabel.textContent = card.querySelector('.game-title h3')?.textContent?.trim() || record.id
  resumeLink.href = route
  resume.hidden = false
}
function remember(id) {
  const record = createLastWorld(id, allowedIds)
  if (!record) return
  saveStorage(JSON.stringify(record))
  renderLastWorld()
}
function shouldTrack(link) {
  if (!link || !link.href) return false
  const card = link.closest('#games-grid article.card[data-game]')
  if (card) return link.matches('a.art, a.play-link, a[data-play], a[data-zion-launch]')
  return Boolean(link.matches('#recent-content a[data-play]'))
}
document.addEventListener('click', event => {
  if (event.button !== 0) return
  const link = event.target.closest('a[href]')
  if (!shouldTrack(link)) return
  const card = link.closest('#games-grid article.card[data-game]')
  const id = card?.dataset.game || link.dataset.play
  if (!allowedIds.has(id)) return
  try {
    const url = new URL(link.href, location.href)
    if (url.origin !== location.origin || !['/games/', '/play/'].some(path => url.pathname.startsWith(path))) return
    remember(id)
  } catch { /* Ignore invalid launch targets. */ }
}, true)

resumeClear?.addEventListener('click', () => {
  clearStorage()
  renderLastWorld()
})
resumeLink?.addEventListener('click', () => {
  if (lastRecord) remember(lastRecord.id)
})
window.addEventListener('storage', event => {
  if (event.key === LAST_WORLD_KEY || event.key === null) renderLastWorld()
})
renderLastWorld()

function setExpanded(open) {
  if (!panel || !toggle) return
  panel.hidden = !open
  toggle.setAttribute('aria-expanded', String(open))
}
function factRows(card) {
  const rows = []
  for (const row of card?.querySelectorAll('.launch-facts > div') || []) {
    const label = row.querySelector('dt')?.textContent?.trim()
    const value = row.querySelector('dd')?.textContent?.trim()
    if (label && value) rows.push([label, value])
  }
  return rows
}
function updateHelp() {
  if (!help || !dialog) return
  help.replaceChildren()
  const id = dialog.dataset.game
  const card = cards.get(id)
  const title = card?.querySelector('.game-title h3')?.textContent?.trim() || 'OSGARD'
  const heading = document.createElement('p')
  heading.className = 'help-game-title'
  heading.textContent = title
  help.append(heading)
  const rows = factRows(card)
  if (rows.length) {
    const list = document.createElement('dl')
    list.className = 'game-controls-facts'
    for (const [key, value] of rows) {
      const dt = document.createElement('dt')
      const dd = document.createElement('dd')
      dt.textContent = key
      dd.textContent = value
      list.append(dt, dd)
    }
    help.append(list)
  } else {
    const message = document.createElement('p')
    message.textContent = 'Управление указано внутри игрового клиента.'
    help.append(message)
  }
  const note = document.createElement('p')
  note.className = 'help-save-disclaimer'
  note.textContent = 'Подсказки относятся к выбранной игре. Быстрый возврат сохраняет только последнюю открытую игру, а не её игровой прогресс.'
  help.append(note)
}
toggle?.addEventListener('click', () => {
  if (!dialog?.open) return
  updateHelp()
  setExpanded(panel.hidden)
})
dialog?.addEventListener('close', () => setExpanded(false))
if (dialog) new MutationObserver(() => {
  updateHelp()
  if (!dialog.open) setExpanded(false)
}).observe(dialog, { attributes: true, attributeFilter: ['open', 'data-game'] })
updateHelp()
setExpanded(false)

function updateConnection() {
  if (!connection) return
  const offline = navigator.onLine === false
  connection.hidden = !offline
  connection.textContent = offline ? 'Соединение не обнаружено. Сетевые режимы могут быть недоступны.' : ''
}
window.addEventListener('offline', updateConnection)
window.addEventListener('online', updateConnection)
updateConnection()
