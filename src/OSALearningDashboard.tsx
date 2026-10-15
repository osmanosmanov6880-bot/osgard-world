import { useEffect, useState } from 'react'
import { OSA_LEARNING_TRACKS, getOSANextLesson, getOSATrackProgress } from './osaLearningTracks'
import { getOSALearningProgress, subscribeOSALearningProgress } from './osaProgress'

export default function OSALearningDashboard() {
  const [locale, setLocale] = useState<'ru' | 'en'>('ru')
  const [progress, setProgress] = useState(getOSALearningProgress)
  useEffect(() => subscribeOSALearningProgress(() => setProgress(getOSALearningProgress())), [])
  const next = getOSANextLesson(progress.lessonCompletions)
  const count = progress.lessonCompletions.length
  return <main style={{maxWidth:1100,margin:'0 auto',padding:'clamp(24px,5vw,72px)',color:'#e8edf7',minHeight:'100vh'}}>
    <header style={{display:'flex',justifyContent:'space-between',gap:20,alignItems:'center'}}>
      <a href="/academy" style={{color:'#a9c4e9'}}>← OSA Academy</a>
      <button type="button" onClick={() => setLocale(locale === 'ru' ? 'en' : 'ru')} aria-label="Switch language">{locale.toUpperCase()} / {locale === 'ru' ? 'EN' : 'RU'}</button>
    </header>
    <p style={{letterSpacing:4,marginTop:60,color:'#a9c4e9'}}>OSA 6.0 / LEARNING</p>
    <h1 style={{fontSize:'clamp(36px,6vw,72px)',lineHeight:1.1}}>{locale === 'ru' ? 'Ваша карта знаний' : 'Your learning map'}</h1>
    <p style={{fontSize:18,color:'#b6c3d5'}}>{locale === 'ru' ? 'Три учебных маршрута. Восемь интерактивных лекций. Один следующий шаг.' : 'Three learning tracks. Eight interactive lessons. One next step.'}</p>
    <section aria-label={locale === 'ru' ? 'Общий прогресс' : 'Overall progress'} style={{margin:'32px 0',padding:24,border:'1px solid #39465b',borderRadius:20}}>
      <strong style={{fontSize:32}}>{count} / 8</strong>
      <p>{locale === 'ru' ? 'Пройдено лекций на этом устройстве' : 'Lessons completed on this device'}</p>
      <progress value={count} max={8} style={{width:'100%',height:12}} />
      {next ? <p><a href={'/lectures/'+next} style={{color:'#a9c4e9'}}>{locale === 'ru' ? 'Продолжить обучение →' : 'Continue learning →'}</a></p> : <p>{locale === 'ru' ? 'Все лекции завершены!' : 'All lessons completed!'}</p>}
    </section>
    <section style={{display:'grid',gridTemplateColumns:'repeat(auto-fit,minmax(240px,1fr))',gap:18}} aria-label={locale === 'ru' ? 'Учебные маршруты' : 'Learning tracks'}>
      {OSA_LEARNING_TRACKS.map(track => {
        const stats = getOSATrackProgress(track,progress.lessonCompletions)
        return <article key={track.id} style={{padding:24,border:'1px solid #39465b',borderRadius:20,background:'#101a2a'}}>
          <p style={{fontSize:12,letterSpacing:2,color:'#a9c4e9'}}>OSA / {track.id.toUpperCase()}</p>
          <h2 style={{fontSize:23}}>{track.title[locale]}</h2>
          <p style={{color:'#b6c3d5'}}>{track.description[locale]}</p>
          <progress value={stats.completed} max={stats.total} style={{width:'100%'}} />
          <p>{stats.completed} / {stats.total} · {stats.percent}%</p>
          <a style={{color:'#a9c4e9'}} href={'/lectures/'+track.lessonSlugs[0]}>{locale === 'ru' ? 'Открыть маршрут →' : 'Open track →'}</a>
        </article>
      })}
    </section>
    <p style={{marginTop:40,color:'#91a1b9',fontSize:13}}>{locale === 'ru' ? 'Прогресс хранится локально в браузере. Синхронизация аккаунта пока не подключена.' : 'Progress is stored locally in this browser. Account sync is not yet available.'}</p>
  </main>
}
