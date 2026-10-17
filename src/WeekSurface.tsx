import { ArrowUpRight, Flame, Trophy } from 'lucide-react'

const worlds = ['NULL//SHIFT', 'SWARM', 'REMIX', 'Империя времени', 'INHERIT']

export function WeekSurface() {
  return <main className="week-page">
    <p className="eyebrow">OSGARD PLAY / ПРОТОТИП СЕЗОНА</p>
    <h1>OSGARD<br />WEEK.</h1>
    <p className="week-lead">Демонстрация интерфейса общего испытания. Рейтинг и вступление в сезон пока не подключены.</p>
    <section className="season-banner"><Flame /><div><span>СЦЕНАРИЙ СЕЗОНА / ПРИМЕР</span><strong>Концепт общего испытания.</strong></div><b aria-label="Время сезона не назначено">—</b></section>
    <section className="leaderboard" aria-label="Макет рейтинга без результатов игроков">
      <header><span>МЕСТО / МИР</span><span>РЕЗУЛЬТАТ</span><span>СТАТУС</span></header>
      {worlds.map(title => <article key={title}><span>—</span><strong>{title}</strong><b>—</b><small>ДЕМО</small></article>)}
    </section>
    <a className="week-join" href="/play">Открыть игровые миры <ArrowUpRight /></a>
    <div className="week-note"><Trophy /> Для игры выберите мир в каталоге. Эта демонстрационная таблица не принимает рекорды.</div>
  </main>
}
