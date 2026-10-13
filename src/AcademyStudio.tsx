import { useEffect, useMemo, useState } from 'react'
import { ArrowDownToLine, CheckCircle2, RotateCcw } from 'lucide-react'
import type { OSACinemaLocale } from './OSACinema'
import './academyStudio.css'

type Assignment = { id:string; title:string; brief:string; deliverables:string[]; hint:string }
type Submission = { response:string; scores:number[]; deliverables:string[]; updatedAt:string }
const KEY='osgard-academy-studio-v1'
const weights=[40,30,20,10]
const copy = {
  ru:{
    eyebrow:'ПРОЕКТНАЯ МАСТЕРСКАЯ',title:'Покажите навык на реальной задаче',
    intro:'Выберите проект, подготовьте собственный результат и оцените его по единой рубрике. Черновик и оценки сохраняются в этом браузере.',
    projects:'Практические проекты',workspace:'Рабочая область',draftSaved:'Черновик сохранён',deliverableProgress:'Готовность результата',projectComplete:'Чек-лист проекта выполнен',projectInProgress:'Отмечайте готовые пункты по мере работы',deliverableCount:'пунктов готово',saveFailed:'Не удалось сохранить в этом браузере. Скопируйте или экспортируйте черновик.',startProject:'Начать проект',brief:'Задание',deliverables:'Что должно быть в результате',hint:'Подсказка',response:'Ваш результат',responseHint:'Вставьте свой анализ, план или черновик. Не добавляйте пароли, секреты и персональные данные.',wordCount:'слов',localOnly:'Черновик хранится только в локальном хранилище этого браузера: он не отправляется на сервер и не синхронизируется между устройствами.',
    rubric:'Самооценка качества',accuracy:'Точность и проверяемость',usefulness:'Практическая применимость',clarity:'Ясность и структура',safety:'Ограничения и риски',
    scale:['Не оценено','1 · Слабо','2 · Частично','3 · Хорошо','4 · Отлично'],score:'Итог самооценки',outOf:'из 100',save:'Сохранено на устройстве',export:'Экспортировать проект',reset:'Очистить черновик',resetConfirm:'Удалить черновик, оценки и отметки чек-листа этого проекта?',empty:'Начните с краткого черновика — его можно доработать позже.',
    projectsData:[
      {id:'evidence',title:'1. Проверка утверждения',brief:'Выберите значимое утверждение, которое часто повторяют в вашей сфере. Установите, что именно требуется доказать, и проверьте исходные свидетельства.',deliverables:['Точная формулировка проверяемого утверждения','Первичный источник и независимое подтверждение','Что известно, что остаётся неизвестным','Вывод с уровнем уверенности'],hint:'Не считайте несколько публикаций независимыми, если все они пересказывают один источник.'},
      {id:'privacy',title:'2. Запрос с защитой данных',brief:'Возьмите типовую рабочую задачу, для которой обычно используют документы или переписку. Спроектируйте способ выполнить её с минимальным раскрытием данных.',deliverables:['Цель и минимально необходимый контекст','Какие поля удалить или обобщить','Какие правила обработки проверить','Как проверить полезность обезличенного результата'],hint:'Удаление имени само по себе не гарантирует анонимность: сочетание деталей тоже может идентифицировать человека.'},
      {id:'decision',title:'3. Решение с участием ИИ',brief:'Выберите решение с несколькими вариантами. Используйте ИИ для черновика и альтернатив, но определите человеческую проверку до того, как принимать решение.',deliverables:['Цель, критерии и ограничения','Не менее двух альтернатив','Доказательства и допущения отдельно','Риски, ответственный человек и следующий шаг'],hint:'Чем выше цена ошибки, тем больше требуется независимая проверка и человеческий контроль.'}
    ] as Assignment[],
    criteriaData:[
      {name:'Точность и проверяемость',desc:'Утверждения отделены от предположений; доказательства можно открыть и проверить.'},
      {name:'Практическая применимость',desc:'Результат отвечает задаче и содержит выполнимые следующие шаги.'},
      {name:'Ясность и структура',desc:'Логика прозрачна, вывод и неопределённость сформулированы понятно.'},
      {name:'Ограничения и риски',desc:'Учтены приватность, последствия ошибки и необходимость человеческого решения.'}
    ] as {name:string;desc:string}[]
  },
  en:{
    eyebrow:'PROJECT STUDIO',title:'Demonstrate the skill on a real task',
    intro:'Choose a project, create your own deliverable and assess it against a shared rubric. Your draft and scores stay in this browser.',
    projects:'Practical projects',workspace:'Workspace',draftSaved:'Draft saved',deliverableProgress:'Deliverable checklist',projectComplete:'Project checklist complete',projectInProgress:'Tick off items as you complete them',deliverableCount:'items complete',saveFailed:'Could not save in this browser. Copy or export your draft.',startProject:'Start project',brief:'Assignment',deliverables:'Required deliverables',hint:'Field note',response:'Your work',responseHint:'Write your analysis, plan or draft. Do not include passwords, secrets or personal data.',wordCount:'words',localOnly:'Your draft stays in this browser’s local storage. It is not sent to a server or synced across devices.',
    rubric:'Quality self-assessment',accuracy:'Accuracy and verifiability',usefulness:'Practical usefulness',clarity:'Clarity and structure',safety:'Limits and risks',
    scale:['Not rated','1 · Weak','2 · Partial','3 · Good','4 · Excellent'],score:'Self-assessment score',outOf:'out of 100',save:'Saved on this device',export:'Export project',reset:'Clear draft',resetConfirm:'Delete this project draft, scores and checklist progress?',empty:'Start with a rough draft — you can improve it later.',
    projectsData:[
      {id:'evidence',title:'1. Verify a claim',brief:'Choose a consequential claim often repeated in your field. Define exactly what must be established and inspect the original evidence.',deliverables:['Exact wording of the claim','Primary source and independent corroboration','What is known and still unknown','Conclusion with a confidence level'],hint:'Several articles are not independent if they all repeat the same source.'},
      {id:'privacy',title:'2. A privacy-aware prompt',brief:'Take a typical work task usually handled with documents or correspondence. Design a way to complete it while exposing as little data as possible.',deliverables:['Goal and minimum necessary context','Fields to remove or generalise','Data-handling rules to check','How to test the de-identified result'],hint:'Removing a name alone does not guarantee anonymity; combinations of details may identify a person.'},
      {id:'decision',title:'3. Human-owned AI decision',brief:'Choose a decision with several possible options. Use AI for a draft and alternatives, but define human verification before making the decision.',deliverables:['Goal, criteria and constraints','At least two alternatives','Evidence separated from assumptions','Risks, accountable person and next step'],hint:'The higher the cost of error, the stronger the independent verification and human oversight required.'}
    ] as Assignment[],
    criteriaData:[
      {name:'Accuracy and verifiability',desc:'Claims are separated from assumptions; evidence can be opened and checked.'},
      {name:'Practical usefulness',desc:'The result addresses the task and gives actionable next steps.'},
      {name:'Clarity and structure',desc:'The reasoning is transparent and the conclusion and uncertainty are clear.'},
      {name:'Limits and risks',desc:'Privacy, consequences of error and human decision-making are addressed.'}
    ] as {name:string;desc:string}[]
  }
} as const

