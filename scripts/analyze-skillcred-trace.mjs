import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'
import { pathToFileURL } from 'node:url'

// Read saved capture data only. This script does not launch a browser or enforce
// the separate Lighthouse 100/100 acceptance gate.
// Lighthouse 12.8.2's simulated long-tasks audit prunes child tasks; its "other"
// bucket and simulated timestamps cannot identify a raw JavaScript call:
// https://github.com/GoogleChrome/lighthouse/blob/v12.8.2/core/audits/long-tasks.js
const TASK_NAMES = new Set([
  'RunTask', 'ThreadControllerImpl::RunTask', 'ThreadControllerImpl::DoWork',
  'TaskQueueManager::ProcessTaskFromWorkQueue',
])
const LIMITS = { inputBytes: 256 * 1024 * 1024, events: 1_000_000, samples: 1_000_000, tasks: 20, rows: 20, frames: 12 }
const isObject = value => value !== null && typeof value === 'object' && !Array.isArray(value)
const finite = value => typeof value === 'number' && Number.isFinite(value)
const text = (value, max = 500) => typeof value === 'string' ? value.slice(0, max) : null
const ms = microseconds => Math.round(microseconds) / 1000
const frameOf = event => event.args?.frame ?? event.args?.data?.frame ?? event.args?.data?.frameId
const check = (condition, message) => { if (!condition) throw new Error(message) }
const hash = bytes => createHash('sha256').update(bytes).digest('hex')
const pick = (value, keys) => Object.fromEntries(keys.filter(key => finite(value?.[key]) || typeof value?.[key] === 'boolean').map(key => [key, value[key]]))

function normalizeUrl(value) {
  try { const url = new URL(value); url.hash = ''; return url.href } catch { return null }
}

function callFrame(value) {
  if (!isObject(value)) return null
  const result = {
    functionName: text(value.functionName), url: text(value.url, 1200),
    scriptId: typeof value.scriptId === 'string' || finite(value.scriptId) ? String(value.scriptId).slice(0, 100) : null,
    lineNumber: finite(value.lineNumber) ? value.lineNumber : null,
    columnNumber: finite(value.columnNumber) ? value.columnNumber : null,
  }
  return Object.values(result).some(value => value !== null) ? result : null
}

function sourceEvidence(event) {
  const data = { ...(event.args?.beginData || {}), ...(event.args?.data || {}) }
  const stack = data.stackTrace ?? event.args?.stackTrace
  const frames = Array.isArray(stack) ? stack : stack?.callFrames
  return {
    direct: callFrame(data),
    stack: Array.isArray(frames) ? frames.slice(0, LIMITS.frames).map(callFrame).filter(Boolean) : [],
  }
}

function selectCapture(report, events) {
  const metrics = report.audits?.metrics?.details?.items?.[0]
  check(isObject(metrics), 'Lighthouse report is missing its metrics item')
  const navigationTs = metrics.observedNavigationStartTs
  const originTs = metrics.observedTimeOriginTs ?? navigationTs
  check(finite(navigationTs) && finite(originTs), 'Report is missing exact observed navigation/time-origin timestamps')
  const expectedUrl = normalizeUrl(report.mainDocumentUrl ?? report.finalDisplayedUrl ?? report.finalUrl)
  check(expectedUrl && expectedUrl.length <= 4096, 'Report is missing a valid bounded final main-document URL')

  const roots = new Set()
  for (const event of events) {
    if (event.name === 'TracingStartedInBrowser') {
      for (const frame of Array.isArray(event.args?.data?.frames) ? event.args.data.frames : []) {
        if (typeof frame.frame === 'string' && !frame.parent) roots.add(frame.frame)
      }
    }
    if (event.name === 'FrameCommittedInBrowser' && !event.args?.data?.parent && typeof frameOf(event) === 'string') roots.add(frameOf(event))
  }
  const candidates = events.filter(event => {
    if (event.name !== 'navigationStart' || !finite(event.ts) || Math.abs(event.ts - navigationTs) > 1) return false
    const data = event.args?.data || {}
    const frameId = frameOf(event)
    const root = roots.has(frameId) || data.isOutermostMainFrame === true
    return typeof frameId === 'string' && root && data.isOutermostMainFrame !== false &&
      normalizeUrl(data.documentLoaderURL) === expectedUrl
  })
  check(candidates.length === 1, `Expected one real main-frame navigation matching the report; found ${candidates.length}`)
  const navigation = candidates[0]
  check(finite(navigation.pid) && finite(navigation.tid), 'Main-frame navigation is missing numeric process/thread identifiers')
  const frameId = frameOf(navigation)
  const thread = events.find(event => event.name === 'thread_name' && event.ph === 'M' &&
    event.pid === navigation.pid && event.tid === navigation.tid && event.args?.name === 'CrRendererMain')
  check(thread, 'Matching main-frame navigation has no identified CrRendererMain thread')
  const threadEvents = events.filter(event => event.pid === thread.pid && event.tid === thread.tid)
  const realOrigin = threadEvents.some(event => finite(event.ts) && Math.abs(event.ts - originTs) <= 1 &&
    (event.name === 'navigationStart' || (event.name === 'ResourceSendRequest' && frameOf(event) === frameId)))
  check(realOrigin, 'Report time origin does not match a real navigation or main-frame request event')
  const rawEnd = events.reduce((end, event) => finite(event.ts) ? Math.max(end, event.ts + (finite(event.dur) ? event.dur : 0)) : end, originTs)
  const endTs = metrics.observedTraceEndTs
  check(finite(endTs) && endTs > originTs && endTs <= rawEnd + 1, 'Report is missing a matching observed trace end')
  const laterNavigation = events.find(event => event.name === 'navigationStart' && frameOf(event) === frameId &&
    finite(event.ts) && event.ts > navigation.ts + 1 && event.ts < endTs && event.args?.data?.documentLoaderURL)
  check(!laterNavigation, 'Another main-frame navigation occurs inside the report window; refusing mixed capture attribution')
  const switchedProcess = events.find(event => event.name === 'FrameCommittedInBrowser' && frameOf(event) === frameId &&
    finite(event.ts) && event.ts >= navigation.ts && event.ts < endTs &&
    finite(event.args?.data?.processId) && event.args.data.processId !== thread.pid)
  check(!switchedProcess, 'Main frame changes renderer process inside the capture; this analyzer requires a single identified main thread')
  return { metrics, navigation, originTs, endTs, frameId, thread, threadEvents, expectedUrl }
}

