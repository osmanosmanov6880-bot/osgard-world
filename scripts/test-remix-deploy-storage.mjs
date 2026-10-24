#!/usr/bin/env node
// Regression for the Docker ENOSPC incident. Never contacts production.
// Validate the *actual workflow source* order and safety boundaries.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {spawnSync} from 'node:child_process';
const file=process.argv[2]||'.github/workflows/deploy-remix-arena-static.yml';
const s=fs.readFileSync(file,'utf8');
function position(token){const p=s.indexOf(token);assert.ok(p>=0,'missing deployment safety step: '+token);return p;}
const lock=position('flock -w 420 9');
const cleanup=position('REMIX_OWN_STAGING_CLEANUP');
const preflight=position('REMIX_STORAGE_PREFLIGHT');
const copy=position('if ! docker cp game');
const activation=position('destination=/usr/share/nginx/html/games/remix/arena-v2');
const comparator=position('nebula-r37-report-verify.html');
const cleanBackup=position('if [ -d "$backup" ]; then rm -rf -- "$backup"; fi');
const success=position('REMIX ARENA and optional NEBULA R37 verified');
assert.ok(lock<cleanup&&cleanup<preflight&&preflight<copy&&copy<activation,
 'staging cleanup and disk checks must run while lock held and before copy');
assert.ok(activation<comparator&&comparator<cleanBackup&&cleanBackup<success,
 'remove rollback copy only after successful Nginx / report route healthchecks');
assert.match(s,/for old in \/tmp\/remix-arena-candidate-\[0-9\]\* \/tmp\/remix-arena-previous-\[0-9\]\*/);
assert.match(s,/case "\$old" in[\s\S]{0,320}\/tmp\/remix-arena-candidate-\[0-9\]\*/);
assert.match(s,/rm -rf -- "\$old"/);
assert.match(s,/REMIX_STORAGE_ERROR: insufficient container disk; retained active game/);
assert.match(s,/rm -rf -- "\/tmp\/remix-arena-candidate-\$RELEASE_ID"/);
assert.match(s,/REMIX_COPY_ERROR: cleaned only incomplete own candidate; live game untouched/);
assert.match(s,/NEBULA R37 performance-report route failed; previous game restored/);
assert.match(s,/No\w* unsafe activation lock symlink|Unsafe activation lock symlink/);
assert.match(s,/if \[ -d "\$backup" \]; then mv "\$backup" "\$destination"; fi/);
assert.ok(!s.includes('docker system prune'),
 'must never prune unrelated projects or the Docker daemon');
assert.ok(!s.includes('docker volume prune'),
 'must never prune persistent volumes or saves');
assert.ok(!s.includes('rm -rf /usr/share/nginx/html'),
 'must never delete the root production web directory');
const start=s.indexOf("<<'REMOTE'\n"),end=s.indexOf("\n          REMOTE",start);
assert.ok(start>0&&end>start,'missing remote deployment script heredoc');
const shell=s.slice(start+"<<'REMOTE'\n".length,end);
const syntax=spawnSync('sh',['-n'],{input:shell,encoding:'utf8'});
assert.equal(syntax.status,0,'production remote shell syntax invalid: '+syntax.stderr);
console.log('REMIX_DEPLOY_STORAGE_SAFETY_SUCCESS own staging only, disk preflight, rollback, R37 route and sh syntax');
