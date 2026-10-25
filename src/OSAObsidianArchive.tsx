/* OSA CINEMA / V42 OBSIDIAN ARCHIVE: existing scenes, not invented film titles. */
type Props={locale:'ru'|'en';onSelectScene:(scene:number)=>void}
const portals=[
 {scene:0,id:'I',art:'understand.webp',ru:'ПРИРОДА ИНТЕЛЛЕКТА',en:'THE NATURE OF INTELLIGENCE',subRu:'Понять, прежде чем доверять',subEn:'Understand before trusting'},
 {scene:2,id:'II',art:'library.webp',ru:'ВЛАСТЬ ЗНАНИЯ',en:'THE POWER OF KNOWLEDGE',subRu:'Кто владеет ключами?',subEn:'Who holds the keys?'},
 {scene:4,id:'III',art:'verify.webp',ru:'ПРОВЕРКА РЕАЛЬНОСТИ',en:'THE EVIDENCE TEST',subRu:'Доверие требует доказательств',subEn:'Trust requires proof'},
 {scene:6,id:'IV',art:'decide.webp',ru:'ПОСЛЕДНИЙ ВЫБОР',en:'THE FINAL CHOICE',subRu:'Ответственность остаётся за нами',subEn:'The responsibility remains ours'}
] as const
export default function OSAObsidianArchive({locale,onSelectScene}:Props){
 const ru=locale==='ru'
 return <>
  <section className='osa42-worlds' id='osa42-worlds' aria-label={ru?'Разделы истории':'Story chapters'}>
   <div className='osa42-section-head'><div><span className='osa42-kicker'>OSA / ARCHIVE 001</span><h2>{ru?'Четыре порога познания':'Four thresholds of knowing'}</h2></div><span className='osa42-section-note'>{ru?'ОДНА ИСТОРИЯ · ВОСЕМЬ СЦЕН':'ONE STORY · EIGHT SCENES'}</span></div>
   <div className='osa42-world-grid'>{portals.map(portal=><button type='button' className='osa42-world' key={portal.id} onClick={()=>onSelectScene(portal.scene)} aria-label={(ru?'Перейти к сцене ':'Open scene ')+(portal.scene+1)+': '+(ru?portal.ru:portal.en)}>
    <span className='osa42-world-art' style={{backgroundImage:"linear-gradient(180deg,transparent 18%,rgba(4,5,6,.92) 100%),url('/osa-cinema/reference/"+portal.art+"')"}} aria-hidden='true'/>
    <span className='osa42-world-number'>{portal.id} / 04</span>
    <span className='osa42-world-info'><b>{ru?portal.ru:portal.en}</b><small>{ru?portal.subRu:portal.subEn}</small></span>
    <span className='osa42-world-arrow' aria-hidden='true'>↗</span>
   </button>)}</div>
  </section>
  <section className='osa42-lower' id='osa42-about'>
   <div className='osa42-inner-circle'><span className='osa42-arch-icon' aria-hidden='true'>◈</span><div><span className='osa42-kicker'>{ru?'СТУДИЙНОЕ ДОСЬЕ':'STUDIO DOSSIER'}</span><h2>{ru?'Не всё должно быть выставлено напоказ.':'Not everything belongs on display.'}</h2><p>{ru?'Мы показываем только проверяемую интерактивную историю; невыпущенные фильмы, закрытые производственные материалы и документы недоступны публике.':'Only the verified interactive story is shown; unreleased films, private production materials and legal documents are not public.'}</p></div></div>
   <blockquote><span>“</span><p>{ru?'Главная роскошь — способность мыслить независимо.':'The rarest privilege is to think independently.'}</p><cite>OSA ORIGINAL / 001</cite></blockquote>
   <div className='osa42-method'><span className='osa42-kicker'>{ru?'АРХИВ ИДЕЙ':'ARCHIVE OF IDEAS'}</span><strong>001</strong><p>{ru?'8 интерактивных сцен. 3 акта. Никаких вымышленных премьер и платных допусков.':'Eight interactive scenes. Three acts. No invented premieres or paid-access claims.'}</p><a href='#osa42-story'>{ru?'Вернуться к истории ↑':'Return to the story ↑'}</a></div>
  </section>
 </>
}