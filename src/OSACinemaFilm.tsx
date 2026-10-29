import { useEffect, useState } from 'react'
import { ArrowLeft, ArrowRight, Check, CheckCircle2, Clapperboard, ExternalLink, Film, Globe2, Heart, LockKeyhole, Play, Share2, ShieldCheck, VideoOff } from 'lucide-react'
import { getStudioWork, isPublicVideoAvailable, studioWorks, type StudioLocale, type GateState } from './osaCinemaStudioRegistry'
import { readWatchlist, subscribeWatchlist, writeWatchlist } from './osaCinemaWatchlist'
import './osaCinemaStudio.css'
import './osaCinemaFilm.css'

type Props = { projectId: string }
const stateWord = (state:GateState,ru:boolean) => state==='verified' ? (ru?'Проверено':'Verified') : state==='pending' ? (ru?'В работе':'Pending') : (ru?'Не подтверждено':'Not cleared')
export default function OSACinemaFilm({projectId}:Props) {
  const project=getStudioWork(projectId)
  const [locale,setLocale]=useState<StudioLocale>(()=>new URLSearchParams(window.location.search).get('lang')==='en'?'en':'ru')
  const [saved,setSaved]=useState(false)
  const [shareMessage,setShareMessage]=useState('')
  const ru=locale==='ru'
  const tr=(a:string,b:string)=>ru?a:b
  useEffect(()=>{const sync=()=>setSaved(readWatchlist().includes(projectId));sync();return subscribeWatchlist(sync)},[projectId])
  useEffect(()=>{
    if(!project)return
    const previousTitle=document.title
    document.title=(ru?project.title:project.english)+' — OSA CINEMA'
    return()=>{document.title=previousTitle}
  },[project,ru])
  const setLanguage=()=>{
    const next=ru?'en':'ru'
    const url=new URL(window.location.href)
    url.searchParams.set('lang',next)
    window.history.replaceState(window.history.state,'',url.pathname+url.search+url.hash)
    setLocale(next)
  }
  const toggleSaved=()=>{
    if(!project)return
    const next=saved?readWatchlist().filter(x=>x!==project.id):[...readWatchlist(),project.id]
    if(!writeWatchlist(next)){
      setShareMessage(tr('Локальное сохранение недоступно в этом браузере.','Local storage is unavailable in this browser.'))
      return
    }
    setSaved(next.includes(project.id))
    setShareMessage('')
  }
  const share=async()=>{
    try{await navigator.clipboard.writeText(window.location.href);setShareMessage(tr('Ссылка скопирована.','Link copied.'))}
    catch{setShareMessage(tr('Копирование недоступно. Скопируйте адрес из браузера.','Copy is unavailable. Use your browser address bar.'))}
  }
  if(!project)return <main className="osa-studio osa-film-missing" lang={locale}><div className="osa-film-missing-inner"><p className="osa-studio-eyebrow">OSA CINEMA / 404</p><h1>{tr('Проект не найден','Project not found')}</h1><p>{tr('Такого проекта нет в подтверждённой коллекции.','This project is not in the verified collection.')}</p><a className="osa-studio-button" href={'/osa-cinema/studio?lang='+locale}><ArrowLeft size={17}/>{tr('Вернуться в коллекцию','Back to collection')}</a></div></main>
  const released=isPublicVideoAvailable(project)
  return <main className="osa-studio osa-film-page" lang={locale} data-project-id={project.id} data-public-video={released?'available':'blocked'}>
    <a className="osa-studio-skip" href="#osa-film-content">{tr('К описанию проекта','Skip to project details')}</a>
    <header className="osa-studio-header osa-film-header">
      <a className="osa-studio-brand" href={'/osa-cinema/studio?lang='+locale}><span className="osa-studio-symbol" aria-hidden="true">◈</span><span>OSA <b>CINEMA</b><small>ORIGINAL STUDIOS</small></span></a>
      <nav aria-label={tr('Навигация проекта','Project navigation')}><a href={'/osa-cinema/studio?lang='+locale}><ArrowLeft size={15}/>{tr('Коллекция','Collection')}</a><a href="#osa-film-evidence">{tr('Доказательства','Evidence')}</a><a href="#osa-film-production">{tr('Производство','Production')}</a><a href={'/osa-cinema/studio/library?lang='+locale}>{tr('Моя коллекция','My library')}</a></nav>
      <button className="osa-studio-language" type="button" aria-label={tr('Switch to English','Переключить на русский')} onClick={setLanguage}><Globe2 size={15}/>{locale.toUpperCase()}</button>
    </header>
    <section className="osa-film-hero" aria-labelledby="osa-film-title">
      <div className="osa-film-visual" role="img" aria-label={tr('Иллюстративное изображение из существующего художественного архива, не кадр нового фильма','Illustrative art from the existing archive, not a filmed frame')} style={{backgroundImage:"linear-gradient(90deg,#08090b 5%,rgba(8,9,11,.64) 56%,rgba(8,9,11,.35)),url('/osa-cinema/reference/"+project.artwork+"')"}}/>
      <div className="osa-film-hero-inner">
        <a className="osa-film-crumb" href={'/osa-cinema/studio?lang='+locale}><ArrowLeft size={15}/>{tr('НАЗАД К КОЛЛЕКЦИИ','BACK TO COLLECTION')}</a>
        <span className="osa-studio-eyebrow">OSA ORIGINAL / {project.category.toUpperCase()} / {project.year}</span>
        <h1 id="osa-film-title">{ru?project.title:project.english}</h1>
        <p className="osa-film-logline">{ru?project.loglineRu:project.loglineEn}</p>
        <div className="osa-film-tags"><span><Clapperboard size={15}/>{project.runtime}</span><span><Globe2 size={15}/>RU / EN</span><span><ShieldCheck size={15}/>{tr('Проверяемый статус','Auditable status')}</span></div>
        <div className="osa-film-actions">
          {project.href?<a className="osa-studio-button" href={project.href+'?lang='+locale}><Play size={17}/>{tr('Открыть интерактивную историю','Enter interactive story')}<ArrowRight size={16}/></a>:<a className="osa-studio-button" href="#osa-film-production"><Clapperboard size={18}/>{tr('Смотреть этапы производства','Explore production stages')}<ArrowRight size={17}/></a>}
          <button type="button" className={'osa-film-utility'+(saved?' active':'')} aria-pressed={saved} onClick={toggleSaved}><Heart size={17} fill={saved?'currentColor':'none'}/>{saved?tr('Сохранено','Saved'):tr('В избранное','Save')}</button>
          <button type="button" className="osa-film-utility" onClick={()=>void share()}><Share2 size={17}/>{tr('Поделиться','Share')}</button><a className="osa-film-utility" href={'/osa-cinema/studio/library?lang='+locale}><Heart size={17}/>{tr('Моя коллекция','My library')}</a>{project.id==='zero-window'&&<a className="osa-film-utility" href={'/osa-cinema/studio/production?lang='+locale}><Clapperboard size={17}/>{tr('Планировать производство','Production desk')}</a>}
        </div>
        <p className="osa-film-feedback" role="status" aria-live="polite">{shareMessage}</p>
      </div>
      <div className="osa-film-hero-footer"><span>{tr('Независимая студия','Independent studio')}</span><span>OSA CINEMA / EDITION 001</span></div>
    </section>
    <div className="osa-film-main" id="osa-film-content">
      <section className="osa-film-overview" aria-labelledby="osa-film-overview-title">
        <div className="osa-film-side-label">01 / {tr('О ПРОЕКТЕ','THE PROJECT')}</div>
        <div><p className="osa-studio-eyebrow">CREATIVE DOSSIER / ORIGINAL</p><h2 id="osa-film-overview-title">{tr('История, а не обещание','A story, not a promise')}</h2><p className="osa-film-prose">{ru?project.description:project.descriptionEn}</p><p className="osa-film-prose">{ru?project.formatRu:project.formatEn}</p></div>
      </section>
      <section className="osa-film-release" aria-labelledby="osa-film-release-title">
        <div className="osa-film-release-icon">{released?<CheckCircle2 size={28}/>:project.releaseState==='interactive_public'?<Film size={29}/>:<VideoOff size={29}/>}</div>
        <div><p className="osa-studio-eyebrow">RELEASE STATUS / FACT-CHECKED</p><h2 id="osa-film-release-title">{project.releaseState==='interactive_public'?tr('Интерактивный опыт доступен','Interactive experience available'):tr('Публичная премьера не состоялась','Not publicly premiered')}</h2><p>{ru?project.releaseRu:project.releaseEn}</p></div>
        {!released&&project.releaseState!=='interactive_public'&&<span className="osa-film-no-video"><LockKeyhole size={15}/>{tr('Видеопоказ закрыт','No public video')}</span>}
      </section>
      <section className="osa-film-production" id="osa-film-production" aria-labelledby="osa-film-production-title">
        <div className="osa-studio-section-head"><div><p className="osa-studio-eyebrow">02 / PRODUCTION EVIDENCE</p><h2 id="osa-film-production-title">{tr('Реальный ход производства','The actual production record')}</h2><p>{tr('Каждый статус привязан к существующему результату или невыполненному условию.','Every milestone is marked by actual progress or an outstanding condition.')}</p></div><span className="osa-studio-section-index">{project.gates.length} GATES</span></div>
        <ol className="osa-film-gate-list">{project.gates.map((g,i)=><li className={'osa-film-gate '+g.state} key={g.code}><div className="osa-film-gate-mark">{g.state==='verified'?<Check size={19}/>:<LockKeyhole size={17}/>}</div><div className="osa-film-gate-description"><span>{String(i+1).padStart(2,'0')} / {g.code}</span><h3>{ru?g.ru:g.en}</h3></div><span className="osa-film-gate-state">{stateWord(g.state,ru)}</span></li>)}</ol>
      </section>
      <section className="osa-film-evidence" id="osa-film-evidence" aria-labelledby="osa-film-evidence-title"><div><p className="osa-studio-eyebrow">03 / VERIFIED SOURCE RECORD</p><h2 id="osa-film-evidence-title">{tr('Открытая документация','The public record')}</h2><p>{tr('Документы подтверждают процесс, а не право показывать незавершённый фильм.','Documents establish production history, not permission to show unreleased films.')}</p></div><div className="osa-film-sources">{project.evidence.map(e=><a href={e.url} key={e.url} target={e.url.startsWith('https:')?'_blank':undefined} rel={e.url.startsWith('https:')?'noopener noreferrer':undefined}><span>{ru?e.labelRu:e.labelEn}</span><ExternalLink size={17}/></a>)}</div></section>
      <section className="osa-film-next" aria-labelledby="osa-film-next-title"><p className="osa-studio-eyebrow">DISCOVER MORE / OSA ORIGINAL</p><h2 id="osa-film-next-title">{tr('Другие проекты','Explore other projects')}</h2><div className="osa-film-next-grid">{studioWorks.filter(w=>w.id!==project.id).map(w=><a className="osa-film-next-card" key={w.id} href={'/osa-cinema/studio/films/'+w.id+'?lang='+locale}><span>{w.category.toUpperCase()} / {w.year}</span><strong>{ru?w.title:w.english}</strong><span>{ru?w.status:w.statusEn}<ArrowRight size={17}/></span></a>)}</div></section>
    </div>
    <footer className="osa-studio-footer"><div><span className="osa-studio-symbol" aria-hidden="true">◈</span><strong>OSA CINEMA</strong><p>{tr('Оригинальные истории. Проверяемое производство.','Original stories. Verifiable production.')}</p></div><div className="osa-studio-footer-links"><a href={'/osa-cinema/studio?lang='+locale}><ArrowLeft size={17}/>{tr('В каталог','Back to catalogue')}</a><a href="/portal"><ArrowRight size={17}/>OSGARD WORLD</a></div><span>© 2026 OSA ORIGINAL STUDIOS</span></footer>
  </main>
}
