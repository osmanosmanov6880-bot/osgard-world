#!/usr/bin/env python3
"""Real REMIX browser regressions, including deliberately unavailable/faulted local services."""
import argparse
import functools
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'server'))
import core_commerce
from core_server import Handler, create_server
from remix_acceptance import register


class LostResponseHandler(Handler):
    """Drop one response after the real operation transaction has already committed."""
    def output(self, value, status=200):
        target = self.server.drop_target
        matches_target = self.path.endswith('/input') if target == 'input' else self.path == '/api/core/remix/v1/' + target
        if self.command == 'POST' and matches_target and status == 200 and self.server.drop_response:
            self.server.drop_response = False
            self.server.dropped_entity_id = value.get('id') or value.get('state', {}).get('id')
            self.close_connection = True
            try: self.connection.shutdown(socket.SHUT_RDWR)
            except OSError: pass
            return
        super().output(value, status)


class TransientStateHandler(Handler):
    """A real local HTTP 503 on the first restore read; subsequent reads use SQLite."""
    def api(self, method):
        if method == 'GET' and self.path.startswith('/api/core/remix/v1/matches/') and self.path.endswith('/state') and self.server.fail_state_read:
            self.server.fail_state_read = False
            # Keep the read in flight briefly so the browser also checks that
            # startup cannot enable a new match between challenge and state.
            threading.Event().wait(0.3)
            self.output(dict(error='storage_unavailable', message='Тестовое временное хранилище недоступно.'), 503)
            return
        super().api(method)


