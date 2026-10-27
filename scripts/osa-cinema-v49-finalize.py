#!/usr/bin/env python3
"""Produce a truthful live receipt only after REAL HTTPS bytes and browser QA.

Never guesses rights, transcripts or browser status. CLI acknowledgement records the
human operator's decision, not a cryptographic signer identity or legal opinion.
"""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import sys

PREFIX='https://osgard.world/osa-cinema/premiere/'
EXPECTED_BYTES=185899405
MP4_RU='c6e71377c2f4ecdcf8327c9ae213cd972a78ea6f97f9090945a7d18fad0fe751'
CHECKS=('desktopPlayback','mobilePlayback','seek','languageSwitch','captions','trailer')
RELEASE_RE=re.compile(r'osa-v[0-9]+-[a-z0-9-]{3,50}')


def fail(message):
    raise ValueError('OSA_V49_FINALIZE_HOLD: '+message)


def load(path):
    path=Path(path)
    if path.is_symlink() or not path.is_file():fail('evidence file must be a regular file')
    if path.stat().st_size>2_000_000:fail('unexpected large evidence')
    return json.loads(path.read_text('utf-8'))


def check(http, browser, pin):
    expected={a['path']:(a['bytes'],a['sha256']) for a in pin['assets']}
    if len(expected)!=8 or len(pin['assets'])!=8:fail('incorrect pinned assets')
    if any(x.get('path') not in expected for x in http.get('results',[])):fail('unknown HTTP asset')
    if http.get('status')!='PRODUCTION_HTTP_BYTES_VERIFIED_BROWSER_STILL_PENDING' or http.get('baseUrl')!=PREFIX:
        fail('real HTTPS source check missing')
    if http.get('assetsVerified')!=8 or http.get('bytesVerified')!=EXPECTED_BYTES or len(http.get('results',[]))!=8:
        fail('incomplete HTTP media transfer')
    seen=set()
    for x in http['results']:
        name=x['path']
        if name in seen:fail('duplicate HTTP evidence')
        seen.add(name)
        size,sha=expected[name]
        if (x.get('bytesVerified'),x.get('sha256Verified'))!=(size,sha):fail('remote bytes differ from GitHub pin')
        if (x.get('httpFull'),x.get('httpRange'),x.get('httpUnsatisfiableRange'))!=(200,206,416):
            fail('HTTP 200/206/416 evidence incomplete')
        if x.get('url')!=PREFIX+name:fail('HTTP URL differs from exact public path')
    if seen!=set(expected):fail('not all eight files checked')
    if browser.get('schemaVersion')!=1 or browser.get('project')!='OSA CINEMA' or browser.get('status')!='PUBLIC_BROWSER_PLAYBACK_PASS' or browser.get('baseUrl')!=PREFIX:
        fail('independent real-browser report missing')
    if browser.get('checks')!={key:True for key in CHECKS}:
        fail('required desktop/mobile/language/subtitle/seek/trailer checks not all PASS')
    if not re.fullmatch(r'[0-9a-f]{40}',browser.get('sourceSha','')):
        fail('browser evidence missing exact source revision')
    return browser['sourceSha']


def finalize(root, release_id, pin_path, http_path, browser_path, acknowledgment):
    if acknowledgment!='I_APPROVE_THE_PUBLIC_OSA_FILM':
        fail('operator must explicitly acknowledge the public release action')
    if not RELEASE_RE.fullmatch(release_id):fail('invalid release ID')
    root=Path(root).absolute()
    if root.is_symlink() or not root.is_dir():fail('invalid media root')
    active=root/'current'
    if not active.is_symlink() or os.readlink(active)!='releases/'+release_id:
        fail('exact release must be active before finalizing')
    actual=root/'releases'/release_id
    if actual.is_symlink() or not actual.is_dir():fail('missing verified release')
    pin=load(pin_path)
    if pin.get('localCaptionRevision')!='V48.1_ACCESSIBILITY_FIX_NO_VIDEO_OR_AUDIO_CHANGE':fail('incorrect version pin')
    source_sha=check(load(http_path),load(browser_path),pin)
    receipt={
      'schemaVersion':1, 'project':'OSA CINEMA', 'status':'PUBLIC_BROWSER_QA_PASS',
      'releaseId':release_id, 'publicPath':'/osa-cinema/premiere/',
      'publicationAuthorized':True, 'authorizationBasis':'OWNER_EXPLICIT_OPERATOR_ACKNOWLEDGMENT_NOT_SIGNED_LEGAL_OPINION',
      'rightsStatus':'OWNER_SELF_ATTESTED', 'captionAccuracy':'AUTOMATED_EDITORIAL_NOT_VERBATIM_REVIEWED',
      'paidCheckoutEnabled':False, 'assetCount':8,'fullRuSha256':MP4_RU,
      'mediaBytes':EXPECTED_BYTES, 'browserSourceSha':source_sha,
      'verifiedAtUTC':datetime.now(timezone.utc).isoformat()
    }
    marker=actual/'release.json'
    if marker.exists() or marker.is_symlink():fail('immutable live receipt already exists')
    temp=actual/'.release-json.tmp'
    with temp.open('x', encoding='utf-8') as out:
        json.dump(receipt,out,ensure_ascii=False,sort_keys=True,indent=2)
        out.write('\n')
    temp.chmod(0o644)
    os.replace(temp,marker)
    return receipt


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ('root','release-id','pin','http-report','browser-report','publisher-acknowledgment'):
        parser.add_argument('--'+name,required=True)
    a=parser.parse_args()
    receipt=finalize(a.root,a.release_id,a.pin,a.http_report,a.browser_report,a.publisher_acknowledgment)
    print(json.dumps({'status':receipt['status'],'releaseId':receipt['releaseId'],'publicPath':receipt['publicPath'],'sourceSha':receipt['browserSourceSha']},sort_keys=True))


if __name__=='__main__':
    try:main()
    except (ValueError,KeyError,OSError,json.JSONDecodeError) as e:
        print('HOLD '+str(e),file=sys.stderr);sys.exit(1)
