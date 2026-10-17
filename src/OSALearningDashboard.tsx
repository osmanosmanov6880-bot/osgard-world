import { useEffect, useState } from 'react'
import { OSA_LEARNING_TRACKS, getOSANextLesson, getOSATrackProgress } from './osaLearningTracks'
import { getOSALearningProgress, subscribeOSALearningProgress } from './osaProgress'
import { readOSAAttempts, clearOSAAttempts } from './osaAttempts'

export default function OSALearningDashboard() {
  const [locale, setLocale] = useState<'ru' | 'en'>('ru')
  const [progress, setProgress] = useState(getOSALearningProgress)
  useEffect(() => subscribeOSALearningProgress(() => setProgress(getOSALearningProgress())), [])
  const [attempts, setAttempts] = useState(readOSAAttempts)
  useEffect(() => { const update = () => setAttempts(readOSAAttempts()); window.addEventListener('osa6:attempts-changed', update); window.addEventListener('storage', update); return () => { window.removeEventListener('osa6:attempts-changed', update); window.removeEventListener('storage', update) } }, [])
  const next = getOSANextLesson(progress.lessonCompletions)
  const count = progress.lessonCompletions.length
  return <main lang={locale} style={{maxWidth:1100,margin:'0 auto',padding:'clamp(24px,5vw,72px)',color:'#e8edf7',minHeight:'100vh'}}>
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
    <p><a href="/learning/workspace" style={{color:"#a9c4e9"}}>{locale === "ru" ? "Мои проекты и портфолио →" : "My projects and portfolio →"}</a></p>
    <p><a href="/learning/program" style={{color:"#a9c4e9"}}>{locale === "ru" ? "Практическая программа →" : "Practical program →"}</a></p>
    <p><a href="/learning/project" style={{color:"#f0ddb6"}}>{locale === "ru" ? "Создать практический проект →" : "Create a practical project →"}</a></p>
    <p><a href="/learning/pricing" style={{display:'inline-block',padding:'12px 20px',border:'1px solid #c8a96b',borderRadius:12,color:'#f0ddb6'}}>{locale === 'ru' ? 'Программы и форматы OSA →' : 'OSA programs and plans →'}</a></p>
    <p><a href="/learning/assessment" style={{display:'inline-block',padding:'12px 20px',border:'1px solid #a9c4e9',borderRadius:12,color:'#d6e5fb'}}>{locale === 'ru' ? 'Пройти итоговую самопроверку →' : 'Take the final knowledge check →'}</a></p>
    <section style={{padding:24,margin:'24px 0',border:'1px solid #39465b',borderRadius:20}} aria-label={locale==='ru'?'История тестов':'Assessment history'}>
      <h2>{locale==='ru'?'Результаты самопроверки':'Assessment results'}</h2>
      {attempts.length ? <><p>{locale==='ru'?'Попыток':'Attempts'}: {attempts.length} · {locale==='ru'?'Лучший результат':'Best score'}: {Math.max(...attempts.map(item=>item.correct))} / 8</p><ol>{attempts.slice(0,5).map(item=><li key={item.at}>{new Date(item.at).toLocaleDateString(locale==='ru'?'ru-RU':'en-US')} — {item.correct} / 8</li>)}</ol><button type="button" onClick={()=>{if(window.confirm(locale==='ru'?'Удалить историю тестов?':'Delete assessment history?')) clearOSAAttempts()}}>{locale==='ru'?'Очистить историю':'Clear history'}</button></> : <p>{locale==='ru'?'Пока нет попыток.':'No attempts yet.'}</p>}
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
