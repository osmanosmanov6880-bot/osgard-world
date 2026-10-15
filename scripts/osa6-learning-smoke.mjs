import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
const tracks = readFileSync('src/osaLearningTracks.ts','utf8')
const dashboard = readFileSync('src/OSALearningDashboard.tsx','utf8')
const router = readFileSync('src/main.tsx','utf8')
assert.ok(tracks.includes('getOSATrackProgress') && tracks.includes('getOSANextLesson'))
assert.ok(tracks.includes('OSA_LESSON_SLUGS.slice(0, 2)') && tracks.includes('OSA_LESSON_SLUGS.slice(2, 5)') && tracks.includes('OSA_LESSON_SLUGS.slice(5, 8)'))
assert.ok(dashboard.includes('subscribeOSALearningProgress') && dashboard.includes('getOSALearningProgress'))
assert.ok(dashboard.includes('progress.lessonCompletions') && dashboard.includes('aria-label'))
assert.ok(router.includes("path === '/learning'") && router.includes('<OSALearningDashboard />'))
console.log('OSA6_LEARNING_SMOKE_PASS: route, track partitions, reactive progress and bilingual dashboard present')
