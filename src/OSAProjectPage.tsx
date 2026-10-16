import { useEffect, useRef, useState } from 'react'
import { emptyProject, parseProject, PROJECT_KEY, projectReadiness, safeEvidence } from './osaProjects'
import type { Project } from './osaProjects'
import './osaProject.css'

export default function OSAProjectPage() {
  const [en, setEn] = useState(false)
  const [project, setProject] = useState<Project>(emptyProject)
  const [message, setMessage] = useState('')
  const [conflict, setConflict] = useState(false)
  const baseline = useRef<string | null>(null)
  const dirty = useRef(false)
  const t = (ru: string, english: string) => en ? english : ru
  useEffect(() => {
    try { const raw = localStorage.getItem(PROJECT_KEY); baseline.current = raw; if (raw) setProject(parseProject(raw)) }
    catch { setMessage('Не удалось прочитать сохранение. Экспортируйте текущую работу перед заменой. / Could not read saved work.') }
    const update = (e: StorageEvent) => { if (e.key === PROJECT_KEY || e.key === null) setConflict(true) }
    const leave = (e: BeforeUnloadEvent) => { if (dirty.current) { e.preventDefault(); e.returnValue = '' } }
    window.addEventListener('storage', update); window.addEventListener('beforeunload', leave)
    return () => { window.removeEventListener('storage', update); window.removeEventListener('beforeunload', leave) }
  }, [])
  const edit = (patch: Partial<Project>) => { dirty.current = true; setProject(p => ({...p,...patch,updatedAt:new Date().toISOString()})); setMessage('') }
  const save = () => {
    try {
      if (localStorage.getItem(PROJECT_KEY) !== baseline.current) { setConflict(true); return }
      const raw = JSON.stringify(parseProject(JSON.stringify(project)))
      localStorage.setItem(PROJECT_KEY, raw); baseline.current = raw; dirty.current = false
      setMessage(t('Сохранено на этом устройстве.', 'Saved on this device.'))
    } catch { setMessage(t('Не удалось сохранить. Проверьте ссылку и скачайте JSON, чтобы сохранить работу.', 'Could not save. Check your URL and download JSON to keep your work.')) }
  }
  const download = () => {
    const url = URL.createObjectURL(new Blob([JSON.stringify(project,null,2)], {type:'application/json'}))
    const a = document.createElement('a'); a.href = url; a.download = 'osa-project.json'; a.click(); setTimeout(() => URL.revokeObjectURL(url),1000)
  }
  const importFile = async (file?: File) => {
    if (!file) return
    if (file.size > 100000) { setMessage(t('Файл слишком большой: максимум 100 КБ.', 'File too large: maximum 100 KB.')); return }
    try { const loaded = parseProject(await file.text()); if (window.confirm(t('Заменить открытый черновик? Сохранённая копия изменится только после нажатия «Сохранить».', 'Replace the open draft? Saved work changes only when you press Save.'))) { setProject(loaded); dirty.current = true; setMessage(t('Импортировано. Сохраните после проверки.', 'Imported. Review and save.')) } }
    catch { setMessage(t('Неверный формат JSON или небезопасная ссылка. Работа не изменена.', 'Invalid JSON format or unsafe URL. Your work is unchanged.')) }
  }
  const checks = [t('Проверил факты по независимым источникам','Checked facts against independent sources'),t('Убрал персональные данные и секреты','Removed personal data and secrets'),t('Проверил результат на новом примере','Tested the result on a new example')]
  const readiness = projectReadiness(project)
  return <main className="osa-project">
    <header><a href="/learning">← OSA Learning</a><button onClick={() => setEn(!en)}>{en ? 'RU' : 'EN'}</button></header>
    <nav><a href="/learning/workspace">{t("Мастерская и история версий", "Workspace and revision history")}</a> · <a href="/learning/program">{t("Программа", "Program")}</a></nav>
    <p className="osa-project-kicker">OSA / PROJECT WORKSPACE</p>
    <h1>{t('От знания — к результату','From knowledge to results')}</h1>
    <p>{t('Создайте инструкцию для полезной задачи с ИИ: опишите цель, проверьте ответ и покажите свою работу.', 'Create a guide for a useful AI task: define a goal, verify the output and show your work.')}</p>
    <p className="osa-project-note">{t('Гостевой режим: сохранение в этом браузере. Для переноса используйте JSON. Самооценка не является оценкой преподавателя.', 'Guest mode: saved in this browser. Use JSON to transfer work. Self-review is not an instructor assessment.')}</p>
    <section aria-labelledby="brief-title"><h2 id="brief-title">01 / {t('Замысел и план','Brief and plan')}</h2>
      {(['title','goal','audience','plan'] as const).map((key,i) => <label key={key}>{[t('Название проекта','Project title'),t('Какую задачу решаем и как измерим успех?','What problem are we solving and how will we measure success?'),t('Для кого создаём результат?','Who is this for?'),t('Шаги работы, ограничения и источники','Steps, constraints and sources')][i]}<textarea rows={key === 'plan' ? 5 : 2} maxLength={10000} value={project[key]} onChange={e => edit({[key]:e.target.value})}/></label>)}
    </section>
    <section aria-labelledby="result-title"><h2 id="result-title">02 / {t('Работа и проверка','Evidence and review')}</h2>
      <label>{t('Ссылка на результат (https://…)','Result URL (https://…)')}<input type="url" value={project.evidence} maxLength={10000} onChange={e => edit({evidence:e.target.value})}/></label>
      {safeEvidence(project.evidence) && <a href={project.evidence} target="_blank" rel="noopener noreferrer">{t('Открыть результат ↗','Open result ↗')}</a>}
      <label>{t('Что получилось, какие ошибки нашли и что улучшите?','What worked, what failed, and what will you improve?')}<textarea rows={4} maxLength={10000} value={project.reflection} onChange={e => edit({reflection:e.target.value})}/></label>
      {checks.map((label,i) => <label className="osa-project-check" key={i}><input type="checkbox" checked={project.checks[i]} onChange={e => edit({checks:project.checks.map((c,j) => j === i ? e.target.checked : c)})}/>{label}</label>)}
    </section>
    <section><h2>03 / {t('Готовность к разбору','Ready for review')}</h2><progress value={readiness.filter(Boolean).length} max={5}/><p>{readiness.filter(Boolean).length} / 5</p><ul>{[t('Цель и аудитория','Goal and audience'),t('План работы','Work plan'),t('Ссылка на работу','Evidence URL'),t('Рефлексия','Reflection'),t('Самопроверка','Self-review')].map((label,i) => <li key={i}>{readiness[i] ? '✓' : '○'} {label}</li>)}</ul><p>{t('Наличие ссылки не подтверждает качество или доступность работы. Для итоговой оценки нужен разбор преподавателя.', 'A URL does not verify quality or availability. Final assessment requires instructor review.')}</p></section>
    {conflict && <div role="alert" className="osa-project-note">{t('Сохранение изменилось в другой вкладке. Скачайте свой черновик, затем загрузите сохранённую версию.', 'Saved work changed in another tab. Download your draft, then load the saved version.')} <button onClick={() => { try { const raw = localStorage.getItem(PROJECT_KEY); const loaded = raw ? parseProject(raw) : emptyProject(); if (!window.confirm(t('Загрузить сохранённую версию вместо черновика?', 'Replace your draft with the saved version?'))) return; setProject(loaded); baseline.current = raw; dirty.current = false; setConflict(false) } catch { setMessage(t('Не удалось загрузить сохранение.', 'Could not load saved work.')) } }}>{t('Загрузить сохранение','Load saved version')}</button></div>}
    <footer><button disabled={conflict} onClick={save}>{t('Сохранить','Save')}</button><button onClick={download}>{t('Скачать JSON','Download JSON')}</button><label className="osa-project-import">{t('Импорт JSON','Import JSON')}<input type="file" accept=".json,application/json" onChange={e => { void importFile(e.target.files?.[0]); e.target.value = '' }}/></label></footer>
    <p role="status" aria-live="polite">{message}</p>
  </main>
}
