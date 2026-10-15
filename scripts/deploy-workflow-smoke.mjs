import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const workflow = readFileSync('.github/workflows/deploy-frontend.yml', 'utf8')
const packageJson = JSON.parse(readFileSync('package.json', 'utf8'))
const activation = readFileSync('scripts/activate-frontend-remote.sh', 'utf8')
const nginx = readFileSync('nginx.conf', 'utf8')

for (const secret of ['OSGARD_DEPLOY_HOST', 'OSGARD_DEPLOY_USER', 'OSGARD_DEPLOY_KEY']) {
  assert.ok(workflow.includes(`secrets.${secret}`), `Deployment workflow must use ${secret}`)
  assert.ok(workflow.includes(`Missing GitHub Actions secret ${secret}`), `Missing-secret error must name ${secret}`)
}

assert.ok(workflow.includes("grep -q -- 'PRIVATE KEY'"), 'Workflow must reject a key value that does not look like a private SSH key')
assert.ok(workflow.includes('ssh-keyscan -T 10 -H "$DEPLOY_HOST"'), 'SSH host-key scan must have a finite timeout')
assert.ok(workflow.includes('Could not read the SSH host key'), 'SSH host-key failure must provide actionable diagnostics')
assert.ok(workflow.includes("printf '%s\\n' \"$DEPLOY_KEY\" > ~/.ssh/osgard_deploy"), 'SSH key must be written with a trailing newline')
assert.ok(workflow.includes('npm run qa:deploy-workflow'), 'Deploy workflow must run its own static contract test before deployment')
assert.ok(workflow.includes("cancel-in-progress: ${{ contains(github.event.head_commit.message, '[supersede]') }}"), 'Recovery deploys must be able to cancel a stale recovery run')
assert.ok(workflow.includes("group: osgard-frontend-deploy") && !workflow.includes("osgard-frontend-deploy-recovery"), "Supersede deployments must share the default concurrency group so they can cancel stale regular releases");
assert.ok(workflow.includes("id: godot-export-cache") && workflow.includes("path: public/games/null-shift-godot"), 'Deployment must cache the actual generated Godot Web export')
assert.ok(workflow.includes("hashFiles('godot/null-shift/**', 'scripts/null-shift-godot-smoke.mjs')"), 'Godot export cache must invalidate when game sources or export validation changes')
assert.ok(workflow.includes("if: ${{ steps.godot-export-cache.outputs.cache-hit != 'true' && !contains(github.event.head_commit.message, '[supersede]') }}"), 'Godot engine cache must only be needed when there is no reusable Web export')
for (const step of ['Verify Godot installation','Import and parse the Godot project','Runtime-smoke gameplay state transitions in headless Godot','Export Godot Web game']) {
  const start = workflow.indexOf('- name: ' + step)
  assert.ok(start >= 0 && workflow.slice(start, start + 220).includes("steps.godot-export-cache.outputs.cache-hit != 'true'"), step + ' must be skipped only when a source-matched Web export has been restored')
}
assert.ok(!workflow.includes('godot-changes'), 'Deploy must not infer reusable binary assets from unchanged source alone')
assert.ok(workflow.includes('REMOTE_RELEASE_DIR="/tmp/osgard-gh-release-${GITHUB_RUN_ID}"'), 'Each deploy must stage its archive in a unique run-scoped directory')
assert.ok(workflow.includes('REMOTE_SCRIPT="/tmp/activate-frontend-remote-${GITHUB_RUN_ID}.sh"'), 'Each deploy must use its own activation script path')
assert.ok(packageJson.scripts?.['qa:deploy-workflow'] === 'node scripts/deploy-workflow-smoke.mjs', 'Package script must expose the deploy workflow contract test')
assert.ok(workflow.includes('Verify host-managed API from frontend container') && workflow.includes('http://$host_gateway:4317/health'), 'Deployment must verify the host-managed API through the active Docker gateway')
assert.ok(activation.includes('api_gateway=') && activation.includes('__OSGARD_HOST_GATEWAY__') && activation.includes('Unresolved OSGARD host-gateway placeholder'), 'Activation must replace the API gateway placeholder using the current container network')
assert.ok(activation.includes("<title>OSA Intelligence") && activation.includes('OSA INTELLIGENCE / BEYOND THE MODEL'), 'Activation must validate the actual OSA HTML and JavaScript bundle from the public domain')
assert.ok(nginx.includes('location = /index.html') && nginx.includes('no-store, no-cache, must-revalidate, proxy-revalidate'), 'HTML shell must not be cached separately from versioned assets')
assert.ok(!workflow.includes('echo "$DEPLOY_KEY"'), 'Workflow must not print the private key')

console.log('PASS deployment workflow: required secrets, safe key handling, SSH timeout and actionable diagnostics')