function buildIntervals(events, originTs, endTs, quality) {
  const intervals = []
  const open = []
  const sorted = events.map((event, index) => ({ event, index })).filter(({ event }) => finite(event.ts))
    .sort((a, b) => a.event.ts - b.event.ts || a.index - b.index)
  function add(event, end, index) {
    if (!finite(end) || end < event.ts) { quality.invalidDurationCount++; return }
    if (end <= originTs || event.ts >= endTs || end === event.ts) return
    intervals.push({ event, index, start: event.ts, end, parent: null, children: [], ambiguous: false })
  }
  for (const { event, index } of sorted) {
    if (event.ph === 'X') {
      if (!finite(event.dur)) quality.invalidDurationCount++
      else add(event, event.ts + event.dur, index)
    } else if (event.ph === 'B') open.push({ event, index })
    else if (event.ph === 'E') {
      const begin = open.pop()
      if (!begin) { quality.unmatchedEndCount++; continue }
      if (event.name && event.name !== begin.event.name) { quality.mismatchedPairCount++; continue }
      add(begin.event, event.ts, begin.index)
    }
  }
  quality.unmatchedBeginCount = open.length
  intervals.sort((a, b) => a.start - b.start || b.end - a.end ||
    Number(TASK_NAMES.has(b.event.name)) - Number(TASK_NAMES.has(a.event.name)) || a.index - b.index)
  const parents = []
  for (const node of intervals) {
    while (parents.length && parents.at(-1).end <= node.start) parents.pop()
    while (parents.length && node.end > parents.at(-1).end) {
      quality.crossingIntervalCount++
      node.ambiguous = true
      for (const parent of parents) parent.ambiguous = true
      parents.pop()
    }
    node.parent = parents.at(-1) || null
    node.parent?.children.push(node)
    parents.push(node)
  }
  // Children are ordered by start. Use their union so even malformed crossing
  // spans cannot produce negative self time; mark affected self times unknown.
  for (const node of intervals.slice().reverse()) {
    let covered = 0, lastEnd = node.start
    for (const child of node.children) {
      covered += Math.max(0, child.end - Math.max(lastEnd, child.start))
      lastEnd = Math.max(lastEnd, child.end)
      node.ambiguous ||= child.ambiguous
    }
    node.self = node.ambiguous ? null : Math.max(0, node.end - node.start - covered)
  }
  return intervals
}

function profileKey(event) {
  const id = event.id ?? event.id2?.local ?? event.id2?.global
  return typeof id === 'string' || finite(id) ? `${event.pid}:${String(id).slice(0, 100)}` : null
}

