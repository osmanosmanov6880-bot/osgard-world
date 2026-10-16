import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const workflow = readFileSync('.github/workflows/deploy-frontend.yml', 'utf8')
const packageJson = JSON.parse(readFileSync('package.json', 'utf8'))
const activation = readFileSync('scripts/activate-frontend-remote.sh', 'utf8')
const homepage = readFileSync('index.html', 'utf8')
const healthWorkflow = readFileSync('.github/workflows/production-health-watch.yml', 'utf8')
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
assert.ok(workflow.includes('npm run qa:core-api'), 'Deploy workflow must run Core API and SQLite regressions before deployment')
assert.ok(workflow.includes("cancel-in-progress: ${{ contains(github.event.head_commit.message, '[supersede]') }}"), 'Recovery deploys must be able to cancel a stale recovery run')
assert.ok(workflow.includes("group: osgard-frontend-deploy") && !workflow.includes("osgard-frontend-deploy-recovery"), "Supersede deployments must share the default concurrency group so they can cancel stale regular releases");
assert.ok(workflow.includes("id: godot-changes") && workflow.includes("git diff --quiet HEAD^ HEAD -- godot/null-shift/ public/games/null-shift-godot/ scripts/null-shift-godot-smoke.mjs"), 'Static-only releases must detect whether Godot sources actually changed')
assert.ok(workflow.includes("fetch-depth: 2"), 'Deployment checkout must include the parent commit for path-aware Godot rebuild detection')
assert.ok(workflow.includes("if: ${{ steps.godot-changes.outputs.changed == 'true' && !contains(github.event.head_commit.message, '[supersede]') }}"), 'Godot cache must only run for game changes and must retain the supersede fallback policy')
for (const step of ['Verify Godot installation','Import and parse the Godot project','Runtime-smoke gameplay state transitions in headless Godot','Export Godot Web game']) {
  const start = workflow.indexOf('- name: ' + step)
  assert.ok(start >= 0 && workflow.slice(start, start + 220).includes("steps.godot-changes.outputs.changed == 'true'"), step + ' must be conditional on Godot source changes')
}
assert.ok(workflow.includes('REMOTE_RELEASE_DIR="/tmp/osgard-gh-release-${GITHUB_RUN_ID}"'), 'Each deploy must stage its archive in a unique run-scoped directory')
assert.ok(workflow.includes('REMOTE_SCRIPT="/tmp/activate-frontend-remote-${GITHUB_RUN_ID}.sh"'), 'Each deploy must use its own activation script path')
assert.ok(packageJson.scripts?.['qa:deploy-workflow'] === 'node scripts/deploy-workflow-smoke.mjs', 'Package script must expose the deploy workflow contract test')
assert.ok(workflow.includes('Verify host-managed API from frontend container') && workflow.includes('http://$host_gateway:4317/health'), 'Deployment must verify the host-managed API through the active Docker gateway')
assert.ok(activation.includes('api_gateway=') && activation.includes('__OSGARD_HOST_GATEWAY__') && activation.includes('Unresolved OSGARD host-gateway placeholder'), 'Activation must replace the API gateway placeholder using the current container network')
assert.ok(homepage.includes('<meta name="osgard-app" content="osgard-ecosystem"'), 'Homepage must expose the OSGARD ecosystem identity marker')
assert.ok(healthWorkflow.includes('workflow_run:') && healthWorkflow.includes('workflows: ["OSGARD frontend deploy"]') && healthWorkflow.includes('types: [completed]') && !healthWorkflow.includes('\n  push:\n'), 'Production health checks must run after deploy, not race the push-triggered deploy')
assert.ok(activation.includes('<title>OSGARD WORLD — цифровые продукты, построенные как системы</title>') && activation.includes("grep -q 'OSGARD WORLD'"), 'Activation must validate the OSGARD root identity and JavaScript bundle')
assert.ok(activation.includes('core-api-image.tar.gz') && activation.includes('--network-alias core-api') && activation.includes('/api/core/health'), 'Activation must deploy, health-check and publish the Core API alongside the frontend')
assert.ok(activation.includes('label=com.docker.compose.volume=osgard-core-data') && activation.includes('Multiple OSGARD Core data volumes exist'), 'Activation must preserve a single existing Core volume and refuse ambiguous data selection')
assert.ok(workflow.includes('docker build --pull -f server/Dockerfile') && workflow.includes('docker save osgard-core-api:${GITHUB_SHA}'), 'Release archive must contain the versioned Core API image')
assert.equal((activation.match(/name="osgard-app" content="osgard-ecosystem"/g) ?? []).length, 2, 'Activation must check the OSGARD identity in both candidate and live HTML')
assert.ok(nginx.includes('location = /index.html') && nginx.includes('no-store, no-cache, must-revalidate, proxy-revalidate'), 'HTML shell must not be cached separately from versioned assets')
assert.ok(!workflow.includes('echo "$DEPLOY_KEY"'), 'Workflow must not print the private key')

assert.ok(workflow.includes('Preserve Godot Web export for static-only releases'), 'Static-only deploys must preserve generated Godot artifacts instead of deleting them')
assert.ok(workflow.includes("steps.godot-changes.outputs.changed == 'false'") && workflow.includes('/tmp/osgard-gh-previous/games/null-shift-godot'), 'Static-only recovery must fall back to the prior verified Godot export when the active release is incomplete')
assert.ok(workflow.includes('node scripts/null-shift-godot-smoke.mjs --export-check "$TEMP_DIR/unpacked/html/games/null-shift-godot"'), 'Preserved Godot export must be validated before archive re-creation')
assert.ok(workflow.indexOf('Preserve Godot Web export for static-only releases') < workflow.indexOf('Stage archive and verify checksum'), 'Preserved export must be included before the release archive checksum is created')

console.log('PASS deployment workflow: required secrets, safe key handling, SSH timeout and actionable diagnostics')

assert.ok(workflow.includes('"public/development/phantom/**"'), 'Deploy workflow must include the PHANTOM public case path')
assert.ok(workflow.includes('node scripts/phantom-case-smoke.mjs'), 'Deploy workflow must run the PHANTOM case contract before publishing')
assert.ok(packageJson.scripts?.['qa:phantom-case'] === 'node scripts/phantom-case-smoke.mjs', 'Package must expose the PHANTOM case smoke test')
