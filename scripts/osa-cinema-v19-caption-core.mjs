/**
 * OSA Cinema V19 — offline WebVTT drafting and validation.
 * This module cannot transcribe speech, verify language or grant public media rights.
 */
const CLOCK = /^(?:(\d{2}):)?(\d{2}):(\d{2})\.(\d{3})$/
const TEXT_RESTRICTION = /[<>]|\u0000|-->/
export function parseTimestamp(input) {
  if (typeof input !== 'string') return null
  const found = input.trim().match(CLOCK)
  if (!found) return null
  const hour = Number(found[1] || 0), min = Number(found[2]), sec = Number(found[3])
  if (min >= 60 || sec >= 60) return null
  return hour * 3600 + min * 60 + sec + Number(found[4]) / 1000
}
export function formatTimestamp(seconds) {
  if (!Number.isFinite(seconds) || seconds < 0 || seconds > 359999) throw new Error('Invalid time')
  const total = Math.round(seconds * 1000)
  const hour = Math.floor(total / 3600000)
  const min = Math.floor((total % 3600000) / 60000)
  const sec = Math.floor((total % 60000) / 1000)
  const ms = total % 1000
  return [hour,min,sec].map(v=>String(v).padStart(2,'0')).join(':')+'.'+String(ms).padStart(3,'0')
}
export function validateCues(cues, durationSeconds) {
  if (!Array.isArray(cues) || !Number.isFinite(durationSeconds) || durationSeconds <= 0) return ['invalid_file_or_duration']
  const errors=[]
  if(cues.length>2000) errors.push('too_many_cues')
  let previousEnd = 0
  cues.forEach((cue,index) => {
    const start=cue?.start,end=cue?.end,text=cue?.text
    if(!Number.isFinite(start)||!Number.isFinite(end)||start<0||end<=start||end>durationSeconds+.02)errors.push('invalid_range_'+index)
    if(index>0 && Number.isFinite(start) && start<previousEnd-.001)errors.push('overlap_or_unsorted_'+index)
    if(typeof text!=='string'||!text.trim()||text.length>500||TEXT_RESTRICTION.test(text))errors.push('invalid_text_'+index)
    if(typeof text==='string'&&text.split('\n').length>3)errors.push('too_many_lines_'+index)
    if(Number.isFinite(end)) previousEnd=end
  })
  return errors
}
export function parseWebVtt(source, durationSeconds) {
  if(typeof source!=='string'||source.length>800000)throw new Error('Invalid WebVTT source length')
  const text=source.replace(/^\uFEFF/,'').replace(/\r\n?/g,'\n')
  const blocks=text.trim().split(/\n\s*\n/).filter(Boolean)
  if(!blocks.length||!/^WEBVTT(?:[ \t].*)?$/.test(blocks[0].split('\n')[0]))throw new Error('WEBVTT header required')
  const cues=[]
  for(const block of blocks.slice(1)){
    const lines=block.trim().split('\n')
    if(/^NOTE(?:\s|$)/.test(lines[0]))continue
    if(/^(STYLE|REGION)(?:\s|$)/.test(lines[0]))throw new Error('Styles or regions need separate editorial review')
    const pos=lines.findIndex(l=>l.includes('-->'))
    if(pos<0||pos>1)throw new Error('Cue timing is missing')
    const timing=lines[pos].match(/^(\d{2}:\d{2}:\d{2}\.\d{3}|\d{2}:\d{2}\.\d{3})[ \t]+-->[ \t]+(\d{2}:\d{2}:\d{2}\.\d{3}|\d{2}:\d{2}\.\d{3})$/)
    if(!timing)throw new Error('Invalid cue timing or unsupported cue settings')
    const start=parseTimestamp(timing[1]),end=parseTimestamp(timing[2])
    const value=lines.slice(pos+1).join('\n').trim()
    cues.push({start,end,text:value})
  }
  const errors=validateCues(cues,durationSeconds)
  if(errors.length)throw new Error('Invalid WebVTT cues: '+errors.join(', '))
  return cues
}
export function exportWebVtt(cues,durationSeconds) {
  const errors=validateCues(cues,durationSeconds)
  if(errors.length)throw new Error('Invalid captions: '+errors.join(', '))
  if(!cues.length)throw new Error('Cannot export empty caption draft')
  return 'WEBVTT\n\n'+cues.map(cue=>formatTimestamp(cue.start)+' --> '+formatTimestamp(cue.end)+'\n'+cue.text.trim()).join('\n\n')+'\n'
}
export function createPrivateCaptionReport({sourceId,sourceSha256,locale,cues,sourceBytesVerified=false,notes=''}) {
  if(typeof sourceId!=='string'||typeof sourceSha256!=='string'||!(/^[0-9a-f]{64}$/).test(sourceSha256)||!['ru','en'].includes(locale)) throw new Error('Unknown caption source')
  return {
    schemaVersion:1,sourceId,originalSha256:sourceSha256,locale,
    status:'DRAFT_REQUIRES_HUMAN_LISTENING_AND_RIGHTS_REVIEW',
    sourceBytesVerified:sourceBytesVerified===true,
    cues:cues.map(cue=>({start:cue.start,end:cue.end,text:cue.text})),
    notes: String(notes).slice(0,3000),
    transcriptMatchesAudibleSpeech:false,
    captionsEditoriallyApproved:false,
    rightsCleared:false,
    publicPlaybackApproved:false,
    releaseAuthorized:false
  }
}
