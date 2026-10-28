import { useEffect, useMemo, useState, type ChangeEvent } from 'react'
import { ArrowLeft, ArrowRight, Bookmark, Check, Clapperboard, Download, Film, Globe2, LockKeyhole, ShieldCheck, Trash2, Upload } from 'lucide-react'
import { studioWorks, type StudioLocale } from './osaCinemaStudioRegistry'
import { exportWatchlist, OSA_STUDIO_MAX_IMPORT_BYTES, parseWatchlistBackup, readWatchlist, subscribeWatchlist, writeWatchlist } from './osaCinemaWatchlist'
import OSAStudioContinue from './OSAStudioContinue'
import './osaCinemaStudio.css'
import './osaCinemaLibrary.css'

export default function OSACinemaLibrary() {
  const [locale, setLocale] = useState<StudioLocale>(() => new URLSearchParams(window.location.search).get('lang') === 'en' ? 'en' : 'ru')
  const [saved, setSaved] = useState<string[]>(readWatchlist)
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')
  const [confirmClear, setConfirmClear] = useState(false)
  const ru = locale === 'ru'
  const tr = (a: string, b: string) => ru ? a : b
  useEffect(() => subscribeWatchlist(() => setSaved(readWatchlist())), [])
  const items = useMemo(() => studioWorks.filter(item => saved.includes(item.id)), [saved])
  const toggleLocale = () => {
    const next = ru ? 'en' : 'ru'
    const address = new URL(window.location.href)
    address.searchParams.set('lang', next)
    window.history.replaceState(window.history.state, '', address.pathname + address.search + address.hash)
    setLocale(next)
  }
  const remove = (id: string) => {
    const next = saved.filter(item => item !== id)
    if (!writeWatchlist(next)) {
      setError(tr('Не удалось сохранить изменение на устройстве.', 'This device cannot persist the change.'))
      return
    }
    setSaved(next)
    setConfirmClear(false)
    setError('')
    setMessage(tr('Проект убран из вашей коллекции.', 'Project removed from your collection.'))
  }
  const clear = () => {
    if (!confirmClear) { setConfirmClear(true); setMessage(''); return }
    if (!writeWatchlist([])) {
      setError(tr('Хранилище устройства недоступно. Коллекция не очищена.', 'Device storage is unavailable. Nothing was cleared.'))
      return
    }
    setSaved([])
    setConfirmClear(false)
    setError('')
    setMessage(tr('Ваша коллекция очищена на этом устройстве.', 'Your collection was cleared on this device.'))
  }
  const download = () => {
    setError('')
    setMessage('')
    let objectUrl: string | undefined
    try {
      const content = exportWatchlist(saved)
      objectUrl = URL.createObjectURL(new Blob([content], { type: 'application/json;charset=utf-8' }))
      const anchor = document.createElement('a')
      anchor.href = objectUrl
      anchor.download = 'OSA-CINEMA-watchlist-v1.json'
      document.body.appendChild(anchor)
      anchor.click()
      anchor.remove()
      setMessage(tr('Резервная копия создана. Файл сохраняется только через ваш браузер.', 'Backup prepared. Your browser handles the local download.'))
    } catch {
      setError(tr('Не удалось создать файл резервной копии.', 'Unable to prepare the backup file.'))
    } finally {
      if (objectUrl) {
        const createdUrl = objectUrl
        window.setTimeout(() => URL.revokeObjectURL(createdUrl), 1500)
      }
    }
  }
  const importFile = async (event: ChangeEvent<HTMLInputElement>) => {
    const input = event.currentTarget
    const file = input.files?.[0]
    if (!file) return
    setMessage('')
    setError('')
    try {
      if (file.size > OSA_STUDIO_MAX_IMPORT_BYTES || !/\.(json)$/i.test(file.name))
        throw Error('invalid')
      const parsed = parseWatchlistBackup(await file.text())
      if (parsed === null) throw Error('invalid')
      if (!writeWatchlist(parsed)) throw Error('storage')
      setSaved(parsed)
      setConfirmClear(false)
      setMessage(tr('Коллекция восстановлена. Сохранённые проекты: ', 'Collection restored. Saved projects: ') + parsed.length)
    } catch (problem) {
      setError(problem instanceof Error && problem.message === 'storage'
        ? tr('Хранилище заблокировано: импорт ничего не изменил.', 'Storage is blocked: import did not change your collection.')
        : tr('Неподходящий JSON. Импорт ничего не изменил.', 'Invalid JSON backup. Your collection was not changed.'))
    } finally { input.value = '' }
  }
  return <main className="osa-studio osa-library-page" lang={locale}>
    <a className="osa-studio-skip" href="#osa-library-collection">{tr('К моей коллекции','Skip to my collection')}</a>
    <header className="osa-studio-header">
      <a className="osa-studio-brand" href={'/osa-cinema/studio?lang=' + locale}><span className="osa-studio-symbol" aria-hidden="true">◈</span><span>OSA <b>CINEMA</b><small>PRIVATE COLLECTION</small></span></a>
      <nav aria-label={tr('Навигация библиотеки','Library navigation')}><a href={'/osa-cinema/studio?lang=' + locale}><ArrowLeft size={15}/>{tr('Каталог','Catalogue')}</a><a href="#osa-library-collection">{tr('Сохранённое','Saved')}</a><a href="#osa-library-backup">{tr('Мои данные','My data')}</a></nav>
      <button className="osa-studio-language" type="button" onClick={toggleLocale} aria-label={tr('Switch to English','Переключить на русский')}><Globe2 size={15}/>{locale.toUpperCase()}</button>
    </header>
    <section className="osa-library-hero" aria-labelledby="osa-library-title">
      <div className="osa-library-orbit" aria-hidden="true"/>
      <div className="osa-library-hero-inner">
        <p className="osa-studio-eyebrow">OSA ORIGINAL / THE PRIVATE EDITION</p>
        <h1 id="osa-library-title">{tr('ВАША','YOUR')}<br/><em>{tr('КОЛЛЕКЦИЯ.','COLLECTION.')}</em></h1>
        <p>{tr('Место для историй, к которым вы хотите вернуться. Без регистрации и без передачи ваших предпочтений на сервер.', 'A space for stories worth returning to. No account, no server upload of your favorites.')}</p>
      </div>
      <div className="osa-library-count"><strong>{String(saved.length).padStart(2, '0')}</strong><span>{tr('сохранено на устройстве','saved on this device')}</span></div>
    </section>
    <OSAStudioContinue locale={locale}/>
    <section className="osa-library-content" id="osa-library-collection" aria-labelledby="osa-library-collection-title">
      <div className="osa-studio-section-head"><div><p className="osa-studio-eyebrow">01 / CURATED BY YOU</p><h2 id="osa-library-collection-title">{tr('Избранные проекты','Saved projects')}</h2><p>{tr('Доступность фильмов определяется их реальным статусом, а не добавлением в избранное.', 'Saving a title does not grant access to unreleased films.')}</p></div><span className="osa-studio-section-index">WATCHLIST / {saved.length}</span></div>
      {items.length === 0 ? <div className="osa-library-empty"><Bookmark size={36}/><h3>{tr('Коллекция пока пуста.','Nothing saved yet.')}</h3><p>{tr('Откройте каталог и нажмите сердечко у интересующего проекта.','Discover the catalogue and tap the heart on any title.')}</p><a className="osa-studio-button" href={'/osa-cinema/studio?lang=' + locale}>{tr('Исследовать каталог','Explore the catalogue')}<ArrowRight size={17}/></a></div> :
      <div className="osa-library-grid">{items.map(work => <article className="osa-library-item" key={work.id}><div className="osa-library-cover" style={{backgroundImage: "linear-gradient(90deg,rgba(6,8,10,.05),rgba(6,8,10,.76)),url('/osa-cinema/reference/" + work.artwork + "')"}} aria-hidden="true"><span>OSA ORIGINAL / {work.year}</span></div><div className="osa-library-item-copy"><span className="osa-library-category">{work.category.toUpperCase()} / {work.runtime}</span><h3>{ru ? work.title : work.english}</h3><p>{ru ? work.status : work.statusEn}</p><div className="osa-library-item-actions"><a href={'/osa-cinema/studio/films/' + work.id + '?lang=' + locale}>{tr('Подробнее','View dossier')}<ArrowRight size={16}/></a><button type="button" onClick={() => remove(work.id)} aria-label={tr('Убрать из избранного: ','Remove saved title: ') + (ru ? work.title : work.english)}><Trash2 size={16}/>{tr('Убрать','Remove')}</button></div></div></article>)}</div>}
    </section>
    <section className="osa-library-backup" id="osa-library-backup" aria-labelledby="osa-library-backup-title">
      <div><p className="osa-studio-eyebrow">02 / PRIVATE BY DESIGN</p><h2 id="osa-library-backup-title">{tr('Ваши данные — ваш выбор.','Your data. Your decision.')}</h2><p>{tr('Избранное хранится только в этом браузере. Можно скачать JSON-резервную копию, восстановить её на другом устройстве или очистить коллекцию. Импорт заменяет текущий список.', 'Your favorites remain in this browser. Export a JSON backup, restore it on another device, or clear the collection. Import replaces the current list.')}</p><p className="osa-library-security"><ShieldCheck size={18}/>{tr('Никакого аккаунта, аналитического профиля или скрытой передачи списка.', 'No account, tracking profile or silent watchlist upload.')}</p></div>
      <div className="osa-library-tools"><div className="osa-library-tools-row"><button type="button" onClick={download}><Download size={20}/><span>{tr('Экспорт JSON','Export JSON')}<small>OSA_CINEMA_WATCHLIST_V1</small></span><ArrowRight size={17}/></button><input id="osa-library-json" type="file" accept=".json,application/json" onChange={event => { void importFile(event) }}/><label className="osa-library-upload" htmlFor="osa-library-json"><Upload size={20}/><span>{tr('Импорт JSON','Import JSON')}<small>{tr('До 16 КБ · только ваши проекты','Up to 16 KB · known titles only')}</small></span><ArrowRight size={17}/></label></div>{saved.length > 0 && <button className={'osa-library-clear' + (confirmClear ? ' confirm' : '')} type="button" onClick={clear}><Trash2 size={16}/>{confirmClear ? tr('Подтвердить очистку','Confirm clear') : tr('Очистить коллекцию','Clear collection')}</button>}{confirmClear && <button className="osa-library-cancel" type="button" onClick={() => setConfirmClear(false)}>{tr('Отмена','Cancel')}</button>}</div>
    </section>
    <div className="osa-library-feedback" aria-live="polite">{message && <p role="status"><Check size={17}/>{message}</p>}{error && <p role="alert"><LockKeyhole size={17}/>{error}</p>}</div>
    <footer className="osa-studio-footer"><div><span className="osa-studio-symbol" aria-hidden="true">◈</span><strong>OSA CINEMA</strong><p>{tr('Оригинальные истории. Проверяемое производство.','Original stories. Verifiable production.')}</p></div><div className="osa-studio-footer-links"><a href={'/osa-cinema/studio?lang=' + locale}><Film size={16}/>{tr('Каталог','Catalogue')}</a><a href="/portal"><ArrowRight size={16}/>OSGARD WORLD</a></div><span>© 2026 OSA ORIGINAL STUDIOS</span></footer>
  </main>
}
