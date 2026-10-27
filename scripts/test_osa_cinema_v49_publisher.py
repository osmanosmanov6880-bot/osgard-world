#!/usr/bin/env python3
"""Security and atomic-release tests against real filesystem operations."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest

SCRIPT=Path(__file__).with_name('osa-cinema-v49-publisher.py')
spec=importlib.util.spec_from_file_location('osa_v49_publisher',SCRIPT)
pub=importlib.util.module_from_spec(spec)
spec.loader.exec_module(pub)


def digest(data):
    return hashlib.sha256(data).hexdigest()


class PublisherTest(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.work=Path(self.tmp.name)
        self.src=self.work/'source'
        self.root=self.work/'persistent-media'
        self.src.mkdir()
        self.root.mkdir()
        self.pinfile=self.work/'pin.json'
        media=[]
        totals={}
        for i,(key,path) in enumerate(pub.MEDIA.items()):
            data=(b'\0\0\0\x18ftypisom0000\0\0\0\0' if path.endswith('.mp4')
                 else b'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nA word\n')+bytes([65+i])*48
            out=self.src/path
            out.parent.mkdir(parents=True,exist_ok=True)
            out.write_bytes(data)
            media.append({'id':key,'path':path,'kind':'video' if path.endswith('.mp4') else 'webvtt',
                          'sha256':digest(data),'bytes':len(data)})
            totals[path]=digest(data)
        index=b'<!doctype html><html><head><title>BEYOND THE MODEL</title></head></html>'
        poster=b'\xff\xd8\xff'+b'jpg bytes'*8
        (self.src/'index.html').write_bytes(index)
        (self.src/'assets').mkdir()
        (self.src/'assets/osa-premiere-poster.jpg').write_bytes(poster)
        totals['index.html']=digest(index)
        totals['assets/osa-premiere-poster.jpg']=digest(poster)
        manifest={'releaseCandidate':'V48','paidCheckoutEnabled':False,'assets':media}
        manifest_bytes=(json.dumps(manifest,sort_keys=True)+'\n').encode()
        (self.src/'manifest.json').write_bytes(manifest_bytes)
        totals['manifest.json']=digest(manifest_bytes)
        (self.src/'SHA256SUMS.txt').write_text(''.join(f'{h}  {p}\n' for p,h in totals.items()))
        pin={'localCaptionRevision':'V48.1_ACCESSIBILITY_FIX_NO_VIDEO_OR_AUDIO_CHANGE',
             'releaseDecision':'NO_GO','publicationAuthorized':False,'assets':media}
        self.pinfile.write_text(json.dumps(pin))
        original_pins=pub.EXTRA_PIN
        pub.EXTRA_PIN={rel:totals[rel] for rel in pub.EXTRA}
        self.addCleanup(setattr,pub,'EXTRA_PIN',original_pins)

    def test_verify_stage_activate_rollback(self):
        evidence=pub.verify_source(self.src,self.pinfile)
        self.assertEqual((evidence['assets'],evidence['files']),(8,11))
        pub.stage(self.src,self.pinfile,self.root,'osa-v49-example-1')
        staged=self.root/'releases/osa-v49-example-1'
        self.assertTrue((staged/'masters/osa-v48-directors-en.mp4').is_file())
        self.assertFalse((self.root/'current').exists())
        pub.activate(self.pinfile,self.root,'osa-v49-example-1')
        self.assertEqual(os.readlink(self.root/'current'),'releases/osa-v49-example-1')
        pub.rollback(self.root)
        self.assertFalse((self.root/'current').is_symlink())

    def test_modified_input_denied(self):
        path=self.src/'masters/osa-v48-directors-ru.mp4'
        path.write_bytes(path.read_bytes()+b'altered')
        with self.assertRaisesRegex(pub.GateError,'mismatch'):
            pub.stage(self.src,self.pinfile,self.root,'osa-v49-example-1')
        self.assertFalse((self.root/'current').exists())

    def test_tampered_stage_denied_on_activate(self):
        pub.stage(self.src,self.pinfile,self.root,'osa-v49-example-1')
        path=self.root/'releases/osa-v49-example-1/captions/osa-v48-trailer-en.vtt'
        path.write_bytes(path.read_bytes()+b'evil')
        with self.assertRaisesRegex(pub.GateError,'mismatch'):
            pub.activate(self.pinfile,self.root,'osa-v49-example-1')
        self.assertFalse((self.root/'current').is_symlink())

    def test_symlink_source_denied(self):
        path=self.src/'captions/osa-v48-trailer-en.vtt'
        backup=self.work/'original.vtt'
        path.rename(backup)
        path.symlink_to(backup)
        with self.assertRaisesRegex(pub.GateError,'not a regular file'):
            pub.verify_source(self.src,self.pinfile)

    def test_no_duplicate_release_or_path_traversal(self):
        pub.stage(self.src,self.pinfile,self.root,'osa-v49-example-1')
        with self.assertRaisesRegex(pub.GateError,'already exists'):
            pub.stage(self.src,self.pinfile,self.root,'osa-v49-example-1')
        with self.assertRaisesRegex(pub.GateError,'invalid release ID'):
            pub.activate(self.pinfile,self.root,'../../other')

    def test_bad_pinned_identity_denied(self):
        pin=json.loads(self.pinfile.read_text())
        pin['assets'][0]['sha256']='f'*64
        self.pinfile.write_text(json.dumps(pin))
        with self.assertRaisesRegex(pub.GateError,'GitHub SHA'):
            pub.verify_source(self.src,self.pinfile)

    def test_staged_release_immutable_after_first_creation(self):
        pub.stage(self.src,self.pinfile,self.root,'osa-v49-example-1')
        pub.activate(self.pinfile,self.root,'osa-v49-example-1')
        with self.assertRaisesRegex(pub.GateError,'already active'):
            pub.activate(self.pinfile,self.root,'osa-v49-example-1')

    def test_same_origin_html_tamper_even_with_forged_sha256sums_denied(self):
        index=self.src/'index.html'
        evil=index.read_bytes()+b'<script>console.log("injection")</script>'
        index.write_bytes(evil)
        sums=(self.src/'SHA256SUMS.txt').read_text().splitlines()
        sums=[(digest(evil)+'  index.html') if line.endswith('  index.html') else line for line in sums]
        (self.src/'SHA256SUMS.txt').write_text('\\n'.join(sums)+'\\n')
        with self.assertRaisesRegex(pub.GateError,'immutable GitHub shell pin mismatch'):
            pub.verify_source(self.src,self.pinfile)

    def test_bad_rollback_pointer_denied(self):
        (self.root/'current').symlink_to('../../etc')
        with self.assertRaisesRegex(pub.GateError,'outside'):
            pub.rollback(self.root)


if __name__ == '__main__':
    unittest.main(verbosity=2)