function parseProfiles(events, capture, quality) {
  const groups = new Map()
  let otherThreadEventCount = 0
  for (const event of events) {
    if (event.name !== 'Profile' && event.name !== 'ProfileChunk') continue
    if (event.pid !== capture.thread.pid) { otherThreadEventCount++; continue }
    const key = profileKey(event)
    if (!key) { quality.profileEventsWithoutId++; continue }
    if (!groups.has(key)) groups.set(key, [])
    groups.get(key).push(event)
  }
  const samples = [], profiles = []
  let allSampleCount = 0
  for (const [key, chunks] of groups) {
    chunks.sort((a, b) => a.ts - b.ts)
    // Chrome emits chunks on a different thread. Match process + profile ID;
    // take thread ownership and trace-clock origin from the Profile header.
    // https://github.com/ChromeDevTools/devtools-frontend/blob/main/front_end/models/trace/handlers/SamplesHandler.ts
    const heads = chunks.filter(event => event.name === 'Profile')
    if (heads.length !== 1) { quality.missingOrAmbiguousProfileHeaderCount++; continue }
    const head = heads[0]
    if (head.tid !== capture.thread.tid) { otherThreadEventCount += chunks.length; continue }
    const start = finite(head.ts) ? head.ts : null
    const nodes = new Map(), parents = new Map()
    let ambiguousNodes = false
    for (const event of chunks) {
      const cpu = event.args?.data?.cpuProfile
      for (const node of Array.isArray(cpu?.nodes) ? cpu.nodes : []) {
        if (!isObject(node) || !finite(node.id)) { quality.invalidProfileNodeCount++; ambiguousNodes = true; continue }
        const previous = nodes.get(node.id)
        if (previous && JSON.stringify(previous.callFrame) !== JSON.stringify(node.callFrame)) { quality.conflictingProfileNodeCount++; ambiguousNodes = true }
        const children = Array.isArray(node.children) ? node.children : []
        nodes.set(node.id, { ...previous, ...node, children: [...new Set([...(previous?.children || []), ...children])] })
      }
    }
    function parentOf(childId, parentId) {
      if (parents.has(childId) && parents.get(childId) !== parentId) { quality.conflictingProfileParentCount++; ambiguousNodes = true }
      else parents.set(childId, parentId)
    }
    for (const node of nodes.values()) {
      // Tracing profiles commonly use parent pointers; CDP profiles can use children.
      if (finite(node.parent)) parentOf(node.id, node.parent)
      for (const childId of node.children) if (finite(childId)) parentOf(childId, node.id)
    }
    let cursor = start, sampleCount = 0, windowSampleCount = 0
    for (const event of chunks) {
      if (event.name !== 'ProfileChunk') continue
      const data = event.args?.data || {}, ids = data.cpuProfile?.samples || [], deltas = data.timeDeltas ?? data.cpuProfile?.timeDeltas
      if (!Array.isArray(ids)) { quality.invalidProfileChunkCount++; continue }
      sampleCount += ids.length
      allSampleCount += ids.length
      check(allSampleCount <= LIMITS.samples, 'CPU profile exceeds the bounded sample limit')
      if (!ids.length) continue
      if (!finite(cursor) || !Array.isArray(deltas) || deltas.length !== ids.length || !deltas.every(finite)) {
        quality.unplaceableProfileSamples += ids.length
        cursor = null // Later deltas cannot repair a missing prefix of the clock.
        continue
      }
      for (let i = 0; i < ids.length; i++) {
        if (deltas[i] < 0) quality.negativeProfileDeltaCount++
        cursor += deltas[i]
        if (cursor < capture.originTs || cursor > capture.endTs) continue
        windowSampleCount++
        const frames = [], visited = new Set()
        let id = ids[i], complete = false
        while (id !== undefined && !visited.has(id) && visited.size < 128) {
          visited.add(id)
          const node = nodes.get(id)
          if (!node) break
          const frame = callFrame(node.callFrame)
          if (frame) frames.push(frame)
          const parent = parents.get(id)
          if (parent === undefined) { complete = node.callFrame?.functionName === '(root)'; break }
          id = parent
        }
        if (visited.has(id) && parents.has(id)) quality.cyclicOrTruncatedProfileStackCount++
        samples.push({ ts: cursor, profile: key, frames, complete: complete && !ambiguousNodes })
      }
    }
    profiles.push({
      id: key, ownerTid: head.tid, startTimestampUs: start,
      headerMonotonicStartTimeUs: finite(head.args?.data?.startTime) ? head.args.data.startTime : null,
      nodeCount: nodes.size, sampleCount, sampleCountInCaptureWindow: windowSampleCount,
    })
  }
  samples.sort((a, b) => a.ts - b.ts)
  return { samples, profiles, otherThreadEventCount, allSampleCount }
}

