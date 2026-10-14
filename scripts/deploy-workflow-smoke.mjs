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
assert.ok(packageJson.scripts?.['qa:deploy-workflow'] === 'node scripts/deploy-workflow-smoke.mjs', 'Package script must expose the deploy workflow contract test')
assert.ok(workflow.includes('Verify host-managed API from frontend container') && workflow.includes('http://$host_gateway:4317/health'), 'Deployment must verify the host-managed API through the active Docker gateway')
assert.ok(activation.includes('api_gateway=') && activation.includes('__OSGARD_HOST_GATEWAY__') && activation.includes('Unresolved OSGARD host-gateway placeholder'), 'Activation must replace the API gateway placeholder using the current container network')
assert.ok(activation.includes("<title>OSA Intelligence") && activation.includes('OSA INTELLIGENCE / BEYOND THE MODEL'), 'Activation must validate the actual OSA HTML and JavaScript bundle from the public domain')
assert.ok(nginx.includes('location = /index.html') && nginx.includes('no-store, no-cache, must-revalidate, proxy-revalidate'), 'HTML shell must not be cached separately from versioned assets')
assert.ok(!workflow.includes('echo "$DEPLOY_KEY"'), 'Workflow must not print the private key')

console.log('PASS deployment workflow: required secrets, safe key handling, SSH timeout and actionable diagnostics')
