"""CI gateway pacing uses the shipped bridge and probe, without sockets or sleeps."""
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


gateway = load('inherit_gateway_pacing', 'core-inherit-gateway-smoke.py')
contract = load('inherit_gateway_original_contract', 'core-inherit-live-smoke.py')


class Clock:
    def __init__(self):
        self.value = 0.0
        self.waits = []

    def __call__(self):
        return self.value

    def sleep(self, seconds):
        self.waits.append(seconds)
        self.value += seconds


class Response:
    status = 200

    def read(self, limit):
        return b'{"loggedOut":true}'[:limit]

    def getheader(self, name, default=''):
        return {'Content-Type': 'application/json', 'Cache-Control': 'no-store'}.get(name, default)


def fixture(clock, outcomes=()):
    events, connections = [], []
    outcomes = list(outcomes)

    class Connection:
        def __init__(self, host, port, *, timeout):
            self.host, self.port, self.timeout, self.closed = host, port, timeout, False
            connections.append(self)

        def request(self, method, path, body=None, headers=None, **kwargs):
            events.append(dict(at=clock(), method=method, path=path, body=body, headers=headers))
            if outcomes:
                outcome = outcomes.pop(0)
                if isinstance(outcome, Exception):
                    raise outcome

        def getresponse(self):
            return Response()

        def close(self):
            self.closed = True

    return gateway.connection_factory(4173, clock=clock, sleep=clock.sleep, connection_type=Connection), events, connections


class GatewayPacingTest(unittest.TestCase):
    def test_shared_pacing_covers_new_connections_and_preserves_requests(self):
        clock = Clock()
        factory, events, connections = fixture(clock)
        calls = [('GET', '/api/core/health'), ('POST', contract.API + 'worlds'),
                 ('GET', contract.API + 'worlds'), ('POST', '/api/core/auth/logout')]
        for method, path in calls:
            connection = factory('osgard.world', timeout=5)
            connection.request(method, path, b'{}', {'Idempotency-Key': 'fixture-key', 'Host': 'wrong-host'})
            connection.close()
        self.assertEqual([event['at'] for event in events], [0, 0.25, 0.5, 0.75])
        self.assertEqual([(event['method'], event['path']) for event in events], calls)
        self.assertTrue(all(event['headers'] == {'Idempotency-Key': 'fixture-key', 'Host': 'osgard.world'} for event in events))
        self.assertTrue(all(event['body'] == b'{}' for event in events))
        self.assertTrue(all((c.host, c.port, c.closed) == ('127.0.0.1', 4173, True) for c in connections))
        with self.assertRaises(ValueError):
            factory('another-host', timeout=5)
        self.assertEqual(len(connections), len(calls))

    def test_elapsed_response_time_needs_no_additional_delay(self):
        clock = Clock()
        factory, events, _ = fixture(clock)
        factory('osgard.world', timeout=5).request('GET', '/api/core/health')
        clock.value = 3
        factory('osgard.world', timeout=5).request('GET', '/api/core/health')
        self.assertEqual([event['at'] for event in events], [0, 3])
        self.assertEqual(clock.waits, [])

    def test_overall_deadline_stops_before_post_and_cleanup_retains_its_bounded_budget(self):
        clock = Clock()
        factory, events, connections = fixture(clock)
        with patch.object(contract.time, 'monotonic', clock):
            probe = contract.Probe(factory)
            probe.request('GET', contract.API + 'worlds')
            probe.deadline = clock() + 0.1
            with self.assertRaises(TimeoutError):
                probe.request('POST', contract.API + 'worlds', body={'title': 'never dispatched'}, key='fixture-key')
            self.assertEqual(len(events), 1)
            self.assertEqual(clock.waits, [])
            probe.tokens = ['first-fixture-token', 'next-fixture-token']
            probe.cleanup()
            probe.cleanup()
        self.assertEqual([event['path'] for event in events], [contract.API + 'worlds', '/api/core/auth/logout', '/api/core/auth/logout'])
        self.assertEqual([event['at'] for event in events], [0, 0.25, 0.5])
        self.assertTrue(probe.report['allQaSessionsLoggedOut'])
        self.assertTrue(all(c.closed for c in connections))
        self.assertEqual([c.timeout for c in connections][-2:], [5, 5])

    def test_uncertain_post_is_not_retried_and_cleanup_is_still_paced(self):
        clock = Clock()
        factory, events, _ = fixture(clock, [OSError('synthetic response loss')])
        with patch.object(contract.time, 'monotonic', clock):
            probe = contract.Probe(factory)
            probe.tokens.append('private-fixture-token')
            with self.assertRaises(OSError):
                probe.request('POST', contract.API + 'worlds', token=probe.tokens[0], key='fixture-key', body={'title': 'fixture'})
            probe.cleanup()
        self.assertEqual([(event['at'], event['path']) for event in events], [(0, contract.API + 'worlds'), (0.25, '/api/core/auth/logout')])
        self.assertEqual(probe.report['requests'][0]['outcome'], 'uncertain')
        self.assertTrue(probe.report['allQaSessionsLoggedOut'])
        self.assertNotIn('private-fixture-token', json.dumps(probe.report))


if __name__ == '__main__':
    unittest.main()