function sampleSummary(samples, limit = LIMITS.rows) {
  const functions = new Map()
  let completeStacks = 0, resolvedLeaves = 0
  for (const sample of samples) {
    if (sample.complete) completeStacks++
    if (sample.frames.length) resolvedLeaves++
    const seen = new Set()
    for (const [index, frame] of sample.frames.entries()) {
      const key = JSON.stringify(frame)
      if (!functions.has(key)) functions.set(key, { ...frame, selfSamples: 0, inclusiveSamples: 0 })
      const row = functions.get(key)
      if (index === 0) row.selfSamples++
      if (!seen.has(key)) row.inclusiveSamples++
      seen.add(key)
    }
  }
  return {
    sampleCount: samples.length, resolvedLeafSampleCount: resolvedLeaves, completeStackSampleCount: completeStacks,
    functionCount: functions.size,
    functions: [...functions.values()].sort((a, b) => b.selfSamples - a.selfSamples || b.inclusiveSamples - a.inclusiveSamples).slice(0, limit),
  }
}

function summarizeTask(root, capture, samples) {
  const descendants = [], pending = [root]
  while (pending.length) { const node = pending.pop(); descendants.push(node); for (const child of node.children) pending.push(child) }
  const groups = new Map()
  for (const node of descendants) {
    const name = text(node.event.name) || '(unnamed)'
    if (!groups.has(name)) groups.set(name, { name, count: 0, inclusiveMs: 0, selfMs: 0, ambiguousSelfTime: false })
    const group = groups.get(name)
    group.count++
    group.inclusiveMs += (node.end - node.start) / 1000
    if (node.self === null) group.ambiguousSelfTime = true
    else group.selfMs += node.self / 1000
  }
  const taskSamples = samples.filter(sample => sample.ts >= root.start && sample.ts < root.end)
  const nested = descendants.filter(node => node !== root).sort((a, b) => (b.end - b.start) - (a.end - a.start))
  return {
    name: root.event.name, startTimestampUs: root.start, endTimestampUs: root.end,
    startMsFromObservedOrigin: ms(root.start - capture.originTs), durationMs: ms(root.end - root.start),
    overlapWithCaptureWindowMs: ms(Math.max(0, Math.min(root.end, capture.endTs) - Math.max(root.start, capture.originTs))),
    selfTimeMs: root.self === null ? null : ms(root.self), selfTimeReliable: !root.ambiguous,
    synchronousEventCount: descendants.length,
    activityByEventName: [...groups.values()].map(group => ({ ...group, inclusiveMs: ms(group.inclusiveMs * 1000), selfMs: group.ambiguousSelfTime ? null : ms(group.selfMs * 1000) }))
      .sort((a, b) => (b.selfMs ?? -1) - (a.selfMs ?? -1) || b.inclusiveMs - a.inclusiveMs).slice(0, LIMITS.rows),
    longestNestedEvents: nested.slice(0, LIMITS.rows).map(node => ({
      name: text(node.event.name), category: text(node.event.cat), startMsFromObservedOrigin: ms(node.start - capture.originTs),
      durationMs: ms(node.end - node.start), selfTimeMs: node.self === null ? null : ms(node.self),
      parentEventName: text(node.parent?.event.name), source: sourceEvidence(node.event),
    })),
    timelineStackEvidence: descendants.filter(node => { const source = sourceEvidence(node.event); return source.direct || source.stack.length })
      .sort((a, b) => (b.end - b.start) - (a.end - a.start)).slice(0, LIMITS.rows)
      .map(node => ({ name: text(node.event.name), startMsFromObservedOrigin: ms(node.start - capture.originTs), durationMs: ms(node.end - node.start), ...sourceEvidence(node.event) })),
    v8Samples: {
      ...sampleSummary(taskSamples, 10),
      stackExamples: taskSamples.filter(sample => sample.frames.some(frame => frame.url)).slice(0, 4)
        .map(sample => ({ atMsFromObservedOrigin: ms(sample.ts - capture.originTs), completeStack: sample.complete, leafToRoot: sample.frames.slice(0, LIMITS.frames) })),
    },
  }
}

