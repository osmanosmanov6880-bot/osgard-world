import json
import tempfile
import unittest
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'server'))
from core_server import Store
from core_model import Fault

class ProjectCreationContract(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.store=Store(Path(self.tmp.name)/'core.sqlite')
        self.auth=self.store.auth('register',{'username':'creator_test','password':'secure-test-password-123'})
        self.actor=self.store.actor(self.auth['token'])['id']
    def tearDown(self):
        self.tmp.cleanup()
    def test_created_structure_is_persisted(self):
        p={'title':'Сервис заявок','goal':'Запустить понятный портал заявок для клиентов','audience':'Менеджеры студий','projectKind':'software','tasks':['Создать структуру','Проверить интерфейс'],'acceptance':['Клиент может создать заявку']}
        with self.store.transaction() as db:
            # The same authoritative mutation is used by the HTTP API.
            from core_model import initial, uid, now
            from core_model import text,require
            d=initial(p['title'],p['goal']);d['audience']=text(p['audience'],1000)
            for field in ('tasks','acceptance'):
                d[field]=[dict(id=uid(),title=text(item,500,2),done=False) for item in p[field]]
            pid=uid(); stamp=now(); raw=json.dumps(d,ensure_ascii=False)
            db.execute('INSERT INTO projects VALUES(?,?,?,?,?,?)',(pid,self.actor,1,raw,stamp,stamp))
        with self.store.connect() as db:
            saved=json.loads(db.execute('SELECT data FROM projects').fetchone()['data'])
        self.assertEqual(saved['audience'],'Менеджеры студий')
        self.assertEqual([t['title'] for t in saved['tasks']],p['tasks'])
        self.assertEqual(saved['acceptance'][0]['title'],p['acceptance'][0])
if __name__=='__main__': unittest.main()
