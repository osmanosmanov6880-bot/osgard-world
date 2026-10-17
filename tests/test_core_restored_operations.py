#!/usr/bin/env python3
"""Restore/retry contracts against real temporary Core SQLite and an in-memory provider."""
import hashlib
import hmac
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "server"))
from core_backup import backup
from core_commerce import API_VERSION, Config, RETRY_WINDOW
from core_model import Fault
from core_server import Store

provider_spec = importlib.util.spec_from_file_location("commerce_fixture", ROOT / "scripts/core-commerce-smoke.py")
provider_module = importlib.util.module_from_spec(provider_spec)
provider_spec.loader.exec_module(provider_module)
FakeProvider = provider_module.FakeProvider
verify_spec = importlib.util.spec_from_file_location("recovery_verifier", ROOT / "scripts/verify-core-backup.py")
verifier = importlib.util.module_from_spec(verify_spec)
verify_spec.loader.exec_module(verifier)


class RestoredOperationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.people = {name: uuid.uuid4().hex for name in ("merchant", "buyer", "reviewer")}
        self.provider = FakeProvider()
        self.config = Config(True, self.people["merchant"], "acct_fixture", False,
                             "https://osgard.example", "not-a-real-key", "whsec_local_test_fixture_only")
        # An accidentally constructed SDK adapter must fail this test instead of contacting anything.
        blocked = patch("core_commerce.StripeProvider", side_effect=AssertionError("real provider is forbidden"))
        blocked.start()
        self.addCleanup(blocked.stop)
        self.store = Store(self.base / "source.sqlite3", self.config, self.provider)
        with self.store.transaction() as db:
            for name, actor in self.people.items():
                db.execute("INSERT INTO users VALUES(?,?,?,?,?)",
                           (actor, "recovery-" + name, "00", "synthetic-unusable-hash", "2026-01-01T00:00:00Z"))
        self.project = self.write("projects", dict(title="Recovery fixture", goal="Create and verify one recoverable artifact."))["project"]
        self.prepare()

    def write(self, route, body, person="merchant", key=None):
        return self.store.mutate(route, self.people[person], body, key or uuid.uuid4().hex)

    def project_route(self, suffix=""):
        return "projects/" + self.project["id"] + suffix

    def update(self, changes):
        result = self.write(self.project_route(), dict(expectedVersion=self.project["version"], changes=changes))
        self.project = result["project"]

    def act(self, kind, payload=None, key=None):
        body = dict(expectedVersion=self.project["version"], kind=kind, payload=payload or {})
        result = self.write(self.project_route("/actions"), body, key=key)
        self.project = result["project"]
        return result, body

    def prepare(self):
        self.update(dict(currency="USD", budgetMinor=20000, consents=dict(learning=True, studio=True, business=True),
                         allowedActions=["local_checks", "build_preview", "prepare_offer"],
                         acceptance=[dict(id="criterion", title="File contains the agreed outcome.", done=True)],
                         offer=dict(title="Reviewed recovery fixture", customer="Synthetic buyer",
                                    scope="One synthetic HTML file; no real sale.", amountMinor=1000)))
        self.update({"accepted": True})
        self.build_key = uuid.uuid4().hex
        build, self.build_body = self.act("build_preview", key=self.build_key)
        self.asset_id = build["assetId"]
        result = self.write(self.project_route("/members"),
                            dict(expectedVersion=self.project["version"], username="recovery-reviewer", role="editor"))
        self.project = result["project"]
        self.release_key = uuid.uuid4().hex
        released, self.release_body = self.act("release", key=self.release_key)
        release = released["result"]
        self.release_id = release["id"]
        result = self.write(self.project_route("/release-review"),
                            dict(expectedVersion=self.project["version"], releaseId=self.release_id,
                                 criteria=[dict(id="criterion", passed=True, evidence="Synthetic test checks the saved artifact.")],
                                 note="Only a regression fixture; no independent real-world acceptance."),
                            person="reviewer")
        self.project = result["project"]
        draft = self.act("create_order")[0]["result"]
        result = self.write(self.project_route("/commerce"),
                            dict(expectedVersion=self.project["version"], draftOrderId=draft["id"],
                                 releaseId=self.release_id, buyerUsername="recovery-buyer",
                                 confirmedAmountMinor=1000, confirmedCurrency="USD", sharingAcknowledged=True))
        self.order = result["order"]

    def checkout(self, key=None):
        return self.store.commerce.execute("commerce/orders/" + self.order["id"] + "/checkout",
                                           self.people["buyer"], {}, key or uuid.uuid4().hex)

    def refund(self, key=None):
        return self.store.commerce.execute("commerce/orders/" + self.order["id"] + "/refund",
                                           self.people["merchant"], {"targetRefundMinor": 400},
                                           key or uuid.uuid4().hex)

    def event(self, kind, item):
        return dict(id="evt_" + uuid.uuid4().hex, object="event", type=kind,
                    api_version=API_VERSION, livemode=False, data={"object": item})

    def webhook(self, event):
        raw = json.dumps(event, separators=(",", ":")).encode()
        stamp = str(int(time.time()))
        signature = hmac.new(self.config.webhook_secret.encode(), stamp.encode() + b"." + raw, hashlib.sha256).hexdigest()
        return self.store.commerce.webhook(raw, "t=" + stamp + ",v1=" + signature)

    def paid(self):
        self.checkout()
        session = self.provider.settle(self.order["id"])
        event = self.event("checkout.session.completed", session)
        self.webhook(event)
        return event

    def restore_snapshot(self):
        target = self.base / ("restored-" + uuid.uuid4().hex + ".sqlite3")
        checksum = backup(self.store.path, target)
        result = verifier.drill(target, checksum)
        self.assertTrue(result["core_schema_checked"])
        self.store = Store(target, self.config, self.provider)

    def test_lost_checkout_retries_the_original_provider_operation_after_restore(self):
        key = uuid.uuid4().hex
        self.provider.lose_checkout = True
        with self.assertRaises(Fault) as failed:
            self.checkout(key)
        self.assertEqual(failed.exception.code, "checkout_unknown")
        self.restore_snapshot()
        resumed = self.checkout(key)
        replayed = self.checkout(key)
        self.assertTrue(replayed["replayed"])
        self.assertEqual(resumed["url"], replayed["url"])
        self.assertEqual(self.checkout()["url"], resumed["url"])
        self.assertEqual(self.provider.checkout_creates, 1)
        with self.store.connect() as db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM commerce_checkout_ops").fetchone()[0], 1)

    def test_lost_refund_and_webhook_replay_do_not_duplicate_after_restore(self):
        paid_event = self.paid()
        key = uuid.uuid4().hex
        self.provider.lose_refund = True
        with self.assertRaises(Fault) as failed:
            self.refund(key)
        self.assertEqual(failed.exception.code, "refund_unknown")
        self.restore_snapshot()
        self.refund(key)
        self.refund(key)
        self.assertEqual(self.provider.refund_creates, 1)
        self.assertTrue(self.webhook(paid_event)["replayed"])
        refund_event = self.event("refund.updated", next(iter(self.provider.refunds.values())))
        self.webhook(refund_event)
        self.restore_snapshot()
        self.assertTrue(self.webhook(refund_event)["replayed"])
        with self.store.connect() as db:
            order = db.execute("SELECT paid_minor,refunded_minor FROM commerce_orders WHERE id=?", (self.order["id"],)).fetchone()
            self.assertEqual(tuple(order), (1000, 400))
            self.assertEqual(db.execute("SELECT COUNT(*) FROM commerce_entitlements").fetchone()[0], 1)
            self.assertEqual(db.execute("SELECT COUNT(*) FROM commerce_refund_ops").fetchone()[0], 1)

    def test_expired_unknown_checkout_requires_reconciliation_after_restore(self):
        self.provider.lose_checkout = True
        with self.assertRaises(Fault):
            self.checkout()
        with self.store.transaction() as db:
            db.execute("UPDATE commerce_checkout_ops SET started_at=?", (time.time() - RETRY_WINDOW - 5,))
        self.restore_snapshot()
        with self.assertRaises(Fault) as failed:
            self.checkout()
        self.assertEqual(failed.exception.code, "reconciliation_required")
        self.assertEqual(self.provider.checkout_creates, 1)

    def test_expired_unknown_refund_requires_reconciliation_after_restore(self):
        self.paid()
        self.provider.lose_refund = True
        with self.assertRaises(Fault):
            self.refund()
        with self.store.transaction() as db:
            db.execute("UPDATE commerce_refund_ops SET started_at=?", (time.time() - RETRY_WINDOW - 5,))
        self.restore_snapshot()
        with self.assertRaises(Fault) as failed:
            self.refund()
        self.assertEqual(failed.exception.code, "reconciliation_required")
        self.assertEqual(self.provider.refund_creates, 1)

    def test_restored_build_and_internal_release_replay_keep_one_result(self):
        self.restore_snapshot()
        built = self.write(self.project_route("/actions"), self.build_body, key=self.build_key)
        released = self.write(self.project_route("/actions"), self.release_body, key=self.release_key)
        self.assertTrue(built["replayed"])
        self.assertTrue(released["replayed"])
        self.assertEqual(built["assetId"], self.asset_id)
        self.assertEqual(released["result"]["id"], self.release_id)
        with self.store.connect() as db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM assets").fetchone()[0], 1)
            self.assertEqual(db.execute("SELECT COUNT(*) FROM events WHERE kind='release'").fetchone()[0], 1)
        # Core has no external publishing adapter; it must stay rejected after recovery.
        with self.assertRaises(Fault) as failed:
            self.act("publish")
        self.assertEqual(failed.exception.status, 422)
        self.assertEqual(self.provider.checkout_creates, 0)


if __name__ == "__main__":
    unittest.main()