export function analyzeSkillCredTrace(report, trace, inputMetadata = {}) {
  check(isObject(report) && !report.runtimeError, 'Expected a completed Lighthouse report without a runtime error')
  check(report.lighthouseVersion === '12.8.2', 'This analyzer expects the pinned Lighthouse 12.8.2 report')
  const events = Array.isArray(trace) ? trace : trace?.traceEvents
  check(Array.isArray(events) && events.length > 0 && events.length <= LIMITS.events, 'Expected a nonempty traceEvents array within the event limit')
  check(events.every(isObject), 'Trace contains a malformed event')
  const capture = selectCapture(report, events)
  const quality = {
    invalidDurationCount: 0, unmatchedBeginCount: 0, unmatchedEndCount: 0, mismatchedPairCount: 0, crossingIntervalCount: 0,
    profileEventsWithoutId: 0, invalidProfileNodeCount: 0, conflictingProfileNodeCount: 0, conflictingProfileParentCount: 0,
    invalidProfileChunkCount: 0, unplaceableProfileSamples: 0, negativeProfileDeltaCount: 0, cyclicOrTruncatedProfileStackCount: 0,
    missingOrAmbiguousProfileHeaderCount: 0,
  }
  const intervals = buildIntervals(capture.threadEvents, capture.originTs, capture.endTs, quality)
  const tasks = intervals.filter(node => {
    if (!TASK_NAMES.has(node.event.name)) return false
    for (let parent = node.parent; parent; parent = parent.parent) if (TASK_NAMES.has(parent.event.name)) return false
    return true
  }).sort((a, b) => (b.end - b.start) - (a.end - a.start))
  check(tasks.length > 0, 'Identified main frame/thread has no complete top-level RunTask events in the capture window')
  const profile = parseProfiles(events, capture, quality)
  const gaps = []
  if (!profile.profiles.length) gaps.push('No V8 Profile/ProfileChunk stream was captured for the identified main thread.')
  if (!profile.samples.length) gaps.push('No V8 sample has a usable timestamp inside this navigation; absence is not evidence of no JavaScript execution.')
  if (profile.samples.some(sample => !sample.complete)) gaps.push('Some V8 samples have an incomplete or unresolved call stack.')
  if (quality.unplaceableProfileSamples) gaps.push('Some profile sample timestamps cannot be reconstructed; they are excluded from task attribution.')
  if (quality.crossingIntervalCount) gaps.push('Synchronous trace spans cross; affected nested self times are reported as null, without repairing raw durations.')
  if (quality.unmatchedBeginCount || quality.unmatchedEndCount || quality.mismatchedPairCount || quality.invalidDurationCount) gaps.push('Some synchronous events were incomplete or malformed and could not become timed spans.')
  if (quality.conflictingProfileNodeCount || quality.conflictingProfileParentCount || quality.invalidProfileNodeCount || quality.cyclicOrTruncatedProfileStackCount) gaps.push('Profile nodes contain attribution ambiguities; inspect the retained raw profile before drawing a function-level conclusion.')
  if (quality.missingOrAmbiguousProfileHeaderCount) gaps.push('Some profile chunks lack a unique owner header and are excluded from main-thread attribution.')
  if (quality.negativeProfileDeltaCount) gaps.push('Some V8 sample deltas are negative; timestamps are retained and sorted, without inferring CPU milliseconds.')
  const observed = {}
  const observedNames = ['TimeOrigin', 'NavigationStart', 'FirstPaint', 'FirstContentfulPaint', 'FirstContentfulPaintAllFrames',
    'LargestContentfulPaint', 'LargestContentfulPaintAllFrames', 'TraceEnd', 'Load', 'DomContentLoaded',
    'CumulativeLayoutShift', 'CumulativeLayoutShiftMainFrame', 'FirstVisualChange', 'LastVisualChange', 'SpeedIndex']
  for (const name of observedNames) for (const suffix of ['', 'Ts']) {
    const key = `observed${name}${suffix}`
    if (finite(capture.metrics[key])) observed[key] = capture.metrics[key]
  }
  const exact = {}
  for (const [key, value] of Object.entries(observed)) if (key.endsWith('Ts')) exact[key.slice(0, -2) + 'MsFromOrigin'] = ms(value - capture.originTs)
  const metricIds = ['first-contentful-paint', 'largest-contentful-paint', 'speed-index', 'total-blocking-time', 'interactive', 'cumulative-layout-shift']
  const auditMetrics = Object.fromEntries(metricIds.map(id => [id, { value: finite(report.audits?.[id]?.numericValue) ? report.audits[id].numericValue : null, unit: text(report.audits?.[id]?.numericUnit, 30) }]))
  const simulated = report.configSettings?.throttlingMethod === 'simulate'
  const reportTasks = report.audits?.['long-tasks']?.details?.items || []
  return {
    schemaVersion: 1,
    purpose: 'Saved-capture diagnosis only; success is not Lighthouse 100/100 acceptance or a causal performance finding.',
    inputs: inputMetadata,
    capture: {
      lighthouseVersion: report.lighthouseVersion, fetchTime: text(report.fetchTime), requestedUrl: text(report.requestedUrl, 1200), mainDocumentUrl: capture.expectedUrl,
      hostUserAgent: text(report.environment?.hostUserAgent, 1000), emulatedNetworkUserAgent: text(report.environment?.networkUserAgent, 1000),
      benchmarkIndex: finite(report.environment?.benchmarkIndex) ? report.environment.benchmarkIndex : null,
      formFactor: report.configSettings?.formFactor ?? null, throttlingMethod: report.configSettings?.throttlingMethod ?? null,
      throttling: pick(report.configSettings?.throttling, ['rttMs', 'throughputKbps', 'requestLatencyMs', 'downloadThroughputKbps', 'uploadThroughputKbps', 'cpuSlowdownMultiplier']),
      screenEmulation: pick(report.configSettings?.screenEmulation, ['mobile', 'width', 'height', 'deviceScaleFactor', 'disabled']),
      additionalTraceCategories: Array.isArray(report.configSettings?.additionalTraceCategories) ? report.configSettings.additionalTraceCategories.slice(0, 30).map(value => text(value)) : text(report.configSettings?.additionalTraceCategories),
      traceEventCount: events.length, mainThreadEventCount: capture.threadEvents.length,
      frameId: text(capture.frameId), pid: capture.thread.pid, tid: capture.thread.tid, threadName: 'CrRendererMain',
      navigationStartTimestampUs: capture.navigation.ts, observedOriginTimestampUs: capture.originTs, observedEndTimestampUs: capture.endTs,
      identityEvidence: 'Exact report navigation timestamp, trace main-frame identity and URL, and matching CrRendererMain metadata.',
      runWarnings: (Array.isArray(report.runWarnings) ? report.runWarnings : []).slice(0, 20).map(value => text(value)),
    },
    reportMetrics: {
      categoryScores: Object.fromEntries(Object.entries(report.categories || {}).slice(0, 10).map(([key, value]) => [key, finite(value?.score) ? value.score : null])),
      auditMetricClock: simulated ? 'Lighthouse simulation; not the raw trace clock.' : 'Reported Lighthouse audit metric clock; see throttling method.',
      ...(simulated ? { modeled: auditMetrics } : { reportedAuditMetrics: auditMetrics }),
      observed: { reportValues: observed, exactMillisecondsFromObservedOrigin: exact },
      longTaskDiagnosticClock: simulated ? 'Simulated start and duration; never matched to raw task timestamps by numeric proximity.' : 'Reported audit task timings.',
      reportedLongTasks: (Array.isArray(reportTasks) ? reportTasks : []).slice(0, LIMITS.tasks).map(item => ({ url: text(item?.url, 1200), startTimeMs: finite(item?.startTime) ? item.startTime : null, durationMs: finite(item?.duration) ? item.duration : null })),
    },
    rawMainThread: {
      clock: 'Chrome monotonic microsecond timestamps, converted to milliseconds relative to the verified observed origin.',
      scope: 'Complete synchronous tasks overlapping this navigation window; full raw task durations can include a portion before the origin.',
      topLevelTaskCount: tasks.length, rawTaskCountAtLeast50Ms: tasks.filter(node => node.end - node.start >= 50_000).length,
      displayedTaskCount: Math.min(tasks.length, LIMITS.tasks),
      topTasks: tasks.slice(0, LIMITS.tasks).map(node => summarizeTask(node, capture, profile.samples)),
    },
    v8: {
      status: profile.samples.length ? 'samples-captured' : 'no-usable-samples',
      profileCount: profile.profiles.length, profiles: profile.profiles.slice(0, LIMITS.rows), otherThreadProfileEventCount: profile.otherThreadEventCount,
      totalMainThreadProfileSamples: profile.allSampleCount, ...sampleSummary(profile.samples),
      sourcePositions: 'V8 call-frame line/column numbers are zero based; timeline event positions are retained as emitted.',
    },
    quality, attributionGaps: gaps,
    interpretation: [
      'Raw tasks, observed paint timestamps and Lighthouse modeled metrics use different clocks and are reported separately.',
      'Inclusive event totals may count nested work more than once; reliable self times partition the synchronous event tree.',
      'A timeline script URL or triggering stack is evidence of association, not proof that the whole task executed JavaScript from that URL.',
      'V8 selfSamples/inclusiveSamples are sample counts, not measured CPU milliseconds; profiling can affect the capture. Sample times use the Profile event trace clock, not an untranslated header clock.',
      'Lighthouse 12.8.2 simulated task pruning can assign child time to the top-level Other bucket; inspect real child events and sample stacks.',
    ],
    outputLimits: LIMITS,
  }
}

