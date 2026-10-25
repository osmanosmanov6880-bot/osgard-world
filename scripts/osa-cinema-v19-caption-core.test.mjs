import {test} from 'node:test'
import assert from 'node:assert/strict'
import {parseTimestamp,formatTimestamp,validateCues,parseWebVtt,exportWebVtt,createPrivateCaptionReport} from './osa-cinema-v19-caption-core.mjs'

test('Timestamp roundtrip on real 239s and 45s private picture',()=>{
 for(const t of [0,1.234,5,23.833,79,157,238.999]){
  assert.ok(Math.abs(parseTimestamp(formatTimestamp(t))-t)<.00051)
 }
 assert.equal(parseTimestamp('01:19.000'),79)
 assert.equal(parseTimestamp('00:01:19.000'),79)
 for(const invalid of ['1:19','00:61.000','00:00:99.000','-00:05.000','test',undefined]){
  assert.equal(parseTimestamp(invalid),null)
 }
})
test('Genuine two-cue Russian draft imports, edits and exports losslessly',()=>{
 const draft='WEBVTT\n\n00:00:05.000 --> 00:00:07.000\nПервый пробный текст\n\n00:01:19.000 --> 00:01:22.000\nВторая проверка\n'
 const a=parseWebVtt(draft,239)
 assert.equal(a.length,2)
 assert.equal(a[1].start,79)
 assert.equal(exportWebVtt(a,239),draft)
 assert.deepEqual(validateCues(a,239),[])
})
test('WebVTT English valid cues with numbered identifiers and NOTE blocks',()=>{
 const source='WEBVTT\n\nNOTE private editorial draft\nNo approval\n\n23\n00:00:07.000 --> 00:00:09.200\nA test line\n'
 assert.deepEqual(parseWebVtt(source,45),[{start:7,end:9.2,text:'A test line'}])
})
test('Empty WebVTT must not be misreported as imported subtitles',()=>{
 assert.throws(()=>parseWebVtt('WEBVTT\n\n',239),/No caption cues/)
})
test('WebVTT import rejects overlap, out-of-range, markup and forged settings',()=>{
 const bad=[
 'Not VTT\n\n00:00:01.000 --> 00:00:02.000\nHi\n',
 'WEBVTT\n\n00:00:43.000 --> 00:00:49.000\nBeyond source\n',
 'WEBVTT\n\n00:00:00.000 --> 00:00:02.000\nOne\n\n00:00:01.000 --> 00:00:03.000\nOverlap\n',
 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000 align:start\nUnsupported setting\n',
 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\n<b>Unapproved markup</b>\n',
 'WEBVTT\n\nSTYLE\n::cue{color:red}\n',
 'WEBVTT\n\n00:00:01.000 --> 00:00:01.000\nNo duration\n',
 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\n\n'
 ]
 for(const doc of bad) assert.throws(()=>parseWebVtt(doc,45),undefined,doc)
})
test('Cue validation fails closed on empty, malformed, nonfinite and unsorted text',()=>{
 assert.deepEqual(validateCues([{start:1,end:2,text:''}],45),['invalid_text_0'])
 assert.ok(validateCues([{start:NaN,end:2,text:'Hi'}],45).includes('invalid_range_0'))
 assert.ok(validateCues([{start:0,end:3,text:'A'},{start:2.5,end:5,text:'B'}],45).includes('overlap_or_unsorted_1'))
 assert.throws(()=>exportWebVtt([],239),/empty/)
 assert.throws(()=>exportWebVtt([{start:238,end:240,text:'Beyond 239s'}],239),/Invalid/)
})
test('Private export is explicitly NOT authorization even with byte-matched source',()=>{
 const r=createPrivateCaptionReport({sourceId:'osa-v15-directors-ru',sourceSha256:'a'.repeat(64),locale:'ru',sourceBytesVerified:true,cues:[{start:1,end:2,text:'Test spoken line not confirmed'}]})
 assert.equal(r.releaseAuthorized,false)
 assert.equal(r.rightsCleared,false)
 assert.equal(r.captionsEditoriallyApproved,false)
 assert.equal(r.transcriptMatchesAudibleSpeech,false)
 assert.equal(r.publicPlaybackApproved,false)
 assert.equal(r.sourceBytesVerified,true)
 assert.equal(r.cues.length,1)
 assert.throws(()=>createPrivateCaptionReport({sourceId:'unverified',sourceSha256:'bad',locale:'ru',cues:[]}),/Unknown/)
})
