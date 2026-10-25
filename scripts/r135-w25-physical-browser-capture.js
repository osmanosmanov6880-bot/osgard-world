// OSGARD R135 W25. Run only by an independent tester on a REAL phone,
// while the LIVE game is visible and actively rendering. This is a
// measurement draft, NOT independent hardware attestation. Nothing uploads.
// Usage in phone browser's remote DevTools: await OSGARDR135PhoneProbe.run()
//
// This script does not run at page load, does not identify users or transmit
// any data. User must separately make a continuous screen recording.
const OSGARDR135PhoneProbe = (() => {
  const SCHEMA = 'osgard-r135-w25-browser-frames-v1'
  const MAX_SAMPLE = 1800
  const quantile = (sorted, p) => sorted[Math.min(sorted.length - 1,
    Math.max(0, Math.ceil(sorted.length * p) - 1))] ?? null
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms))
  const round = n => Math.round(n * 1000) / 1000
  const validSha = s => /^[a-f0-9]{40}$/.test(s || '')
  let busy = false

  async function run({ warmupMs = 3000, sampleMs = 30000 } = {}) {
    if (busy) throw new Error('Already measuring a phone session')
    if (document.hidden) throw new Error('Keep the genuine game tab visible')
    if (sampleMs < 20000 || sampleMs > 60000 || warmupMs < 2000 || warmupMs > 10000) {
      throw new Error('Test needs 2–10s warmup and 20–60s uninterrupted gameplay')
    }
    const first = window.__OSGARD_R135_QA
    if (!first?.scene_ready || !first?.simulation_only ||
        !first?.viewport_w || !first?.viewport_h) {
      throw new Error('Actual Godot OSGARD R135 simulation is not running')
    }
    const href = new URL('./release.json', window.location.href)
    const response = await fetch(href.toString(), { cache: 'no-store', credentials: 'omit' })
    if (!response.ok) throw new Error('Uncached live release.json unavailable')
    const manifest = await response.json()
    if (!validSha(manifest.source_commit) || manifest.engine !== 'Godot 4.4.1') {
      throw new Error('Live exact-source Godot manifest missing')
    }
    busy = true
    let lost = false
    const canvas = document.querySelector('canvas')
    if (!canvas) throw new Error('Game canvas not available')
    const onLost = e => { lost = true; e.preventDefault() }
    canvas.addEventListener('webglcontextlost', onLost)
    try {
      await sleep(warmupMs)
      if (document.hidden) throw new Error('Browser tab hidden during warmup')
      let prev = null
      let cancelled = false
      const deltas = []
      const startedAt = performance.now()
      let lastState = first
      await new Promise((resolve, reject) => {
        const deadline = startedAt + sampleMs
        const onFrame = now => {
          if (document.hidden || lost) {
            cancelled = true
            reject(new Error('Visibility or WebGL context lost: sample invalid'))
            return
          }
          if (prev !== null && deltas.length < MAX_SAMPLE) {
            const dt = now - prev
            if (!Number.isFinite(dt) || dt <= 0 || dt > 1000) {
              reject(new Error('Non-monotonic or stalled animation frame'))
              return
            }
            deltas.push(round(dt))
          }
          prev = now
          if (deltas.length % 20 === 0) {
            lastState = window.__OSGARD_R135_QA || lastState
          }
          if (now < deadline && deltas.length < MAX_SAMPLE) requestAnimationFrame(onFrame)
          else resolve()
        }
        requestAnimationFrame(onFrame)
      })
      if (cancelled || deltas.length < 240 || lost) {
        throw new Error('Too few real visible frames or lost WebGL context')
      }
      const elapsedMs = performance.now() - startedAt
      const sorted = [...deltas].sort((a, b) => a - b)
      const result = {
        schema: SCHEMA,
        status: 'UNVERIFIED_PHONE_MEASUREMENT_DRAFT',
        game: 'OSGARD R135 Service Spine',
        source_commit: manifest.source_commit,
        version: manifest.version,
        engine: manifest.engine,
        capture_utc: new Date().toISOString(),
        platform_claim: /iPhone|iPad/.test(navigator.userAgent) ? 'ios'
          : /Android/.test(navigator.userAgent) ? 'android' : 'unknown',
        user_agent_trusted: false,
        physical_hardware_attested: false,
        reviewer_confirmed: false,
        no_synthetic_emulation_claim: false,
        orientation: innerWidth < innerHeight ? 'portrait' : 'landscape',
        viewport_width: lastState.viewport_w,
        viewport_height: lastState.viewport_h,
        quality: lastState.quality,
        loaded_model: String(lastState.loaded || '').split('/').pop(),
        scene_ready: Boolean(lastState.scene_ready),
        simulation_only: Boolean(lastState.simulation_only),
        cleared_case_count: lastState.cleared_case_count,
        safety_interlock_verified_by_human: false,
        WebGL_context_lost: lost,
        capture_ms: round(elapsedMs),
        frame_count: deltas.length,
        frames_ms: deltas,
        p50_frame_ms: quantile(sorted, 0.50),
        p95_frame_ms: quantile(sorted, 0.95),
        p99_frame_ms: quantile(sorted, 0.99),
        visual_review_approved: false,
        screen_recording_approved: false,
        uploads_sent: false
      }
      const blob = new Blob([JSON.stringify(result, null, 2) + '\n'],
        { type: 'application/json' })
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.download = 'osgard-w25-' + result.platform_claim + '-' + result.orientation
        + '-' + manifest.source_commit.slice(0, 8) + '.json'
      document.body.appendChild(link)
      link.click()
      link.remove()
      URL.revokeObjectURL(url)
      console.info('W25 UNVERIFIED draft only; original video and independent human review required', {
        p95: result.p95_frame_ms, sample: result.frame_count, sha: result.source_commit
      })
      return result
    } finally {
      canvas.removeEventListener('webglcontextlost', onLost)
      busy = false
    }
  }
  return Object.freeze({ run })
})()