function selfTest() {
  const origin = 1_000_000, url = 'https://osgard.world/skillcred/', script = `${url}app.js`
  const event = (name, ts, extra = {}) => ({ name, ts, pid: 11, tid: 12, cat: 'devtools.timeline', ph: 'X', args: {}, ...extra })
  const report = {
    lighthouseVersion: '12.8.2', mainDocumentUrl: url, configSettings: { throttlingMethod: 'simulate' },
    audits: {
      metrics: { details: { items: [{ observedNavigationStartTs: origin, observedTimeOriginTs: origin, observedTraceEndTs: 1_500_000, observedFirstContentfulPaintTs: 1_150_000 }] } },
      'long-tasks': { details: { items: [{ url: script, startTime: 1785, duration: 444 }] } },
    },
  }
  const trace = { traceEvents: [
    event('TracingStartedInBrowser', 900_000, { ph: 'I', args: { data: { frames: [{ frame: 'main', processId: 11 }, { frame: 'child', parent: 'main', processId: 22 }] } } }),
    event('thread_name', 0, { ph: 'M', cat: '__metadata', args: { name: 'CrRendererMain' } }),
    event('thread_name', 0, { pid: 22, tid: 23, ph: 'M', cat: '__metadata', args: { name: 'CrRendererMain' } }),
    event('navigationStart', origin, { ph: 'R', args: { frame: 'main', data: { documentLoaderURL: url, isOutermostMainFrame: true } } }),
    event('RunTask', 1_010_000, { dur: 100_000 }),
    event('EvaluateScript', 1_020_000, { dur: 50_000, args: { data: { url: script, lineNumber: 0 } } }),
    event('FunctionCall', 1_030_000, { dur: 20_000, args: { data: { functionName: 'render', url: script, lineNumber: 9, stackTrace: [{ functionName: 'boot', url: script, lineNumber: 1 }] } } }),
    event('Layout', 1_040_000, { ph: 'B' }), event('Layout', 1_045_000, { ph: 'E' }),
    event('RunTask', 1_300_000, { dur: 25_000 }),
    event('RunTask', 1_020_000, { pid: 22, tid: 23, dur: 300_000 }),
    event('firstContentfulPaint', 1_150_000, { ph: 'R', args: { frame: 'main' } }),
    event('trace-end', 1_500_000, { ph: 'I' }),
    event('Profile', origin, { ph: 'P', id: '0x1', args: { data: { startTime: origin } } }),
    event('ProfileChunk', 1_450_000, { ph: 'P', id: '0x1', args: { data: { timeDeltas: [20_000, 15_000, 5_000], cpuProfile: {
      nodes: [{ id: 1, callFrame: { functionName: '(root)' }, children: [2] }, { id: 2, callFrame: { functionName: 'boot', url: script }, children: [3] }, { id: 3, callFrame: { functionName: 'render', url: script, lineNumber: 9 } }], samples: [2, 3, 3],
    } } } }),
  ] }
  const result = analyzeSkillCredTrace(report, trace)
  assert.equal(result.rawMainThread.topLevelTaskCount, 2, 'Another renderer must not enter the selected main-frame tasks')
  const task = result.rawMainThread.topTasks[0]
  assert.equal(task.durationMs, 100)
  assert.equal(task.selfTimeMs, 50)
  const byName = Object.fromEntries(task.activityByEventName.map(row => [row.name, row]))
  assert.equal(byName.EvaluateScript.selfMs, 30)
  assert.equal(byName.FunctionCall.selfMs, 15)
  assert.equal(byName.Layout.selfMs, 5)
  assert.equal(task.activityByEventName.reduce((sum, row) => sum + row.selfMs, 0), 100)
  assert.equal(task.startMsFromObservedOrigin, 10, 'A modeled 1785ms timestamp must not select or shift a raw event')
  assert.equal(result.reportMetrics.reportedLongTasks[0].durationMs, 444)
  assert.equal(result.v8.sampleCount, 3)
  assert.equal(result.v8.completeStackSampleCount, 3)
  assert.equal(result.v8.functions.find(row => row.functionName === 'render').selfSamples, 2)
  assert.equal(task.v8Samples.sampleCount, 3)
  assert.equal(result.quality.cyclicOrTruncatedProfileStackCount, 0)
  const tracingProfile = structuredClone(trace)
  tracingProfile.traceEvents.find(item => item.name === 'Profile').args.data.startTime = 900_000
  const chunk = tracingProfile.traceEvents.find(item => item.name === 'ProfileChunk')
  chunk.tid = 99 // Chunk collector is not the profiled CrRendererMain thread.
  chunk.args.data.cpuProfile.nodes = [
    { id: 1, callFrame: { functionName: '(root)', scriptId: 0 } },
    { id: 2, parent: 1, callFrame: { functionName: 'boot', url: script, scriptId: 7 } },
    { id: 3, parent: 2, callFrame: { functionName: 'render', url: script, scriptId: 7, lineNumber: 9 } },
  ]
  tracingProfile.traceEvents.push(event('Profile', origin, { tid: 99, ph: 'P', id: '0x2', args: { data: { startTime: origin } } }))
  tracingProfile.traceEvents.push(event('ProfileChunk', 1_450_000, { ph: 'P', id: '0x2', args: { data: chunk.args.data } }))
  const traced = analyzeSkillCredTrace(report, tracingProfile)
  assert.equal(traced.v8.sampleCount, 3, 'Profile header, not chunk emitting thread, identifies ownership')
  assert.equal(traced.v8.completeStackSampleCount, 3, 'Trace parent pointers must reconstruct actual V8 stacks')
  assert.equal(traced.v8.profiles[0].startTimestampUs, origin, 'Profile event timestamp is in the trace clock domain')
  assert.equal(traced.v8.profiles[0].headerMonotonicStartTimeUs, 900_000)
  assert.equal(traced.rawMainThread.topTasks[0].v8Samples.stackExamples[0].atMsFromObservedOrigin, 20)
  assert.equal(traced.v8.otherThreadProfileEventCount, 2)
  const noProfile = analyzeSkillCredTrace(report, { traceEvents: trace.traceEvents.filter(item => !item.name.startsWith('Profile')) })
  assert.equal(noProfile.v8.status, 'no-usable-samples')
  assert.ok(noProfile.attributionGaps.some(item => item.includes('not evidence of no JavaScript')))
  assert.throws(() => analyzeSkillCredTrace(report, { traceEvents: trace.traceEvents.filter(item => !(item.name === 'thread_name' && item.pid === 11)) }), /CrRendererMain/)
  const wrongReport = structuredClone(report)
  wrongReport.audits.metrics.details.items[0].observedNavigationStartTs += 1_000
  assert.throws(() => analyzeSkillCredTrace(wrongReport, trace), /real main-frame navigation/)
  assert.throws(() => analyzeSkillCredTrace(report, { traceEvents: trace.traceEvents.filter(item => item.name !== 'RunTask') }), /top-level RunTask/)
  const crossed = structuredClone(trace)
  crossed.traceEvents.push(event('CrossingWork', 1_060_000, { dur: 30_000 }))
  const crossedResult = analyzeSkillCredTrace(report, crossed)
  assert.equal(crossedResult.rawMainThread.topTasks[0].selfTimeMs, null)
  assert.ok(crossedResult.quality.crossingIntervalCount > 0)
  console.log('SkillCred trace analyzer: synthetic nesting, main-frame identity, sampled stacks, modeled-clock separation and refusal cases passed.')
}

