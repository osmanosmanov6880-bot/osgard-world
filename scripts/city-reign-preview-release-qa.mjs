import test from 'node:test'
import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'
import {spawnSync} from 'node:child_process'

const remote=readFileSync('scripts/city-reign-preview-remote.sh','utf8')
const manifest=readFileSync('scripts/city-reign-preview-manifest.py','utf8')
const fullSite=readFileSync('scripts/activate-frontend-remote.sh','utf8')
const preserve=readFileSync('scripts/preserve-omega-native.sh','utf8')
const nginx=readFileSync('nginx.conf','utf8')

test('native preview packager runs original WebGL archive provenance and adversarial self tests',()=>{
  const r=spawnSync('python3',
    ['scripts/city-reign-preview-manifest.py','--self-test'],
    {encoding:'utf8',timeout:12000})
  assert.equal(r.status,0,r.stderr || r.stdout)
  assert.match(r.stdout,/PASS: CITY REIGN source-locked native preview manifest/)
  for(const code of ['res://scenes/main.tscn','Godot 4.4.1',
    'native-Godot-HTML5-export','index.wasm','index.pck','SHA256SUMS.txt',
    'public-technical-preview','commercial_aaa_release']){
    assert.ok(manifest.includes(code),'missing manifest contract '+code)
  }
  assert.match(manifest,/index[.]js[?]v=/)
})

test('SSH server deploy has valid Bash, exact run/sha checks and ONE isolated target',()=>{
  const r=spawnSync('bash',['-n','scripts/city-reign-preview-remote.sh'],
    {encoding:'utf8',timeout:8000})
  assert.equal(r.status,0,r.stderr || r.stdout)
  assert.match(remote,/^set -euo pipefail/m)
  assert.match(remote,/osgard-frontend-activation[.]lock/)
  assert.match(remote,/flock -w 120 9/)
  assert.match(remote,/sha256sum -c SHA256SUMS[.]txt/)
  assert.match(remote,/CITY_REIGN_PREVIEW_ACTIVATED/)
  assert.match(remote,/CITY_REIGN_PREVIEW_ROLLBACK/)
  assert.match(remote,/CITY_REIGN_PREVIEW_FINALIZED/)
  assert.match(remote,/.city-reign-preview-backup/)
  assert.match(remote,/.city-reign-preview-candidate/)
  assert.ok(!/\bgit push\b|docker (?:rm|prune)|systemctl restart/.test(remote))
  assert.equal((remote.match(/game_root="\/usr\/share\/nginx\/html\/games"/g)||[]).length,1)
  assert.equal((remote.match(/target="\$\{game_root\}\/city-reign-preview"/g)||[]).length,1)
  assert.ok(!remote.includes('target="${game_root}/omega-3d-preview"'))
})

test('full-site frontend swaps preserve independently deployed preview and old Omega',()=>{
  const omega='sh /tmp/osgard-gh-next/preserve-omega-native.sh /usr/share/nginx/html/games/omega-3d-preview /tmp/osgard-gh-next/html/games/omega-3d-preview'
  const preview='sh /tmp/osgard-gh-next/preserve-omega-native.sh /usr/share/nginx/html/games/city-reign-preview /tmp/osgard-gh-next/html/games/city-reign-preview'
  const swap='mv /usr/share/nginx/html /tmp/osgard-gh-previous'
  const base=fullSite.indexOf(omega)
  const protectedPreview=fullSite.indexOf(preview)
  const cutover=fullSite.indexOf(swap)
  assert.ok(base>0 && protectedPreview>base && cutover>protectedPreview,
    'SSH must NOT ship a game erased by next platform-wide frontend release')
  assert.ok(fullSite.includes(
    'cd /usr/share/nginx/html/games/city-reign-preview && sha256sum -c SHA256SUMS.txt'))
  assert.match(preserve,/SHA256SUMS[.]txt/)
  assert.match(preserve,/cp -a "\$active" "\$stage"/)
  assert.match(nginx,/location \/ \{/)
  assert.match(nginx,/try_files \$uri \$uri\/ \/index[.]html;/)
  assert.match(nginx,/location ~\* .*wasm.*pck/)
})

test('source candidate cannot silently publish on master, on a PR, or on superseding SHA',()=>{
  const path='.github/workflows/city-reign-preview-isolated-ssh.yml'
  const workflow=readFileSync(path,'utf8')
  assert.match(workflow,/\bpush:/)
  assert.match(workflow,/feat\/city-reign-aaa-world-quality-gate-20261028/)
  assert.match(workflow,/\[publish-city-reign-preview\]/)
  assert.match(workflow,/github[.]repository == 'osmanosmanov6880-bot\/osgard-world'/)
  assert.match(workflow,/persist-credentials: false/)
  assert.match(workflow,/permissions:\s*\n\s*contents: read/)
  assert.match(workflow,/source SHA and no master release/i)
  assert.match(workflow,/scripts\/city-reign-preview-manifest[.]py/)
  assert.match(workflow,/scripts\/city-reign-preview-remote[.]sh/)
  assert.match(workflow,/scripts\/omega-live-integrity[.]py/)
  assert.match(workflow,/rollback/)
  assert.match(workflow,/sha256sum -c SHA256SUMS[.]txt/)
  assert.ok(!/^\s*workflow_run:/m.test(workflow),'never SSH-deploy on unrelated workflow')
  assert.ok(!/^\s*pull_request:/m.test(workflow),'never expose SSH secrets to PR refs')
  assert.ok(!/git push.*master|gh workflow run.*deploy-frontend/.test(workflow))
  assert.ok(!workflow.includes('/games/omega-3d-preview --nonce'),
    'must attest isolated preview only, not overwrite canonical existing game')
})
