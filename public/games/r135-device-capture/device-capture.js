// OSGARD R135 W16 — user-operated same-origin physical phone evidence capture.
// This cannot certify hardware, thermals, WCAG or GPU frame-completion latency.
export const REQUIRED_RELEASE = Object.freeze({
  version: 'r135-premium-learning-w18-candidate-20261025',
  source_commit: '5971112ef861afc257aeb0e054550c158c260b6a',
  manifest_sha256: '9ba804724a840439871fe4de5e287058673d6f0ec974151ffdaee071500b3af1'
})
const ROUND = value => Number(value.toFixed(3))
export const hex = array => Array.from(new Uint8Array(array), byte => byte.toString(16).padStart(2,'0')).join('')
const assert = (ok, why) => { if (!ok) throw new Error(why) }

export function detectSupportedDevice(ua) {
  assert(typeof ua === 'string', 'Missing browser user agent')
  if (/Android/i.test(ua) && /Chrome/i.test(ua) && !/EdgA|OPR/i.test(ua))
    return 'android-chrome'
  if (/iPhone/i.test(ua) && /Safari/i.test(ua) && !/CriOS|FxiOS|EdgiOS/i.test(ua))
    return 'iphone-safari'
  throw new Error('Для W16 нужен настоящий Android Chrome либо iPhone Safari. Эмуляция не подходит.')
}

export function summarizeIntervals(intervals) {
  assert(Array.isArray(intervals) && intervals.length >= 300,
    'Нужно минимум 300 исходных видимых rAF-интервалов')
  assert(intervals.every(v => typeof v === 'number' &&
    Number.isFinite(v) && v > 0 && v <= 5000),
  'Повреждённые или искусственные интервалы кадров')
  const values = [...intervals].sort((a,b) => a-b)
  const q = p => values[Math.floor((values.length-1)*p)]
  const worstN = Math.max(1, Math.ceil(values.length * .01))
  const worstMean = values.slice(-worstN).reduce((sum,n)=>sum+n,0) / worstN
  return {
    interval_count: values.length,
    sum_visible_interval_ms: ROUND(values.reduce((sum,n)=>sum+n,0)),
    p50_interval_ms: ROUND(q(.50)),
    p95_interval_ms: ROUND(q(.95)),
    p99_interval_ms: ROUND(q(.99)),
    maximum_interval_ms: ROUND(values.at(-1)),
    callback_pacing_one_percent_low_fps: Number((1000/worstMean).toFixed(2)),
    worst_one_percent_interval_count: worstN,
    fraction_intervals_over_33_3ms: Number((intervals.filter(x=>x>33.333).length/intervals.length).toFixed(4)),
    fraction_intervals_over_50ms: Number((intervals.filter(x=>x>50).length/intervals.length).toFixed(4)),
    metric_scope: 'visible-page requestAnimationFrame callback pacing; NOT actual Godot/GPU render-completion frametimes'
  }
}

function median(values) {
  const sorted = [...values].sort((a,b)=>a-b)
  return sorted[Math.floor((sorted.length-1)/2)]
}

export function verifySoftwareSamples(samples, mode, orientation) {
  const quality = mode === 'ECO' ? 0 : mode === 'HERO' ? 2 : -1
  assert(quality >= 0, 'Только ECO и HERO')
  assert(Array.isArray(samples) && samples.length >= 100,
    'Недостаточно реальных сэмплов Godot FPS')
  assert(samples.every(s => s && s.visible === true &&
    s.quality === quality && Number.isFinite(s.fps) && s.fps > 0 &&
    s.fps <= 300 && Array.isArray(s.viewport) && s.viewport.length === 2),
  'Сэмплы не видимы либо качество/число FPS изменено')
  const [w,h] = samples[0].viewport
  assert(w >= 200 && h >= 200 &&
    (h>w?'portrait':'landscape') === orientation &&
    samples.every(s => s.viewport[0] === w && s.viewport[1] === h),
  'Положение экрана изменилось за сеанс')
  return median(samples.map(s=>s.fps))
}

