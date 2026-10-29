"""OSA CINEMA V63 real binary HTTP/SQLite vault acceptance with V62+V61/Core regressions."""
from http.client import HTTPConnection
from pathlib import Path
from urllib.parse import quote
from tempfile import TemporaryDirectory
from concurrent.futures import ThreadPoolExecutor
import hashlib
import importlib.util
import json
import sys
import unittest
import uuid

spec=importlib.util.spec_from_file_location('cinema_v62',Path(__file__).with_name('core-cinema-v62-evidence-smoke.py'))
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
from core_server import Store
from core_backup import backup
from core_cinema_vault import MAX_ASSET_BYTES

PDF=b'%PDF-1.7\n1 0 obj <</Type/Catalog>>\nendobj\n%%EOF\n'
PNG=b'\x89PNG\r\n\x1a\n'+b'\x00'*20
MP4=b'\x00\x00\x00\x18ftypisom\x00\x00\x00\x00isomiso2'

class VaultTests(base.EvidenceTests):
    def raw(self,method,route,body=None,token=None,headers=None):
        c=HTTPConnection('127.0.0.1',self.port,timeout=10)
        h=dict(headers or {})
        if token:h['Authorization']='Bearer '+token
        c.request(method,'/api/core/'+route,body,h)
        r=c.getresponse();status=r.status;response_headers=dict(r.getheaders())
        data=r.read();c.close()
        if response_headers.get('Content-Type','').startswith('application/json'):
            try:data=json.loads(data)
            except (ValueError,UnicodeError):pass
        return status,response_headers,data

    def upload_raw(self,wid,version,content=PDF,name='screenplay.pdf',
                   mime='application/pdf',token=None,key=None,extra=None):
        hdr={'Content-Type':mime,'X-Cinema-File-Name':quote(name,safe=''),
             'X-Space-Version':str(version),'Idempotency-Key':key or uuid.uuid4().hex}
        hdr.update(extra or {})
        return self.raw('POST','cinema/spaces/'+wid+'/vault/upload',content,token or self.owner['token'],hdr)

    def download_raw(self,wid,aid,token=None):
        return self.raw('GET','cinema/spaces/'+wid+'/vault/'+aid+'/download',token=token or self.owner['token'])

    def listing(self,wid,token=None):
        return self.request('GET','cinema/spaces/'+wid+'/vault',token=token or self.owner['token'])

    def test_real_binary_upload_sha256_and_private_download(self):
        wid=self.workspace()
        status,headers,result=self.upload_raw(wid,1)
        self.assertEqual(status,200,result)
        self.assertEqual(result['actualSha256'],hashlib.sha256(PDF).hexdigest())
        self.assertTrue(result['checksumComputedFromBytes'])
        self.assertFalse(result['malwareScanned'])
        self.assertFalse(result['releaseAuthorized'])
        self.assertIsNone(result['publicVideoUrl'])
        aid=result['assetId']
        status,response_headers,content=self.download_raw(wid,aid)
        self.assertEqual(status,200)
        self.assertEqual(content,PDF)
        self.assertEqual(response_headers['Content-Type'],'application/octet-stream')
        self.assertEqual(response_headers['Cache-Control'],'no-store')
        self.assertEqual(response_headers['X-Content-Type-Options'],'nosniff')
        self.assertTrue(response_headers['Content-Disposition'].startswith('attachment; filename="osa-cinema-'))
        self.assertEqual(response_headers['X-OSA-Cinema-SHA256'],hashlib.sha256(PDF).hexdigest())
        listing=self.listing(wid)[1]
        self.assertEqual(len(listing['assets']),1)
        self.assertEqual(listing['usedBytes'],len(PDF))
        self.assertEqual(listing['assets'][0]['actualSha256'],result['actualSha256'])
        self.assertFalse(listing['publicStreamingEnabled'])
        self.assertFalse(listing['encryptionAtRest'])
        self.assertFalse(listing['serverAntivirus'])
        self.assertNotIn(PDF.decode('latin1'),json.dumps(listing))

    def test_private_membership_origin_and_same_site(self):
        wid=self.workspace()
        status,_,asset=self.upload_raw(wid,1)
        self.assertEqual(status,200,asset)
        path='cinema/spaces/'+wid+'/vault/'+asset['assetId']+'/download'
        self.assertEqual(self.raw('GET',path)[0],401)
        self.assertEqual(self.download_raw(wid,asset['assetId'],self.other['token'])[0],404)
        self.assertEqual(self.upload_raw(wid,2,token=self.other['token'])[0],404)
        self.assertEqual(self.raw('GET',path,token=self.owner['token'],
                         headers={'Origin':'https://evil.example'})[0],403)
        self.assertEqual(self.raw('GET',path,token=self.owner['token'],
                         headers={'Host':'evil.example'})[0],403)
        self.assertEqual(self.edit(wid,2,'member.set',username='viewer',role='viewer')[0],200)
        self.assertEqual(self.download_raw(wid,asset['assetId'],self.viewer['token'])[0],200)
        self.assertEqual(self.upload_raw(wid,3,token=self.viewer['token'])[0],403)
        self.assertEqual(self.write('cinema/spaces/'+wid+'/vault',
           dict(kind='asset.delete',expectedVersion=3,assetId=asset['assetId']),
           self.viewer['token'])[0],403)
        self.assertEqual(self.edit(wid,3,'member.remove',username='viewer')[0],200)
        self.assertEqual(self.download_raw(wid,asset['assetId'],self.viewer['token'])[0],404)

    def test_mime_signature_traversal_and_length_fail_closed(self):
        wid=self.workspace()
        invalid=[
          (b'<script>alert(1)</script>','danger.html','text/html'),
          (b'<html>evil</html>','disguised.pdf','application/pdf'),
          (PDF,'escape/../secret.pdf','application/pdf'),
          (PDF,'..secret.pdf','application/pdf'),
          (PDF,'secret.exe','application/pdf'),
          (PDF,'script.pdf','application/octet-stream'),
          (PNG,'png.jpg','image/jpeg'),
          (b'\x00\x01\x02','fake.txt','text/plain'),
          (MP4,'clip.mp4','video/mp4;unknown'),
        ]
        for content,name,mime in invalid:
            status,_,_=self.upload_raw(wid,1,content,name,mime)
            self.assertIn(status,(400,415),(name,status))
        self.assertEqual(self.listing(wid)[1]['assets'],[])
        self.assertEqual(self.view(wid)[1]['space']['version'],1)
        oversized=b'a'*(MAX_ASSET_BYTES+1)
        self.assertEqual(self.upload_raw(wid,1,oversized,'big.txt','text/plain')[0],413)
        self.assertEqual(self.upload_raw(wid,1,b'','empty.txt','text/plain')[0],413)
        self.assertEqual(self.listing(wid)[1]['assets'],[])

    def test_support_real_png_and_mp4_bytes_as_private_attachments(self):
        wid=self.workspace()
        status,_,png=self.upload_raw(wid,1,PNG,'frame.png','image/png')
        self.assertEqual(status,200,png)
        status,_,mp4=self.upload_raw(wid,2,MP4,'small-proxy.mp4','video/mp4')
        self.assertEqual(status,200,mp4)
        _,h,body=self.download_raw(wid,mp4['assetId'])
        self.assertEqual(body,MP4)
        self.assertEqual(h['Content-Type'],'application/octet-stream')
        self.assertNotIn('video/mp4',h['Content-Type'])
        self.assertFalse(self.listing(wid)[1]['releaseAuthorized'])
        self.assertFalse(self.view(wid)[1]['space']['publicFilmReleaseAuthorized'])

    def test_idempotency_with_real_bytes_concurrent(self):
        wid=self.workspace()
        key=uuid.uuid4().hex
        def same(_):return self.upload_raw(wid,1,PDF,key=key)
        with ThreadPoolExecutor(max_workers=2) as pool:responses=list(pool.map(same,[0,1]))
        self.assertEqual(sorted(x[0] for x in responses),[200,200],responses)
        self.assertEqual(len({x[2]['assetId'] for x in responses}),1)
        self.assertTrue(any(x[2]['replayed'] for x in responses))
        self.assertEqual(len(self.listing(wid)[1]['assets']),1)
        self.assertEqual(self.upload_raw(wid,1,b'%PDF-new',key=key)[0],409)
        self.assertEqual(self.upload_raw(wid,2,PDF,key=key)[0],409)
        self.assertEqual(self.listing(wid)[1]['usedBytes'],len(PDF))

    def test_version_and_cross_workspace_protection(self):
        a=self.workspace()
        b=self.workspace('threshold')
        status,_,res=self.upload_raw(a,1)
        self.assertEqual(status,200,res)
        aid=res['assetId']
        self.assertEqual(self.download_raw(b,aid)[0],404)
        self.assertEqual(self.write('cinema/spaces/'+b+'/vault',
          dict(kind='asset.delete',expectedVersion=1,assetId=aid))[0],404)
        self.assertEqual(self.upload_raw(a,1)[0],409)
        self.assertEqual(self.upload_raw(b,1)[0],200)
        self.assertEqual(len(self.listing(a)[1]['assets']),1)

    def test_link_to_existing_evidence_but_never_automatically_clear(self):
        wid=self.workspace()
        evidence_id=self.create_evidence(wid)
        status,_,res=self.upload_raw(wid,2,extra={'X-Cinema-Evidence-Id':evidence_id})
        self.assertEqual(status,200,res)
        asset=self.listing(wid)[1]['assets'][0]
        self.assertEqual(asset['evidenceId'],evidence_id)
        self.assertFalse(self.read_evidence(wid)[1]['evidence'][0]['externalRightsVerified'])
        self.assertEqual(self.read_evidence(wid)[1]['evidence'][0]['state'],'draft')
        self.assertEqual(self.upload_raw(wid,3,extra={'X-Cinema-Evidence-Id':'a'*32})[0],404)

    def test_revocation_blocks_prior_binary_key_replay(self):
        wid=self.workspace()
        self.assertEqual(self.edit(wid,1,'member.set',username='other',role='editor')[0],200)
        key=uuid.uuid4().hex
        status,_,res=self.upload_raw(wid,2,token=self.other['token'],key=key)
        self.assertEqual(status,200,res)
        self.assertTrue(self.upload_raw(wid,2,token=self.other['token'],key=key)[2]['replayed'])
        self.assertEqual(self.edit(wid,3,'member.remove',username='other')[0],200)
        self.assertEqual(self.upload_raw(wid,2,token=self.other['token'],key=key)[0],404)
        self.assertEqual(self.download_raw(wid,res['assetId'],self.other['token'])[0],404)

    def test_audited_delete_and_durable_restore(self):
        wid=self.workspace()
        status,_,res=self.upload_raw(wid,1)
        self.assertEqual(status,200,res)
        aid=res['assetId']
        fresh=Store(self.db)
        restored=fresh.get('cinema/spaces/'+wid+'/vault',self.owner['user']['id'])
        self.assertEqual(restored['assets'][0]['id'],aid)
        with TemporaryDirectory() as tmp:
            copy=Path(tmp)/'entire-vault.sqlite3'
            digest=backup(self.db,copy);self.assertEqual(len(digest),64)
            self.assertEqual(Store(copy).get('cinema/spaces/'+wid+'/vault',self.owner['user']['id'])['assets'][0]['actualSha256'],
                            hashlib.sha256(PDF).hexdigest())
        key=uuid.uuid4().hex
        body={'kind':'asset.delete','expectedVersion':2,'assetId':aid}
        status,out=self.write('cinema/spaces/'+wid+'/vault',body,key=key)
        self.assertEqual(status,200,out)
        self.assertTrue(out['backupMayRetainDeletedBytes'])
        self.assertEqual(self.write('cinema/spaces/'+wid+'/vault',body,key=key)[0],200)
        self.assertEqual(self.download_raw(wid,aid)[0],404)
        self.assertEqual(self.listing(wid)[1]['assets'],[])
        audit=[e['kind'] for e in self.view(wid)[1]['audit']]
        self.assertIn('vault_asset_deleted',audit)
        self.assertIn('vault_asset_uploaded',audit)
        self.assertNotIn(PDF.decode(),json.dumps(self.view(wid)[1]['audit']))

if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(VaultTests))
    sys.exit(0 if result.wasSuccessful() else 1)