function readInput(file) {
  const stat = fs.statSync(file)
  check(stat.isFile() && stat.size > 0 && stat.size <= LIMITS.inputBytes, 'Input must be a nonempty regular JSON file within the size limit')
  const bytes = fs.readFileSync(file)
  return { value: JSON.parse(bytes.toString('utf8')), metadata: { file: path.basename(file), bytes: bytes.length, sha256: hash(bytes) } }
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  try {
    const args = process.argv.slice(2)
    if (args.length === 1 && args[0] === '--self-test') selfTest()
    else {
      check(args.length === 2 || args.length === 3, 'Usage: node scripts/analyze-skillcred-trace.mjs REPORT.json TRACE.json [OUTPUT.json], or --self-test')
      if (args[2]) {
        const output = path.resolve(args[2])
        if (fs.existsSync(output)) check(fs.lstatSync(output).isFile(), 'Output must be a regular file, not a symlink or directory')
        const realOutput = path.join(fs.realpathSync(path.dirname(output)), path.basename(output))
        check(!args.slice(0, 2).some(input => fs.realpathSync(input) === realOutput), 'Output must not overwrite either capture input')
      }
      const report = readInput(args[0]), trace = readInput(args[1])
      const analysis = analyzeSkillCredTrace(report.value, trace.value, { report: report.metadata, trace: trace.metadata })
      const json = JSON.stringify(analysis, null, 2) + '\n'
      if (args[2]) fs.writeFileSync(args[2], json)
      else process.stdout.write(json)
    }
  } catch (error) {
    console.error(`SkillCred trace analysis failed: ${error.message}`)
    process.exitCode = 1
  }
}