export function createEvidenceRecord({
  ua, mode, orientation, release, manifestSha256, samples, intervals,
  durationSeconds, screenshotSha256, screenshotName, sessionId,
  physicalAttested, visibilityBreaks, startedAt
}) {
  const platform = detectSupportedDevice(ua)
  assert(physicalAttested === true, 'Только личная подтверждённая съёмка с настоящего телефона')
  assert(release?.version === REQUIRED_RELEASE.version &&
    release?.source_commit === REQUIRED_RELEASE.source_commit &&
    manifestSha256 === REQUIRED_RELEASE.manifest_sha256,
  'Другая сборка R135: этот сеанс нельзя включать в W16')
  assert(Number.isFinite(durationSeconds) && durationSeconds >= 60,
    'Сеанс должен длиться минимум 60 секунд')
  assert(visibilityBreaks === 0, 'Страница была скрыта во время замера; повторите сеанс')
  const medianFPS = verifySoftwareSamples(samples,mode,orientation)
  const pacing = summarizeIntervals(intervals)
  assert(typeof sessionId === 'string' && sessionId.length >= 8,
    'Отсутствует уникальный ID сеанса')
  assert(/^[a-f0-9]{64}$/.test(screenshotSha256) &&
    typeof screenshotName === 'string' &&
    screenshotName.toLowerCase().endsWith('.png') &&
    !screenshotName.includes('/') && !screenshotName.includes('\\'),
  'Нужен оригинальный PNG-скриншот и его SHA-256')
  return {
    platform, orientation, mode, session_id: sessionId,
    // Both fields may ONLY be set true AFTER independent human review of the
    // original screenshot and physical touch result.
    user_reviewed_touch: false, original_frame_reviewed: false,
    original_screenshot: screenshotName,
    capture: {
      status: 'CAPTURED_NOT_HARDWARE_CERTIFIED',
      user_attested_physical_device: true,
      software_or_unknown_unless_attested: false,
      release: {
        version: release.version, source_commit: release.source_commit,
        engine: release.engine, raw_manifest_sha256: manifestSha256
      },
      tested_mode: mode,
      timestamp_utc: startedAt,
      capture_seconds: durationSeconds,
      connected_browser: {
        user_agent: ua,
        source: 'user-operated same-origin mobile capture, NOT cryptographic physical proof'
      },
      browser_raf_callback_pacing_NOT_GPU_frametime: {
        ...pacing, raw_interval_samples_ms: intervals
      },
      raw_godot_fps_samples: samples,
      sampled_render_fps_not_frame_time_one_percent_low: { median: medianFPS },
      screenshot_sha256: screenshotSha256,
      thermal_measurement_c: null, battery_impact_measured: false,
      touch_latency_measured: false,
      warning: 'User-attested phone; rAF is callback pacing, not GPU completion; requires independent real-device review.'
    }
  }
}

// Validate complete unmodified PNG structure, not just a renamed file with
// PNG magic. CRC32 validates each original chunk before independent review.
const PNG_MAGIC = [137,80,78,71,13,10,26,10]
let crcTable
function pngCrc(bytes,begin,end) {
  if (!crcTable) crcTable = Array.from({length:256},(_,i)=>{
    let c=i
    for(let j=0;j<8;j++) c=(c&1)?(0xedb88320^(c>>>1)):(c>>>1)
    return c>>>0
  })
  let crc=0xffffffff
  for(let i=begin;i<end;i++) crc=crcTable[(crc^bytes[i])&255]^(crc>>>8)
  return (crc^0xffffffff)>>>0
}
export function verifyOriginalPng(input) {
  const data=input instanceof Uint8Array ? input : new Uint8Array(input)
  assert(data.length>=20000 && data.length<=8000000 &&
    PNG_MAGIC.every((value,i)=>data[i]===value),
  'Оригинальный файл должен быть настоящим PNG размером 20 КБ – 8 МБ')
  const view=new DataView(data.buffer,data.byteOffset,data.byteLength)
  let position=8,seenPixels=false,seenEnd=false,first=true,width=0,height=0
  while(position+12<=data.length) {
    const size=view.getUint32(position,false)
    const start=position+8,finish=start+size
    assert(size<=8000000 && finish+4<=data.length,'Повреждён или обрезан PNG')
    const type=String.fromCharCode(...data.subarray(position+4,position+8))
    const checksum=view.getUint32(finish,false)
    assert(checksum===pngCrc(data,position+4,finish),'CRC PNG не совпадает: '+type)
    if(first) {
      assert(type==='IHDR' && size===13,'Отсутствует настоящий PNG IHDR')
      width=view.getUint32(start,false)
      height=view.getUint32(start+4,false)
      assert(width>=300 && height>=300 && width<=8000 && height<=8000,
        'Неверное разрешение исходного PNG')
      first=false
    } else if(type==='IDAT') seenPixels=true
    if(type==='IEND') {
      assert(size===0 && finish+4===data.length && seenPixels,
        'Неполный PNG, посторонние данные после IEND')
      seenEnd=true
      break
    }
    position=finish+4
  }
  assert(seenEnd,'В исходном PNG отсутствует корректный IEND')
  return {width,height,bytes:data.length}
}

export async function digestBytes(bytes) {
  assert(globalThis.crypto?.subtle, 'Безопасный контекст HTTPS и Web Crypto обязательны')
  return hex(await crypto.subtle.digest('SHA-256', bytes))
}
