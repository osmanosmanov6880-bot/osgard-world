import { useEffect, useState } from 'react'
import { ArrowRight, Check, ChevronLeft, Download, FolderPlus, Plus, Save, Trash2 } from 'lucide-react'
import { coreRequest, CoreError, storePending, readPending } from './coreClient'
import type { CoreProject } from './coreClient'
import { PROJECT_KINDS, createProjectPayload, newCreateDraft, persistCreateDrafts, readCreateDrafts, validateCreateDraft } from './projectCreation'
import type { CreateDraft, ProjectKind } from './projectCreation'
import './create.css'

const steps = ['Идея', 'Настройка', 'Структура', 'Работа', 'Проверка', 'Создание']
const id = () => crypto.randomUUID()
const first = () => readCreateDrafts()
function downloadDraft(draft: CreateDraft) {
  const blob = new Blob([JSON.stringify({ schema: 'osgard-create-draft/v1', project: draft }, null, 2)], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = 'osgard-' + draft.id.slice(0, 8) + '.json'; a.click()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}
export function CreatePrototype() {
  const [drafts, setDrafts] = useState<CreateDraft[]>(first)
  const [selectedId, setSelectedId] = useState<string | null>(() => first()[0]?.id ?? null)
  const [step, setStep] = useState(0)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')
  const [saving, setSaving] = useState(false)
  const [storageOK, setStorageOK] = useState(true)
  const [pendingKey, setPendingKey] = useState<string | null>(null)
  const draft = drafts.find(item => item.id === selectedId)
  useEffect(() => { setStorageOK(persistCreateDrafts(drafts)) }, [drafts])
  function start() {
    const next = newCreateDraft(id())
    setDrafts(list => [next, ...list].slice(0, 12))
    setSelectedId(next.id); setStep(0); setError(''); setMessage('')
  }
  function edit(patch: Partial<CreateDraft>) {
    setDrafts(list => list.map(item => item.id === selectedId ? { ...item, ...patch, serverProjectId: undefined, updatedAt: new Date().toISOString() } : item))
    setError(''); setMessage('')
  }
  function modifyItem(name: 'tasks' | 'acceptance', index: number, value: string) {
    if (!draft) return
    edit({ [name]: draft[name].map((v, i) => index === i ? value : v) })
  }
  function removeItem(name: 'tasks' | 'acceptance', index: number) {
    if (!draft) return
    edit({ [name]: draft[name].filter((_, i) => i !== index) })
  }
  function next() {
    if (!draft) return
    if (step === 0 && (draft.title.trim().length < 2 || draft.goal.trim().length < 10)) { setError('Введите название и описание цели не короче 10 символов.'); return }
    if (step === 2 && draft.tasks.some(v => v.trim().length < 2)) { setError('Заполните задачи или удалите пустые строки.'); return }
    if (step === 4) { const err = validateCreateDraft(draft); if (err) { setError(err); return } }
    setStep(Math.min(5, step + 1)); setError('')
  }
  async function create() {
    if (!draft || saving) return
    let data: ReturnType<typeof createProjectPayload>
    try { data = createProjectPayload(draft) } catch (e) { setError(e instanceof Error ? e.message : 'Проверьте проект.'); return }
    setSaving(true); setError(''); setMessage('')
    const previous = readPending()
    const matched = previous?.route === 'projects' && previous.body?.clientDraftId === draft.id
    const key = matched ? previous.key : (pendingKey || id())
    setPendingKey(key)
    const payload = { ...data, clientDraftId: draft.id }
    if (!matched && previous) { setError('В Core есть другое незавершённое действие. Проверьте его в рабочем пространстве, прежде чем повторять сохранение.'); setSaving(false); return }
    try {
      // A recovered Core session is required. The server remains authoritative.
      const me = await coreRequest<{ user: { id: string } }>('auth/me')
      storePending({ userId: me.user.id, route: 'projects', body: payload, key })
      const created = await coreRequest<{ project: CoreProject }>('projects', payload, key)
      storePending(null); setPendingKey(null)
      edit({ serverProjectId: created.project.id })
      setDrafts(list => list.map(item => item.id === draft.id ? { ...item, serverProjectId: created.project.id } : item))
      setMessage('Проект создан на сервере. Откройте редактор, чтобы продолжить работу.')
    } catch (e) {
      if (e instanceof CoreError && e.status === 401) {
        storePending(null)
        setError('Для серверного создания войдите в OSGARD Core. Локальный черновик сохранён. После входа вернитесь сюда.')
      } else if (e instanceof CoreError && e.status >= 400 && e.status < 500) {
        storePending(null)
        setError(e.message)
      } else {
        setError('Связь с сервером не подтверждена. Проект мог создаться; повтор использует тот же ключ. Не открывайте новый черновик до проверки.')
      }
    } finally { setSaving(false) }
  }
  return <main className="create-page create-studio">
    <header className="create-studio-header"><div><p className="eyebrow">OSGARD / PROJECT CREATION STUDIO</p><h1>От идеи к проекту.</h1><p>Сформируйте план, сохраните черновик и создайте проект в серверном рабочем пространстве.</p></div><a className="create-link" href="/workspace">Мои проекты <ArrowRight size={17}/></a></header>
    <div className="create-studio-grid">
      <aside className="create-studio-sidebar" aria-label="Черновики проектов"><div className="create-panel-heading"><h2>Черновики</h2><button type="button" onClick={start} aria-label="Новый проект" disabled={drafts.length >= 12}><Plus size={19}/></button></div><p className="create-muted">Сохранены только в этом браузере · до 12 проектов</p>{drafts.map(item => <button key={item.id} type="button" className={'create-draft-item' + (item.id === selectedId ? ' active' : '')} onClick={() => { setSelectedId(item.id); setStep(0); setError(''); setMessage('') }}><FolderPlus size={17}/><span>{item.title || 'Без названия'}<small>{new Date(item.updatedAt).toLocaleDateString('ru-RU')}</small></span></button>)}{!drafts.length && <button type="button" className="create-primary" onClick={start}><Plus size={17}/> Создать первый проект</button>}</aside>
      <section className="create-studio-main">
        {!draft ? <div className="create-empty"><h2>Начните с идеи</h2><p>Одна цель, понятный результат, минимум обязательных полей.</p><button onClick={start} className="create-primary">Создать проект <ArrowRight size={18}/></button></div> : <>
          <div className="create-studio-top"><p className="eyebrow">ШАГ {step + 1} / 6</p><span>{storageOK ? <><Save size={15}/> Черновик сохранён локально</> : 'Хранилище браузера недоступно — экспортируйте черновик'}</span></div>
          <nav className="create-progress" aria-label="Этапы создания">{steps.map((name, index) => <button key={name} type="button" aria-current={step === index ? 'step' : undefined} className={index === step ? 'active' : index < step ? 'complete' : ''} onClick={() => { setStep(index); setError('') }}><span>{index < step ? <Check size={14}/> : index + 1}</span>{name}</button>)}</nav>
          <div className="create-editor" key={draft.id}>
            {step === 0 && <><p className="eyebrow">01 / ИДЕЯ</p><h2>Что вы хотите создать?</h2><p className="create-muted">Опишите желаемый результат человеческим языком. AI-генерация пока не подключена.</p><label>Название проекта<input autoFocus maxLength={160} value={draft.title} onChange={e => edit({ title: e.target.value })} placeholder="Например, сервис управления заказами"/></label><label>Какую проблему решает проект?<textarea maxLength={4000} rows={5} value={draft.goal} onChange={e => edit({ goal: e.target.value })} placeholder="Для кого, какую проблему и с каким ожидаемым результатом?"/></label></>}
            {step === 1 && <><p className="eyebrow">02 / НАСТРОЙКА</p><h2>Выберите направление</h2><div className="create-kind-list">{(Object.keys(PROJECT_KINDS) as ProjectKind[]).map(kind => <button key={kind} aria-pressed={kind === draft.kind} className={kind === draft.kind ? 'selected' : ''} onClick={() => edit({ kind, tasks: [...PROJECT_KINDS[kind].tasks] })}>{PROJECT_KINDS[kind].label}<span>{kind === draft.kind ? 'Выбрано' : 'Выбрать'}</span></button>)}</div><label>Для кого создаём?<textarea rows={3} maxLength={1000} value={draft.audience} onChange={e => edit({ audience: e.target.value })} placeholder="Кто будет пользоваться результатом?"/></label></>}
            {step === 2 && <><p className="eyebrow">03 / СТРУКТУРА</p><h2>План проекта</h2><p className="create-muted">Это редактируемый шаблон, а не результат AI. До 30 задач.</p><div className="create-items">{draft.tasks.map((task, index) => <div key={index} className="create-item"><span>{String(index+1).padStart(2,'0')}</span><input aria-label={'Задача ' + (index+1)} maxLength={500} value={task} onChange={e => modifyItem('tasks',index,e.target.value)}/><button type="button" aria-label={'Удалить задачу ' + (index+1)} onClick={() => removeItem('tasks',index)}><Trash2 size={17}/></button></div>)}</div><button className="create-secondary" disabled={draft.tasks.length >= 30} onClick={() => edit({ tasks: [...draft.tasks, ''] })}><Plus size={17}/> Добавить задачу</button></>}
            {step === 3 && <><p className="eyebrow">04 / РАБОТА</p><h2>Ваш рабочий процесс</h2><p>В серверном OSGARD Core доступны редактирование задач, версии, история проекта и экспорт. Здесь мы готовим структуру и не имитируем выполнение работ.</p><div className="create-workflow">{draft.tasks.map((task,i) => <div key={i}><span>{String(i+1).padStart(2,'0')}</span><strong>{task || 'Незаполненная задача'}</strong><small>Не начато</small></div>)}</div></>}
            {step === 4 && <><p className="eyebrow">05 / ПРОВЕРКА</p><h2>Как понять, что готово?</h2><p className="create-muted">Критерии приёмки помогут не перепутать красивый экран с работающим продуктом.</p><div className="create-items">{draft.acceptance.map((item,index)=><div key={index} className="create-item"><span>{index+1}</span><input aria-label={'Критерий '+(index+1)} value={item} maxLength={500} onChange={e => modifyItem('acceptance',index,e.target.value)}/><button aria-label={'Удалить критерий '+(index+1)} onClick={() => removeItem('acceptance',index)}><Trash2 size={17}/></button></div>)}</div><button className="create-secondary" disabled={draft.acceptance.length>=30} onClick={() => edit({ acceptance:[...draft.acceptance,''] })}><Plus size={17}/> Добавить критерий</button></>}
            {step === 5 && <><p className="eyebrow">06 / СОЗДАНИЕ</p><h2>{draft.serverProjectId ? 'Проект создан в Core' : 'Создать проект в Core'}</h2><div className="create-summary"><div><span>Название</span><strong>{draft.title}</strong></div><div><span>Тип</span><strong>{PROJECT_KINDS[draft.kind].label}</strong></div><div><span>Задачи</span><strong>{draft.tasks.length}</strong></div><div><span>Критерии</span><strong>{draft.acceptance.length}</strong></div></div><p className="create-muted">Создание сохраняет проект на сервере, но не публикует сайт и не запускает AI. Для этого нужны отдельные действия и проверка.</p>{draft.serverProjectId ? <a className="create-primary" href={'/workspace?project='+draft.serverProjectId}>Открыть созданный проект <ArrowRight size={18}/></a> : <button className="create-primary" disabled={saving} onClick={() => void create()}>{saving ? 'Проверяем сохранение…' : 'Создать на сервере'} <ArrowRight size={18}/></button>}<a className="create-link" href="/workspace">Войти в Core / мои проекты →</a></>}
          </div>
          {error && <p role="alert" className="create-alert">{error}</p>}{message && <p role="status" className="create-success">{message}</p>}
          <div className="create-editor-footer"><div><button type="button" className="create-secondary" onClick={() => downloadDraft(draft)}><Download size={17}/> Экспорт JSON</button><button type="button" className="create-secondary" onClick={() => { if (!confirm('Удалить локальный черновик?')) return; setDrafts(list=>list.filter(item=>item.id!==draft.id)); setSelectedId(null); setStep(0) }}><Trash2 size={17}/> Удалить</button></div><div>{step>0 && <button type="button" className="create-secondary" onClick={() => { setStep(step-1); setError('') }}><ChevronLeft size={17}/> Назад</button>}{step<5 && <button type="button" className="create-primary" onClick={next}>Продолжить <ArrowRight size={17}/></button>}</div></div>
        </>}
      </section>
    </div>
  </main>
}
