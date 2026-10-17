import { Eye, Film, Radio, Users } from 'lucide-react'
import { useState } from 'react'
import { recordOsgardEvent } from './core/eventQueue'

type Mode = 'LIVE' | 'SPECTATOR' | 'REPLAY' | 'CHALLENGE'
const modes: Array<{ id: Mode; label: string; icon: typeof Radio }> = [
  { id: 'LIVE', label: 'Эфир', icon: Radio },
  { id: 'SPECTATOR', label: 'Наблюдение', icon: Eye },
  { id: 'REPLAY', label: 'Повтор', icon: Film },
  { id: 'CHALLENGE', label: 'Испытание', icon: Users },
]

export function StreamSurface() {
  const [mode, setMode] = useState<Mode>('LIVE')
  const choose = (next: Mode) => { setMode(next); recordOsgardEvent('portal_opened', { surface: 'stream', mode: next, demo: true }) }
  const selected = modes.find(item => item.id === mode)!
  return <main className="stream-page">
    <p className="eyebrow">OSGARD PLAY / ПРОТОТИП ТРАНСЛЯЦИИ</p>
    <h1>Режимы<br />наблюдения.</h1>
    <p className="stream-lead">Демонстрация интерфейса эфира, наблюдения, повтора и испытания. Видеопоток, зрители и архив повторов пока не подключены.</p>
    <nav className="stream-modes" aria-label="Режимы демонстрации">{modes.map(item => {
      const Icon = item.icon
      return <button className={mode === item.id ? 'is-active' : ''} aria-pressed={mode === item.id} onClick={() => choose(item.id)} key={item.id}><Icon />{item.label}</button>
    })}</nav>
    <section className="stream-stage">
      <div className="stream-signal">ДЕМО / {selected.label}</div>
      <div className="stream-grid">
        <div><span>МИР / ПРИМЕР</span><strong>{mode === 'CHALLENGE' ? 'REMIX' : mode === 'REPLAY' ? 'Империя времени' : 'SWARM'}</strong></div>
        <div><span>ЗРИТЕЛИ</span><strong aria-label="Зрители не подключены">—</strong></div>
        <div><span>СТАТУС</span><strong>ДЕМО</strong></div>
      </div>
      <a className="stream-primary" href={mode === 'CHALLENGE' ? '/games/remix/' : '/play'}>{mode === 'CHALLENGE' ? 'Открыть консоль REMIX' : 'Выбрать игровой мир'} <Radio /></a>
    </section>
  </main>
}
