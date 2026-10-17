"""INHERIT lineage database and authorization regressions, entirely isolated."""
import sys
import tempfile
import unittest
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'server'))
from core_model import Fault,now
from core_server import Store


class InheritCoreTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.store=Store(Path(self.tmp.name)/'core.sqlite')
        with self.store.transaction() as db:
            for n,name in enumerate(('alpha','bravo','charlie'),1):
                db.execute('INSERT INTO users VALUES(?,?,?,?,?)',
                           (f'{n:032x}',name,'0'*32,'fixture-password-hash',now()))
        self.ids={name:f'{n:032x}' for n,name in enumerate(('alpha','bravo','charlie'),1)}

    def write(self,route,user='alpha',payload=None,key=None):
        return self.store.mutate(route,self.ids[user],payload or {},key or uuid.uuid4().hex)

    def read(self,route,user='alpha'):
        return self.store.get(route,self.ids[user])

    def fault(self,code,callback):
        with self.assertRaises(Fault) as error:callback()
        self.assertEqual(error.exception.status,code)

    def make(self):
        return self.write('inherit/worlds',payload={'title':'The Quiet Reach'})['worldId']

    def offer(self,wid,from_user='alpha',to_user='bravo',version=1,generation=1,key=None):
        return self.write(f'inherit/worlds/{wid}/pass',from_user,{
            'expectedVersion':version,'expectedGeneration':generation,
            'toUsername':to_user,'message':'New traces to discover',
            'delta':[{'type':'tree','x':20,'y':34}]},key)

    def accept(self,wid,who='bravo',version=2,generation=1,key=None):
        return self.write(f'inherit/worlds/{wid}/accept',who,{
            'expectedVersion':version,'expectedGeneration':generation},key)

    def test_two_people_and_return_to_previous_keeper(self):
        wid=self.make()
        self.fault(404,lambda:self.read(f'inherit/worlds/{wid}','bravo'))
        self.offer(wid)
        self.assertEqual(len(self.read('inherit/inbox','bravo')['invitations']),1)
        self.fault(404,lambda:self.read(f'inherit/worlds/{wid}','bravo'))
        result=self.accept(wid)
        self.assertEqual(result['generation'],2)
        view=self.read(f'inherit/worlds/{wid}','alpha')
        self.assertEqual(view['world']['keeper'],'bravo')
        self.assertEqual(view['snapshot']['objects'],[{'type':'tree','x':20,'y':34}])
        self.assertEqual(view['history'][0]['hash'],result['recordHash'])
        self.assertTrue(any(e['kind']=='new_generation' for e in self.read('inherit/inbox')['events']))
        self.fault(403,lambda:self.offer(wid,'alpha','charlie',3,2))
        self.offer(wid,'bravo','alpha',3,2)
        self.accept(wid,'alpha',4,2)
        self.assertEqual(self.read(f'inherit/worlds/{wid}')['world']['generation'],3)

    def test_conflict_replay_and_no_unauthorized_write(self):
        key=uuid.uuid4().hex
        first=self.write('inherit/worlds',payload={'title':'Quiet World'},key=key)
        replay=self.write('inherit/worlds',payload={'title':'Quiet World'},key=key)
        self.assertTrue(replay['replayed'])
        self.assertEqual(first['worldId'],replay['worldId'])
        self.fault(409,lambda:self.write('inherit/worlds',payload={'title':'Other World'},key=key))
        wid=first['worldId']
        self.fault(403,lambda:self.offer(wid,'bravo','charlie',1))
        self.fault(409,lambda:self.offer(wid,version=2))
        offer_key=uuid.uuid4().hex
        self.offer(wid,key=offer_key)
        self.assertTrue(self.offer(wid,key=offer_key)['replayed'])
        self.fault(409,lambda:self.offer(wid,to_user='charlie',version=2))
        accept_key=uuid.uuid4().hex
        self.accept(wid,key=accept_key)
        self.assertTrue(self.accept(wid,key=accept_key)['replayed'])
        self.assertEqual(len(self.read(f'inherit/worlds/{wid}')['history']),1)

    def test_cancel_bad_payload_and_inbox_isolation(self):
        wid=self.make()
        self.fault(400,lambda:self.write(f'inherit/worlds/{wid}/pass',payload={
            'expectedVersion':1,'expectedGeneration':1,'toUsername':'bravo',
            'message':'A message', 'delta':[{'type':'tree','x':True,'y':3}]}))
        self.offer(wid)
        self.fault(404,lambda:self.accept(wid,'charlie'))
        event=self.read('inherit/inbox','bravo')['events'][0]['id']
        self.fault(404,lambda:self.write('inherit/inbox/ack','charlie',{'eventId':event}))
        self.write('inherit/inbox/ack','bravo',{'eventId':event})
        self.assertIsNotNone(self.read('inherit/inbox','bravo')['events'][0]['readAt'])
        self.write(f'inherit/worlds/{wid}/cancel',payload={
            'expectedVersion':2,'expectedGeneration':1})
        self.fault(404,lambda:self.accept(wid))
        self.assertEqual(self.read(f'inherit/worlds/{wid}')['history'],[])

    def test_concurrent_handoff_and_corruption_fail_closed(self):
        wid=self.make()
        with ThreadPoolExecutor(max_workers=2) as pool:
            results=list(pool.map(lambda who:self._offer_outcome(wid,who),
                                  ('bravo','charlie')))
        self.assertEqual(sorted(results),[200,409])
        who='bravo' if self.read('inherit/inbox','bravo')['invitations'] else 'charlie'
        self.accept(wid,who)
        with self.store.transaction() as db:
            db.execute("UPDATE inherit_generations SET message='tampered' WHERE world_id=?",(wid,))
        self.fault(503,lambda:self.read(f'inherit/worlds/{wid}'))
        self.fault(503,lambda:self.read(f'inherit/worlds/{wid}',who))

    def _offer_outcome(self,wid,who):
        try:self.offer(wid,to_user=who);return 200
        except Fault as error:return error.status


if __name__=='__main__':unittest.main()
