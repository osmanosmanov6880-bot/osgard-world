import { useState } from 'react'
import { ArrowLeft, ArrowRight, BadgeCheck, Clapperboard, Download, ExternalLink, Film, Globe2, LockKeyhole, ShieldAlert, ShieldCheck, VideoOff } from 'lucide-react'
import { studioWorks, type StudioLocale } from './osaCinemaStudioRegistry'
import { publicReleaseDecision } from './osaCinemaDistribution'
import './osaCinemaStudio.css'
import './osaCinemaPressRoom.css'

const documents = {
  journal:'https://github.com/osmanosmanov6880-bot/osgard-world/blob/master/docs/OSA_CINEMA_V53_CONCEPT_EVIDENCE_20261028.json',
  log:'https://github.com/osmanosmanov6880-bot/osgard-world/pull/618'
}
const statuses = {verified:{ru:'Подтверждено в доступных материалах',en:'Documented'},pending:{ru:'Требует независимой проверки',en:'Needs independent review'},blocked:{ru:'Публичная публикация недоступна',en:'Public release blocked'}}
export default function OSACinemaPressRoom() {
  const [locale,setLocale]=useState<StudioLocale>(()=>new URLSearchParams(location.search).get('lang')==='en'?'en':'ru')
  const ru=locale==='ru'
  const tr=(a:string,b:string)=>ru?a:b
  const switchLocale=()=>{
    const next=ru?'en':'ru'
    const nextUrl=new URL(window.location.href)
    nextUrl.searchParams.set('lang',next)
    window.history.replaceState(window.history.state,'',nextUrl.pathname+nextUrl.search+nextUrl.hash)
    setLocale(next)
  }
  const zoom=(id:string)=>'/osa-cinema/studio/films/'+id+'?lang='+locale
  return <main className="osa-studio osa-press-page" lang={locale} data-public-film-premiere="false">
    <a href="#osa-press-projects" className="osa-studio-skip">{tr('К проектам','Skip to projects')}</a>
    <header className="osa-studio-header">
      <a className="osa-studio-brand" href={'/osa-cinema/studio?lang='+locale} aria-label="OSA CINEMA"><span className="osa-studio-symbol" aria-hidden="true">◈</span><span>OSA <b>CINEMA</b><small>WORLD PRESS OFFICE</small></span></a>
      <nav aria-label={tr('Навигация пресс-центра','Press room navigation')}>
        <a href={'/osa-cinema/studio?lang='+locale}><ArrowLeft size={16}/>{tr('Студия','Studio')}</a>
        <a href="#osa-press-projects">{tr('Проекты','Projects')}</a>
        <a href="#osa-press-gates">{tr('Проверяемый статус','Verified status')}</a>
        <a href="#osa-press-files">{tr('Материалы','Media kit')}</a>
      </nav>
      <button className="osa-studio-language" type="button" onClick={switchLocale} aria-label={tr('Switch to English','Переключить на русский')}><Globe2 size={15}/>{locale.toUpperCase()}</button>
    </header>
    <section className="osa-press-hero" aria-labelledby="osa-press-title">
      <div className="osa-press-aurora" aria-hidden="true"/>
      <div className="osa-press-hero-inner">
        <p className="osa-studio-eyebrow">OSA ORIGINAL STUDIOS / INTERNATIONAL PRESS / 2026</p>
        <h1 id="osa-press-title">{tr('ИСТОРИИ.','STORIES.')}<br/><em>{tr('БЕЗ ВЫМЫСЛОВ.','NOT HYPE.')}</em></h1>
        <p className="osa-press-deck">{tr('Открытый двуязычный пресс-центр оригинальных интерактивных историй и кинопроектов. Каждый статус опирается на производственный реестр — без выдуманных премьер, просмотров и наград.','A bilingual editorial press centre for original interactive stories and film projects. Each status comes from production records, with no invented premieres, screenings or awards.')}</p>
        <div className="osa-press-buttons"><a className="osa-studio-button" href="#osa-press-projects">{tr('Изучить проекты','Discover projects')}<ArrowRight size={17}/></a><a className="osa-press-secondary" href="#osa-press-files"><Download size={17}/>{tr('Пресс-материалы','Press materials')}</a></div>
      </div><span className="osa-press-symbol" aria-hidden="true">◈</span>
    </section>
    <section className="osa-press-facts" aria-label={tr('Подтверждённые факты','Verified project facts')}>
      <div><strong>03</strong><span>{tr('проекта в редакционном каталоге','projects in editorial catalogue')}</span></div>
      <div><strong>02</strong><span>{tr('языка пресс-центра','languages supported')}</span></div>
      <div><strong>00</strong><span>{tr('подтверждённых публичных кинопремьер','verified public movie premieres')}</span></div>
      <div><strong>13</strong><span>{tr('запланированных игровых сцен','planned live-action scenes')}</span></div>
    </section>
    <section id="osa-press-projects" className="osa-press-collection" aria-labelledby="osa-press-collection-title">
      <div className="osa-studio-section-head"><div><p className="osa-studio-eyebrow">01 / EDITORIAL COLLECTION</p><h2 id="osa-press-collection-title">{tr('Три проекта. Три честных статуса.','Three projects. Three real statuses.')}</h2><p>{tr('Публичный интерактив, не снятый фильм и локальный концепт-превиз — это разные стадии, и мы их не смешиваем.','The public interactive experience, an unfilmed short and an owner-local concept preview are distinct stages.')}</p></div><span className="osa-studio-section-index">RU / EN</span></div>
      <div className="osa-press-project-grid">{studioWorks.map((w,i)=><article className="osa-press-project" key={w.id}>
        <div className="osa-press-art"><img src={'/osa-cinema/reference/'+w.artwork} alt={tr('Редакционный визуальный референс проекта ','Existing editorial visual reference for ')+(ru?w.title:w.english)} loading="lazy" decoding="async"/><span>OSA ORIGINAL / 0{i+1}</span></div>
        <div className="osa-press-project-copy"><p className="osa-studio-eyebrow">{w.category.toUpperCase()} / {w.year}</p><h3>{ru?w.title:w.english}</h3><p className="osa-press-summary">{ru?w.loglineRu:w.loglineEn}</p><span className={'osa-press-status osa-press-status-'+w.releaseState}><span className="osa-press-status-dot" aria-hidden="true"/>{ru?w.status:w.statusEn}</span><p className="osa-press-release">{ru?w.releaseRu:w.releaseEn}</p><a href={zoom(w.id)}>{tr('Проверить досье','Explore verified dossier')}<ArrowRight size={17}/></a></div>
      </article>)}</div>
    </section>
    <section id="osa-press-gates" className="osa-press-gates" aria-labelledby="osa-press-gates-title">
      <div className="osa-press-gate-intro"><p className="osa-studio-eyebrow">02 / RELEASE INTEGRITY</p><h2 id="osa-press-gates-title">{tr('Проверки вместо обещаний.','Proof before a premiere.')}</h2><p>{tr('Планирование, готовые локальные видеоматериалы и разрешение публичного показа — разные уровни доказательств. Отображаем отдельную картину по каждому фильму.','Planning, local video masters and public screening authorization require different evidence. Each production keeps its own documented decision.')}</p></div>
      <div className="osa-press-gate-grid">{(['zero-window','threshold'] as const).map(id=>{
        const work=studioWorks.find(w=>w.id===id)!
        const decision=publicReleaseDecision(id)
        return <article className="osa-press-gate-card" key={id}>
          <div className="osa-press-gate-card-header"><span>{ru?work.title:work.english}</span><span className="osa-press-gate-denied"><VideoOff size={15}/>NO-GO</span></div>
          <p>{ru?work.description:work.descriptionEn}</p>
          <div className="osa-press-gate-counts"><span><strong>{decision.verified}</strong>{tr('Зафиксировано','Documented')}</span><span><strong>{decision.pending}</strong>{tr('На проверку','For review')}</span><span><strong>{decision.blocked}</strong>{tr('Заблокировано','Blocked')}</span></div>
          <details><summary>{tr('Показать основания','Review evidence gates')}<ArrowRight size={16}/></summary><ul>{decision.gates.map(g=><li key={g.id}><span className={'osa-press-gate-state is-'+g.evidence} aria-hidden="true">{g.evidence==='verified'?<BadgeCheck size={16}/>:g.evidence==='pending'?<ShieldAlert size={16}/>:<LockKeyhole size={16}/>}</span><div><strong>{ru?g.nameRu:g.nameEn}</strong><p>{ru?g.descriptionRu:g.descriptionEn}</p><small>{ru?statuses[g.evidence].ru:statuses[g.evidence].en}</small></div></li>)}</ul></details>
          <a className="osa-press-gate-link" href={zoom(id)}>{tr('Перейти в досье','Go to film dossier')}<ArrowRight size={16}/></a>
        </article>
      })}</div>
    </section>
    <section id="osa-press-files" className="osa-press-files" aria-labelledby="osa-press-files-title">
      <div><p className="osa-studio-eyebrow">03 / OPEN MATERIALS</p><h2 id="osa-press-files-title">{tr('Проверяемые файлы.','Materials you can verify.')}</h2><p>{tr('Скачайте актуальный пресс-набор, построенный автоматически из утверждённого каталога и производственного акта V53. Локальные мастера фильмов и документы на права в пакет не входят.','Download the press kit generated from the approved catalogue and V53 production evidence. Private media masters and rights documents are not in these files.')}</p><p className="osa-press-safe-note"><ShieldCheck size={18}/>{tr('JSON и текстовые пресс-листы не предоставляют право на показ фильма.','The JSON and press sheets never grant screening rights.')}</p></div>
      <div className="osa-press-downloads"><a download="OSA_CINEMA_press_v1.json" href="/osa-cinema/studio/press/press.v1.json"><Download size={19}/><span>{tr('Международный каталог прессы','International press data')}<small>JSON / RU + EN / V1</small></span><ArrowRight size={17}/></a><a download="OSA_CINEMA_press_RU.txt" href="/osa-cinema/studio/press/press.ru.txt"><Download size={19}/><span>{tr('Пресс-лист на русском','Russian press sheet')}<small>TXT / RU</small></span><ArrowRight size={17}/></a><a download="OSA_CINEMA_press_EN.txt" href="/osa-cinema/studio/press/press.en.txt"><Download size={19}/><span>{tr('Пресс-лист на английском','English press sheet')}<small>TXT / EN</small></span><ArrowRight size={17}/></a><a href={documents.journal} target="_blank" rel="noopener noreferrer"><ExternalLink size={19}/><span>{tr('Первичный акт V53','Original V53 evidence')}<small>GITHUB / INDEPENDENT AUDIT NOT CLAIMED</small></span><ArrowRight size={17}/></a></div>
    </section>
    <section className="osa-press-truth"><ShieldAlert size={24}/><p>{tr('Этот пресс-центр — описание оригинальных разработок. Он не является каталогом доступных к просмотру фильмов, фестивальным отбором или юридическим подтверждением прав.','This press room describes original work in progress. It is not a public film streaming service, festival selection or independent rights certificate.')}</p></section>
    <footer className="osa-studio-footer"><div><span className="osa-studio-symbol" aria-hidden="true">◈</span><strong>OSA CINEMA</strong><p>{tr('Истории. Факты. Ответственность.','Stories. Evidence. Accountability.')}</p></div><div className="osa-studio-footer-links"><a href={'/osa-cinema/studio?lang='+locale}><Film size={16}/>{tr('Кинокаталог','Cinema catalogue')}</a><a href={documents.log} target="_blank" rel="noopener noreferrer"><Clapperboard size={16}/>{tr('Журнал производства','Production journal')}</a></div><span>© 2026 OSA ORIGINAL STUDIOS</span></footer>
  </main>
}
