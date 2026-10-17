"""Regression checks for INHERIT's persisted lineage chain and current state."""
import json
import unittest
import uuid

from test_core_inherit import InheritFixture


class LineageIntegrityTests(InheritFixture, unittest.TestCase):
    def test_untouched_lineage_returns_identical_snapshots(self):
        world=self.create('local-copy',[dict(type='stone',x=5,y=95)])
        first=self.append(world)['world']
        second=self.append(first,x=67)['world']
        fresh=self.read('worlds/'+world['id'])['world']
        self.assertEqual(fresh['objects'],second['objects'])
        self.assertEqual(len(fresh['generations']),2)
        self.assertEqual(fresh['snapshotHash'],second['snapshotHash'])
        self.assertEqual(self.read('worlds/'+world['id']+'/generations/1')['generation']['objects'],
                         first['objects'])

    def test_changed_baseline_is_not_a_valid_local_copy(self):
        world=self.create('local-copy',[dict(type='stone',x=4,y=4)])
        with self.store.transaction() as db:
            db.execute("UPDATE inherit_worlds SET baseline='[]' WHERE id=?",(world['id'],))
        self.fault(503,self.read,'worlds/'+world['id'])
        self.fault(503,self.append,world)

    def test_corrupted_tip_json_blocks_read_and_new_input(self):
        world=self.append(self.create())['world']
        with self.store.transaction() as db:
            db.execute("UPDATE inherit_worlds SET objects='not json' WHERE id=?",(world['id'],))
        self.fault(503,self.read,'worlds/'+world['id'])
        self.fault(503,self.append,world)
        self.fault(503,self.read,'worlds/'+world['id']+'/generations/1')

    def test_tip_snapshot_divergence_is_rejected_even_when_json_valid(self):
        world=self.append(self.create())['world']
        with self.store.transaction() as db:
            db.execute("UPDATE inherit_worlds SET objects='[]' WHERE id=?",(world['id'],))
        self.fault(503,self.read,'worlds/'+world['id'])
        self.fault(503,self.offer,world)

    def test_modified_tip_hash_blocks_cached_response(self):
        world=self.create()
        key=uuid.uuid4().hex
        result=self.append(world,key=key)
        with self.store.transaction() as db:
            db.execute("UPDATE inherit_worlds SET snapshot_hash=? WHERE id=?",('f'*64,world['id']))
        self.fault(503,self.read,'operations/'+key)
        self.fault(503,self.append,result['world'])

    def test_mutated_generation_delta_is_detected_without_legacy_triggers(self):
        world=self.append(self.create())['world']
        with self.store.transaction() as db:
            db.execute('DROP TRIGGER inherit_generation_no_update')
            db.execute("UPDATE inherit_generations SET delta=? WHERE world_id=?",(
                json.dumps([dict(type='path',x=12,y=12)]),world['id']))
        self.fault(503,self.read,'worlds/'+world['id'])
        self.fault(503,self.read,'worlds/'+world['id']+'/generations/1')

    def test_invitation_cannot_be_accepted_when_world_tip_is_corrupt(self):
        world=self.append(self.create())['world']
        offered=self.offer(world)
        invitation=offered['invitation']
        with self.store.transaction() as db:
            db.execute("UPDATE inherit_worlds SET objects='[]' WHERE id=?",(world['id'],))
        self.fault(503,self.accept,invitation)
        with self.store.connect() as db:
            row=db.execute('SELECT status FROM inherit_handoffs WHERE id=?',(invitation['id'],)).fetchone()
            self.assertEqual(row['status'],'pending')

    def test_bad_latest_generation_and_explicit_no_implicit_repairs(self):
        world=self.append(self.create())['world']
        with self.store.transaction() as db:
            db.execute("UPDATE inherit_worlds SET generation=99 WHERE id=?",(world['id'],))
        self.fault(503,self.read,'worlds/'+world['id'])
        with self.store.connect() as db:
            self.assertEqual(db.execute('SELECT generation FROM inherit_worlds WHERE id=?',
                            (world['id'],)).fetchone()['generation'],99)


if __name__=='__main__':
    unittest.main(verbosity=2)
