#!/usr/bin/env node
/**
 * W25 local launcher for authorized physical Android Chrome capture only.
 * No recording, network, device attestation or upload occurs automatically.
 * This wrapper avoids the obsolete W11 default source in the legacy command.
 */
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'
import { spawnSync } from 'node:child_process'

const SHA40 = /^[0-9a-f]{40}$/
const SHA64 = /^[0-9a-f]{64}$/
const fail = reason => { throw new Error('W25 physical evidence HOLD: ' + reason) }

export function pinnedRelease(selector, pin) {
  if (!selector || !pin || typeof selector !== 'object' || typeof pin !== 'object')
    fail('missing reviewed release selector/pin')
  if (!['w19','w20','w21','w22','w23','w24','w26','w27'].includes(selector.channel) ||
      selector.pin_file !== ('scripts/r135-' + selector.channel + '-release-pin.json'))
    fail('selector is not canonical reviewed channel')
  if (!Number.isSafeInteger(selector.promotion_gate_run_id) || selector.promotion_gate_run_id <= 0)
    fail('missing independent reviewed promotion gate')
  if (!SHA40.test(String(pin.source_commit || '')) ||
      !SHA64.test(String(pin.manifest_sha256 || '')) ||
      !SHA64.test(String(pin.archive_sha256 || '')) ||
      !/^r135-[a-z0-9-]+$/.test(String(pin.version || '')))
    fail('invalid immutable game source/checksums/version')
  if (pin.physical_phone_fps_verified !== false)
    fail('software pin must not preclaim physical hardware certification')
  return { channel: selector.channel, version: pin.version,
    source: pin.source_commit, manifest: pin.manifest_sha256,
    gate_run: selector.promotion_gate_run_id }
}

export function deviceCapturePlan(args, selector, pin) {
  const release = pinnedRelease(selector, pin)
  const val = (name, fallback = '') => {
    const i = args.indexOf(name)
    return i >= 0 && args[i + 1] ? args[i + 1] : fallback
  }
  const device = val('--platform')
  const mode = val('--mode').toUpperCase()
  const orientation = val('--orientation')
  const cdp = val('--cdp')
  const output = val('--out')
  const seconds = Number(val('--seconds', '60'))
  if (device !== 'android-chrome')
    fail('only authorized physical Android Chrome supports CDP; iPhone Safari needs separate Web Inspector/manual review')
  if (!['ECO','HERO'].includes(mode) || !['portrait','landscape'].includes(orientation))
    fail('real mode and orientation must be explicit')
  if (!args.includes('--physical-device-attested'))
    fail('emulated Chromium does not count as a physical phone')
  if (args.includes('--remote') || args.includes('--upload'))
    fail('remote device recording and uploads are prohibited')
  if (!Number.isFinite(seconds) || seconds < 60 || seconds > 300)
    fail('capture duration must be 60–300 seconds')
  if (!output.endsWith('.json') || output.length > 400)
    fail('local JSON output path is required')
  let url
  try { url = new URL(cdp) } catch { fail('invalid local CDP endpoint') }
  if (url.protocol !== 'http:' ||
      !['127.0.0.1','localhost','[::1]'].includes(url.hostname) ||
      url.username || url.password || !url.port)
    fail('CDP must be locally forwarded, never a remote debug socket')
  const command = [
    'scripts/r135-device-evidence.mjs', '--cdp', cdp,
    '--url', 'https://osgard.world/games/r135-service/',
    '--seconds', String(seconds), '--mode', mode, '--out', output,
    '--physical-device-attested',
    '--expect-version', release.version,
    '--expect-source', release.source,
    '--expect-manifest-sha256', release.manifest
  ]
  return { command, release, platform: device, orientation, mode,
    status: 'HOLD_REQUIRES_PHYSICAL_INDEPENDENT_REVIEW' }
}

function main() {
  const args = process.argv.slice(2)
  const active = JSON.parse(readFileSync('scripts/r135-active-release.json', 'utf8'))
  if (typeof active.pin_file !== 'string' ||
      !/^scripts\/r135-w[0-9]+-release-pin\.json$/.test(active.pin_file))
    fail('unsafe or floating active pin path')
  const pin = JSON.parse(readFileSync(active.pin_file, 'utf8'))
  const plan = deviceCapturePlan(args, active, pin)
  console.log(JSON.stringify({
    active_source: plan.release,
    expected_cell: [plan.platform,plan.orientation,plan.mode].join('/'),
    certification: 'HOLD_ACTUAL_PHONE_UNVERIFIED',
    note: 'User-Agent and self-attestation are not hardware proof. Review original PNG/JSON with r135-hardware-matrix.mjs.'
  }, null, 2))
  if (args.includes('--dry-run')) return
  const proc = spawnSync(process.execPath, plan.command,
    { cwd: process.cwd(), stdio: 'inherit', shell: false })
  if (proc.error) throw proc.error
  if (proc.status !== 0) process.exitCode = proc.status || 1
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href)
  main()
