import { REQUIRED_RELEASE, detectSupportedDevice, createEvidenceRecord, digestBytes, verifyOriginalPng } from './device-capture.js'
const $ = id => document.getElementById(id)
const start = $('start')
const mode = $('mode')
const physical = $('physical')
const screenshot = $('screenshot')
const exportButton = $('export')
const frame = $('game')
const status = $('status')
let pending = null
let running = false
const update = (message, state='') => {
  status.textContent = message
  status.className = 'status '+state
}
function checkView(view) {
  if (!view || !view.scene_ready || !view.loaded?.endsWith('.glb'))
    throw new Error('Настоящая игра Godot ещё не загружена.')
  const q = mode.value === 'ECO' ? 0 : 2
  if (view.quality !== q) throw new Error('В игре включён другой режим. Выбери '+mode.value+' внутри игры.')
  if (!Number.isFinite(view.render_fps_sample) || view.render_fps_sample <= 0)
    throw new Error('Игра пока не выдаёт измеримый FPS.')
  if (!Number.isFinite(view.viewport_w) || !Number.isFinite(view.viewport_h))
    throw new Error('Не найдены настоящие размеры сцены.')
  return [view.viewport_w,view.viewport_h]
}
const imageFile = async file => {
  if (!file || !file.name.toLowerCase().endsWith('.png'))
    throw new Error('Выбери оригинальный PNG-скриншот (20 КБ – 8 МБ).')
  const bytes = new Uint8Array(await file.arrayBuffer())
  verifyOriginalPng(bytes)
  return digestBytes(bytes)
}
function downloadJson(record) {
  const blob = new Blob([JSON.stringify({sessions:[record]},null,2)+'\n'],{type:'application/json'})
  const url=URL.createObjectURL(blob)
  try {
    const a=document.createElement('a')
    a.href=url
    a.download='r135-w16-'+record.platform+'-'+record.orientation+'-'+record.mode+'-'+record.session_id+'.json'
    document.body.append(a)
    a.click()
    a.remove()
  } finally { setTimeout(()=>URL.revokeObjectURL(url),1000) }
}
start.addEventListener('click',async()=>{
  if (running) return
  try {
    if (physical.checked !== true) throw new Error('Подтверди настоящий телефон.')
    detectSupportedDevice(navigator.userAgent)
    if (!crypto?.subtle || !crypto?.randomUUID) throw new Error('Для проверки требуется HTTPS и Web Crypto.')
    const game=frame.contentWindow
    const initial=game.__OSGARD_R135_QA
    const initialViewport=checkView(initial)
    const response=await fetch('/games/r135-service/release.json',{cache:'no-store'})
    if (!response.ok) throw new Error('Не удалось загрузить реальный манифест игры.')
    const bytes=await response.arrayBuffer()
    const hash=await digestBytes(bytes)
    const release=JSON.parse(new TextDecoder().decode(bytes))
    if (hash!==REQUIRED_RELEASE.manifest_sha256 ||
        release.version!==REQUIRED_RELEASE.version ||
        release.source_commit!==REQUIRED_RELEASE.source_commit)
      throw new Error('Опубликованная игра не совпадает с принятой версией W18. Захват запрещён.')
    const orientation=initialViewport[1]>initialViewport[0]?'portrait':'landscape'
    screenshot.value=''
    screenshot.disabled=true
    exportButton.disabled=true
    pending=null
    start.disabled=true
    mode.disabled=true
    physical.disabled=true
    running=true
    const startedAt=new Date().toISOString()
    const started=Date.now()
    const durationMs=65_000
    const samples=[]
    const intervals=[]
    let last=null,interruptions=0
    let recordRaf=true
    const onVis=()=>{if (document.visibilityState!=='visible'){last=null;interruptions++}}
    document.addEventListener('visibilitychange',onVis)
    const onFrame=now=>{
      if (!recordRaf)return
      if (document.visibilityState==='visible') {
        if (last!==null && now>last)intervals.push(now-last)
        last=now
      } else {last=null;interruptions++}
      requestAnimationFrame(onFrame)
    }
    requestAnimationFrame(onFrame)
    const timer=setInterval(()=>{
      try {
        const qa=game.__OSGARD_R135_QA||{}
        samples.push({
          visible:document.visibilityState==='visible',
          quality:qa.quality,fps:Number(qa.render_fps_sample),
          viewport:[qa.viewport_w,qa.viewport_h]
        })
        const remaining=Math.max(0,Math.ceil((durationMs-(Date.now()-started))/1000))
        update('Замер продолжается: '+remaining+' сек. · Godot '+samples.length+' сэмплов.','')
      } catch(error) {
        interruptions++
        update('Ошибка реального измерения: '+error.message,'bad')
      }
    },250)
    await new Promise(resolve=>setTimeout(resolve,durationMs+600))
    clearInterval(timer)
    recordRaf=false
    document.removeEventListener('visibilitychange',onVis)
    const elapsed=(Date.now()-started)/1000
    const final=checkView(game.__OSGARD_R135_QA)
    if (final[0]!==initialViewport[0]||final[1]!==initialViewport[1])
      throw new Error('Размер игрового экрана изменился, начни новый сеанс.')
    if (interruptions>0 || document.visibilityState!=='visible')
      throw new Error('Сеанс прервался или приложение свёрнуто. Результат не сохраняется.')
    pending={ua:navigator.userAgent,mode:mode.value,orientation,release,manifestSha256:hash,
      samples,intervals,durationSeconds:elapsed,physicalAttested:true,
      visibilityBreaks:interruptions,startedAt,sessionId:crypto.randomUUID()}
    screenshot.disabled=false
    update('65 секунд получены. Сделай скриншот на телефоне и выбери исходный PNG.','good')
  } catch(error) {
    pending=null
    screenshot.disabled=true
    exportButton.disabled=true
    update(error instanceof Error?error.message:String(error),'bad')
  } finally {
    running=false
    start.disabled=false
    mode.disabled=false
    physical.disabled=false
  }
})
screenshot.addEventListener('change',async()=>{
  exportButton.disabled=true
  if (!pending) return
  try {
    const file=screenshot.files?.[0]
    const screenshotSha256=await imageFile(file)
    pending.record=createEvidenceRecord({...pending,
      screenshotSha256,screenshotName:file.name})
    exportButton.disabled=false
    update('Исходный PNG подтверждён SHA-256. Экспорт готов, но независимая проверка ещё не выполнена.','good')
  } catch(error) {
    update(error instanceof Error?error.message:String(error),'bad')
  }
})
exportButton.addEventListener('click',()=>{
  if (!pending?.record)return
  downloadJson(pending.record)
  update('JSON сохранён локально. Сохрани также исходный PNG; оба файла нужны проверяющему.','good')
})
