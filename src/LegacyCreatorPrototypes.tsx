import { ArrowRight, BookOpen, GitBranch, Heart } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import { recordOsgardEvent } from './core/eventQueue'
import { completePlayerSession, startPlayerSession } from './core/playerApi'
export function InheritPrototype() { const [generation, setGeneration] = useState(1); const [memory, setMemory] = useState(0); const [trust, setTrust] = useState(62); const session = useRef<string | null>(null); const completed = useRef(false); useEffect(() => { void startPlayerSession('inherit', { surface: 'inherit' }).then(value => { session.current = value?.id ?? null }) }, []); useEffect(() => { if (generation >= 5 && session.current && !completed.current) { completed.current = true; void completePlayerSession(session.current, { generation, memory, trust }) } }, [generation, memory, trust]); const advance = () => { setGeneration(generation + 1); setMemory(memory + 1); setTrust(Math.min(100, trust + 4)); recordOsgardEvent('portal_opened', { game: 'inherit', action: 'GENERATION_ADVANCED', generation: generation + 1 }) }; return <main className="legacy-page"><p className="eyebrow">OSGARD PLAY / INHERIT</p><h1>То, что<br />остаётся.</h1><p className="legacy-lead">Семья меняется. Память остаётся. Передайте следующий мир дальше.</p><section className="family-card"><Heart /><div><span>СЕМЬЯ / АРХИВ</span><strong>Дом Вега</strong><small>Поколение {generation} · {memory} сохранённых воспоминаний</small></div><b>{trust}% доверия</b></section><button className="legacy-action" onClick={advance}>Передать поколение <ArrowRight /></button><section className="memory-list"><article><BookOpen /><span>Первый дом</span><b>НАСЛЕДИЕ</b></article><article><GitBranch /><span>Дорога на север</span><b>ВОСПОМИНАНИЕ</b></article></section></main> }
/** Keep old invitation links on the real console without running the retired demo. */
export function remixLegacyDestination(search: string, hash: string): string {
  const allowed = new Set(['challenge', 'seed', 'ref', 'lang', 'utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term'])
  const target = new URL('/games/remix/', 'https://osgard.world')
  for (const [key, value] of new URLSearchParams(search)) if (allowed.has(key)) target.searchParams.append(key, value)
  target.hash = hash
  return target.pathname + target.search + target.hash
}

export function RemixLegacyRedirect() {
  const destination = remixLegacyDestination(window.location.search, window.location.hash)
  useEffect(() => { window.location.replace(destination) }, [destination])
  return <main className="remix-page"><p className="eyebrow">OSGARD PLAY / REMIX</p><h1>Открываем консоль испытаний.</h1><p className="remix-lead">Приглашение и выбранный язык перейдут на актуальную страницу REMIX.</p><a className="brand-button primary" href={destination}>Перейти в REMIX <ArrowRight /></a></main>
}
