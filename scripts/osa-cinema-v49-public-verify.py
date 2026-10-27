#!/usr/bin/env python3
"""Verify true HTTPS media 200/206/416 and every byte against V48.1 master pins.

Local mode is only for unit/staging tests and can never generate a public proof.
"""
import argparse
from datetime import datetime,timezone
import hashlib
import json
from pathlib import Path
import sys
from urllib.parse import urljoin,urlsplit
from urllib.request import Request,urlopen
from urllib.error import HTTPError

ROOT=Path(__file__).resolve().parent.parent
PRODUCTION='https://osgard.world/osa-cinema/premiere/'

def fetch(url,rng=None):
    headers={'Accept-Encoding':'identity','User-Agent':'OSA-V49-BYTE-INTEGRITY/1.0'}
    if rng:headers['Range']=rng
    try:return urlopen(Request(url,headers=headers),timeout=25)
    except HTTPError as error:return error

def verify_asset(base,asset):
    rel,sha,size=asset['path'],asset['sha256'],asset['bytes']
    if not isinstance(size,int) or size<100 or len(sha)!=64:raise ValueError('invalid pinned asset')
    if '..' in Path(rel).parts or rel.startswith('/'):raise ValueError('unsafe path')
    url=urljoin(base,rel)
    if urlsplit(url).netloc!=urlsplit(base).netloc:raise ValueError('cross-origin asset')
    last=min(size,1024)-1
    with fetch(url,f'bytes=0-{last}') as result:
        if result.status!=206 or result.headers.get('Content-Range')!=f'bytes 0-{last}/{size}':raise ValueError(rel+' failed Range=0')
        if len(result.read(last+2))!=last+1:raise ValueError(rel+' returned wrong range length')
    with fetch(url,f'bytes={size}-{size+128}') as result:
        if result.status!=416 or result.headers.get('Content-Range')!=f'bytes */{size}':raise ValueError(rel+' failed 416')
    with fetch(url) as result:
        if result.status!=200 or result.geturl()!=url:raise ValueError(rel+' redirect or HTTP 200 missing')
        expected='video/mp4' if rel.endswith('.mp4') else 'text/vtt'
        if expected not in result.headers.get('Content-Type','').lower():raise ValueError(rel+' MIME mismatch')
        if int(result.headers.get('Content-Length','-1'))!=size:raise ValueError(rel+' Content-Length mismatch')
        digest=hashlib.sha256();read=0
        for chunk in iter(lambda:result.read(1024*1024),b''):
            read+=len(chunk)
            if read>size:raise ValueError(rel+' response exceeded pin')
            digest.update(chunk)
        if read!=size or digest.hexdigest()!=sha:raise ValueError(rel+' full SHA-256 mismatch')
    return {'path':rel,'bytesVerified':size,'sha256Verified':sha,'url':url,
            'httpFull':200,'httpRange':206,'httpUnsatisfiableRange':416}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base',default=PRODUCTION)
    parser.add_argument('--report',required=True)
    parser.add_argument('--local-qa',action='store_true')
    args=parser.parse_args()
    parts=urlsplit(args.base)
    if args.local_qa:
        if parts.scheme!='http' or parts.hostname not in ('127.0.0.1','localhost','::1'):
            raise ValueError('local QA must be explicitly loopback HTTP')
    elif args.base!=PRODUCTION:
        raise ValueError('public QA must target the exact production HTTPS URL')
    pin=json.loads((ROOT/'docs/OSA_CINEMA_V48_LOCAL_MEDIA_CANDIDATE_20261027.json').read_text())
    if pin.get('localCaptionRevision')!='V48.1_ACCESSIBILITY_FIX_NO_VIDEO_OR_AUDIO_CHANGE' or len(pin.get('assets',[]))!=8:
        raise ValueError('missing canonical V48.1 pin')
    results=[]
    for asset in pin['assets']:
        result=verify_asset(args.base,asset)
        results.append(result)
        print('PASS',result['path'],result['bytesVerified'])
    index=urljoin(args.base,'index.html')
    with fetch(index) as response:
        page=response.read(256*1024)
        if response.status!=200 or b'BEYOND' not in page or b'osa-v48-' not in page:
            raise ValueError('premiere HTML is not valid')
    proof={'schemaVersion':1,'project':'OSA CINEMA','status':
         'LOOPBACK_INTEGRITY_ONLY_NOT_PUBLIC' if args.local_qa else 'PRODUCTION_HTTP_BYTES_VERIFIED_BROWSER_STILL_PENDING',
         'baseUrl':args.base,'assetsVerified':len(results),
         'bytesVerified':sum(item['bytesVerified'] for item in results),'results':results,
         'browserPlaybackVerified':False,'paidCheckoutEnabled':False,
         'timestampUTC':datetime.now(timezone.utc).isoformat()}
    dest=Path(args.report)
    if dest.exists():raise ValueError('refusing to overwrite a proof')
    dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_text(json.dumps(proof,indent=2)+'\n')
    print('PASS: all exact bytes; this does NOT prove browser playback')

if __name__=='__main__':
    try:main()
    except Exception as error:
        print('OSA_V49_PUBLIC_QA_HOLD: '+str(error),file=sys.stderr)
        sys.exit(1)