class SlowStateHandler(Handler):
    """Delay an actual SQLite snapshot, without altering its payload."""
    def output(self, value, status=200):
        if self.command == 'GET' and self.path.endswith('/state') and status == 200:
            threading.Event().wait(self.server.state_response_delay)
        super().output(value, status)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dist', type=Path, default=ROOT / 'dist')
    parser.add_argument('--out', type=Path, default=ROOT / 'test-results/remix-ui')
    parser.add_argument('--only', choices=['poll'], help='Run only the two delayed-read/touch regressions')
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    if not (args.dist / 'games/remix/arena/remix-client.js').is_file():
        raise SystemExit('Build the REMIX UI before this browser acceptance.')
    servers, report, code = [], dict(schemaVersion=1, status='failed', passed=0, failed=1), 1
    try:
        with tempfile.TemporaryDirectory(prefix='osgard-remix-ui-') as temporary:
            bases = {}
            for name in ('normal', 'disabled', 'incompatible', 'lost-response', 'lost-create', 'lost-match', 'state-retry', 'state-reload', 'poll-touch', 'poll-rematch'):
                server = create_server(args.dist, Path(temporary) / (name + '.sqlite3'), port=0, commerce_config=core_commerce.Config(enabled=False), enable_remix=name != 'disabled')
                if name == 'incompatible':
                    # Negative compatibility fixture only. It cannot play matches
                    # through this UI, and is never used for a passing game flow.
                    advertised = server.store.remix.capabilities()
                    server.store.remix.capabilities = lambda advertised=advertised: dict(advertised, ruleset='deliberately-unsupported-test-ruleset')
                if name.startswith('lost-'):
                    server.drop_response = True
                    server.drop_target = {'lost-response': 'input', 'lost-create': 'challenges', 'lost-match': 'matches'}[name]
                    server.RequestHandlerClass = functools.partial(LostResponseHandler, directory=str(args.dist.resolve()))
                if name.startswith('state-'):
                    server.fail_state_read = True
                    server.RequestHandlerClass = functools.partial(TransientStateHandler, directory=str(args.dist.resolve()))
                if name.startswith('poll-'):
                    server.state_response_delay = .6 if name == 'poll-touch' else 3
                    server.RequestHandlerClass = functools.partial(SlowStateHandler, directory=str(args.dist.resolve()))
                thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
                servers.append((name, server, thread))
                bases[name] = 'http://127.0.0.1:' + str(server.server_address[1])
            actor = register(bases['lost-response'])
            environment = dict(os.environ, OSGARD_REMIX_UI_BASES=json.dumps(bases), OSGARD_REMIX_UI_RETRY_TOKEN=actor.token)
            command = ['node', str(ROOT / 'scripts/remix-ui-regressions.mjs'), '--out', str(args.out.resolve())]
            if args.only: command.extend(['--only', args.only])
            process = subprocess.run(command, cwd=ROOT, env=environment, check=False)
            report = json.loads((args.out / 'report.json').read_text())
            code = process.returncode
            retry_server = next(server for name, server, _ in servers if name == 'lost-response')
            with retry_server.store.connect() as db:
                inputs = db.execute('SELECT COUNT(*) FROM remix_inputs').fetchone()[0]
                operations = db.execute('SELECT COUNT(*) FROM remix_operations').fetchone()[0]
            if code != 0 or report['status'] != 'passed' or not args.only and (inputs != 1 or operations != 3):
                raise AssertionError('Browser regressions or exactly-once SQLite input binding failed.')
            if not args.only: report['sqliteProof'] = dict(inputRows=inputs, operationRows=operations, droppedAfterCommit=True)
            report['authRecoveryProof'] = []
            for name in (() if args.only else ('lost-create', 'lost-match')):
                server = next(server for candidate, server, _ in servers if candidate == name)
                with server.store.connect() as db:
                    challenges = db.execute('SELECT id FROM remix_challenges').fetchall()
                    matches = db.execute('SELECT id,challenge_id FROM remix_matches').fetchall()
                    operations = db.execute('SELECT COUNT(*) FROM remix_operations').fetchone()[0]
                recovered = next(check['recoveredEntityId'] for check in report['checks'] if check['name'] == name + '-reauth-preserves-operation')
                if len(challenges) != 1 or len(matches) != 1 or operations != 2 or recovered != server.dropped_entity_id:
                    raise AssertionError('Reauthentication duplicated or replaced a committed entity.')
                report['authRecoveryProof'].append(dict(operation=name, challengeRows=1, matchRows=1, operationRows=2, sameCommittedEntity=True))
            report['readRecoveryProof'] = []
            for name in (() if args.only else ('state-retry', 'state-reload')):
                server = next(server for candidate, server, _ in servers if candidate == name)
                with server.store.connect() as db:
                    matches = db.execute('SELECT id FROM remix_matches').fetchall()
                original = next(check['recoveredEntityId'] for check in report['checks'] if check['name'] == name + '-keeps-confirmed-run')
                if len(matches) != 1 or matches[0]['id'] != original:
                    raise AssertionError('A transient state read created or substituted a run.')
                report['readRecoveryProof'].append(dict(recovery=name, matchRows=1, sameConfirmedRun=True))
            report['pollProof'] = []
            for name, expected_runs in (('poll-touch', 1), ('poll-rematch', 2)):
                server = next(server for candidate, server, _ in servers if candidate == name)
                with server.store.connect() as db:
                    runs = db.execute('SELECT id,state_json FROM remix_matches').fetchall()
                    inputs = db.execute('SELECT COUNT(*) FROM remix_inputs').fetchone()[0]
                if len(runs) != expected_runs or inputs < 1:
                    raise AssertionError('Delayed-read browser regression did not create the expected real runs/inputs.')
                report['pollProof'].append(dict(scenario=name, matchRows=len(runs), inputRows=inputs, realSnapshotsDelayed=True))
    except Exception as error:
        code = 1
        report.update(status='failed', failed=max(1, report.get('failed', 0)), error=str(error))
    finally:
        for _, server, thread in servers:
            try:
                try: server.shutdown()
                finally:
                    try: thread.join(5)
                    finally: server.server_close()
            except Exception as error:
                code = 1
                report.update(status='failed', failed=max(1, report.get('failed', 0)), error='Local server cleanup failed: ' + str(error))
    (args.out / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(f"REMIX UI regressions: {report['status']} ({report['passed']} passed, {report['failed']} failed)")
    return code


if __name__ == '__main__':
    raise SystemExit(main())