export default function AcademyStudio({locale}:{locale:OSACinemaLocale}){
  const t=copy[locale]
  const [active,setActive]=useState(()=>{try{const requested=new URLSearchParams(window.location.search).get('project');return requested&&['evidence','privacy','decision'].includes(requested)?requested:'evidence'}catch{return 'evidence'}})
  const [submissions,setSubmissions]=useState<Record<string,Submission>>({})
  const [ready,setReady]=useState(false)
  const [saveFailed,setSaveFailed]=useState(false)
  useEffect(()=>{try{if(new URLSearchParams(window.location.search).has('project'))document.getElementById('project-studio')?.scrollIntoView({behavior:'auto',block:'start'})}catch{}},[])
  const project=t.projectsData.find(item=>item.id===active) ?? t.projectsData[0]
  const submission=submissions[active] ?? {response:'',scores:[0,0,0,0],deliverables:[],updatedAt:''}
  useEffect(()=>{try{const raw=localStorage.getItem(KEY);if(raw){const parsed=JSON.parse(raw);if(parsed&&typeof parsed==='object'){const restored:Record<string,Submission>={};for(const item of t.projectsData){const value=parsed[item.id];if(value&&typeof value.response==='string'&&Array.isArray(value.scores)){restored[item.id]={response:value.response.slice(0,12000),scores:weights.map((_,i)=>Number.isInteger(value.scores[i])&&value.scores[i]>=0&&value.scores[i]<=4?value.scores[i]:0),deliverables:Array.isArray(value.deliverables)?value.deliverables.filter((id:any)=>typeof id==='string'&&item.deliverables.includes(id)):[],updatedAt:typeof value.updatedAt==='string'?value.updatedAt:''}}}setSubmissions(restored)}}}catch{}finally{setReady(true)}},[])
  useEffect(()=>{if(!ready)return;try{localStorage.setItem(KEY,JSON.stringify(submissions));setSaveFailed(false)}catch{setSaveFailed(true)}},[submissions,ready])
  const wordCount=submission.response.trim()?submission.response.trim().split(/\\s+/).length:0
  const score=useMemo(()=>Math.round(submission.scores.reduce((sum,value,i)=>sum+value/4*weights[i],0)),[submission.scores])
  const update=(next:Partial<Submission>)=>setSubmissions(previous=>({...previous,[active]:{...(previous[active]??{response:'',scores:[0,0,0,0],deliverables:[],updatedAt:''}),...next,updatedAt:new Date().toISOString()}}))
  const exportProject=()=>{const text=[project.title,project.brief,'',t.deliverables,...project.deliverables.map(item=>(submission.deliverables.includes(item)?'[x] ':'[ ] ')+item),'',t.response,submission.response,'',t.rubric,...t.criteriaData.map((item,i)=>`${item.name}: ${submission.scores[i]}/4 (${weights[i]}%)`),`${t.score}: ${score}/100`].join('\n');const blob=new Blob([text],{type:'text/plain;charset=utf-8'});const url=URL.createObjectURL(blob);const link=document.createElement('a');link.href=url;link.download=`osgard-project-${project.id}.txt`;link.click();window.setTimeout(()=>URL.revokeObjectURL(url),1000)}
  const reset=()=>{if(!window.confirm(t.resetConfirm))return;setSubmissions(previous=>({...previous,[active]:{response:'',scores:[0,0,0,0],deliverables:[],updatedAt:''}}))}
  return <section className="academy-section academy-studio" id="project-studio">
    <div className="academy-section-heading"><div><p className="academy-eyebrow">{t.eyebrow}</p><h2>{t.title}</h2></div><p>{t.intro}</p></div>
    <div className="academy-studio-layout">
      <aside className="academy-studio-projects"><p className="academy-studio-label">{t.projects}</p>{t.projectsData.map(item=><button key={item.id} type="button" className={active===item.id?'active':''} aria-pressed={active===item.id} onClick={()=>setActive(item.id)}><span>{item.title}</span><small>{submissions[item.id]?.deliverables?.length===4?t.projectComplete:submissions[item.id]?.response?.trim()||submissions[item.id]?.deliverables?.length?t.draftSaved:'○ '+t.startProject}</small></button>)}</aside>
      <div className="academy-studio-workspace">
        <div className="academy-studio-brief"><p className="academy-studio-label">{t.brief}</p><h3>{project.title}</h3><p>{project.brief}</p><div className="academy-studio-checklist"><div className="academy-studio-checklist-heading"><h4>{t.deliverables}</h4><strong>{submission.deliverables.length}/{project.deliverables.length}</strong></div><div className="academy-studio-checklist-track" role="progressbar" aria-label={t.deliverableProgress} aria-valuemin={0} aria-valuemax={project.deliverables.length} aria-valuenow={submission.deliverables.length}><span style={{width:`${submission.deliverables.length/project.deliverables.length*100}%`}} /></div><p className="academy-studio-checklist-note">{submission.deliverables.length===project.deliverables.length?t.projectComplete:t.projectInProgress}</p><ul>{project.deliverables.map((item,index)=><li key={item}><label className={submission.deliverables.includes(item)?'is-complete':''}><input type="checkbox" checked={submission.deliverables.includes(item)} onChange={event=>update({deliverables:event.target.checked?[...submission.deliverables,item]:submission.deliverables.filter(value=>value!==item)})}/><span>{item}</span></label></li>)}</ul></div><div className="academy-studio-hint"><strong>{t.hint}</strong><p>{project.hint}</p></div></div>
        <div className="academy-studio-editor"><label htmlFor="academy-studio-response">{t.response}</label><textarea id="academy-studio-response" maxLength={12000} rows={8} value={submission.response} onChange={event=>update({response:event.target.value})} placeholder={t.responseHint}/><div className="academy-studio-editor-meta"><span>{submission.response.length} / 12000 · {wordCount} {t.wordCount}</span><span role="status" aria-live="polite">{submission.updatedAt?(saveFailed?t.saveFailed:t.save):saveFailed?t.saveFailed:''}</span></div><p className="academy-studio-local-note">{t.localOnly}</p>
          <div className="academy-studio-rubric"><h4>{t.rubric}</h4>{t.criteriaData.map((item,i)=><div className="academy-studio-criterion" key={item.name}><div><strong>{item.name} <span>{weights[i]}%</span></strong><p>{item.desc}</p></div><label><span className="sr-only">{item.name}</span><select aria-label={item.name} value={submission.scores[i]} onChange={event=>update({scores:submission.scores.map((value,index)=>index===i?Number(event.target.value):value)})}>{t.scale.map((label,value)=><option key={value} value={value}>{label}</option>)}</select></label></div>)}</div>
          <div className="academy-studio-score" aria-live="polite"><div><span>{t.score}</span><strong>{score}<small> / 100</small></strong></div><div className="academy-studio-score-bar"><i style={{width:score+'%'}}/></div><p>{locale==='ru'?'Самооценка — ориентир для улучшения, а не объективная сертификация.':'Self-assessment is a guide for improvement, not an objective certification.'}</p></div>
          <div className="academy-studio-actions"><button type="button" onClick={exportProject} disabled={!submission.response.trim()}><ArrowDownToLine size={16}/>{t.export}</button><button type="button" className="academy-studio-reset" onClick={reset}><RotateCcw size={15}/>{t.reset}</button></div>
        </div>
      </div>
    </div>
  </section>
}
