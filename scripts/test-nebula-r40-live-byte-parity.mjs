#!/usr/bin/env node
// Static, offline contract: R40 live integrity job must never deploy or
// promote production. Passing this contract does not prove live HTTP parity.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const file='.github/workflows/nebula-r40-live-byte-parity.yml';
const y=fs.readFileSync(file,'utf8');
test('the live comparison has strictly read-only repository permissions',()=>{
  assert.match(y,/permissions:\n  contents: read\n  actions: read/);
  assert.match(y,/pull-requests: read/);
  assert.doesNotMatch(y,/secrets\./);
  assert.doesNotMatch(y,/contents: write|actions: write|deployments: write|id-token: write/);
  assert.doesNotMatch(y,/workflow_call|repository_dispatch/);
});
test('the verifier never uses SSH, server commands or mutable GitHub API methods',()=>{
  assert.doesNotMatch(y,/^\s*(ssh|scp|rsync|docker)\s/m);
  assert.doesNotMatch(y,/gh api\s+(-X|--method)\s*(PUT|POST|DELETE|PATCH)/);
  assert.doesNotMatch(y,/gh\s+workflow\s+run|git\s+push|git\s+commit/);
  assert.match(y,/workflow_dispatch:/);
});
test('candidate is a pinned successful PR build, not an arbitrary ZIP',()=>{
  assert.match(y,/nebula-r40-qa-one-shot-source\.json/);
  assert.match(y,/candidate_pr' "\$qa"\)" = 375/);
  assert.match(y,/\.head\.sha/);
  assert.match(y,/\.head_sha/);
  assert.match(y,/\.source_run_id/);
  assert.match(y,/\.conclusion/);
  assert.match(y,/gh run download "\$QA_RUN_ID"/);
  assert.match(y,/sha256sum --check R40_DEVICE_ARTIFACT_SHA256\.txt/);
  assert.match(y,/pull_request_head_sha=\$QA_HEAD_SHA/);
});
test('eight live assets must be compared byte for byte',()=>{
  assert.match(y,/for name in index\.html index\.js index\.wasm index\.pck/);
  assert.match(y,/curl --fail --silent --show-error --location --retry 2/);
  assert.match(y,/Accept-Encoding: identity/);
  assert.match(y,/cmp "public\/games\/remix\/arena-v2\/nebula-3d\/\$name"/);
  assert.match(y,/compare_ci_pin isolated_qa/);
  assert.match(y,/\.files\[\$file\]\.sha256/);
  assert.match(y,/node scripts\/nebula-production-artifact-guard\.mjs/);
  assert.match(y,/node scripts\/nebula-r40-ci-pin\.mjs --validate/);
  assert.match(y,/node scripts\/nebula-r40-ci-pin\.mjs --check-dir/);
  assert.match(y,/NEBULA_R40_QA_ROUTE_MISSING/);
  assert.match(y,/variant="\$\(jq -er '\.approved_variant'/);
  assert.match(y,/case "\$variant" in R38\|R40/);
  assert.match(y,/\.approval\.real_device_reviewed/);
  assert.match(y,/compare_ci_pin isolated_qa/);
  assert.match(y,/\.files\[\$file\]\.sha256/);
  assert.match(y,/NEBULA_ACTIVE_VARIANT/);
  assert.match(y,/\.approved_for_production/);
});

test('live byte integrity runs after every real full frontend deployment',()=>{
  assert.match(y,/workflow_run:\n    workflows:\n      - "OSGARD frontend deploy"\n    types: \[completed\]\n    branches: \[master\]/);
  assert.match(y,/if: github\.event_name == 'workflow_run'/);
  assert.match(y,/UPSTREAM_CONCLUSION:/);
  assert.match(y,/UPSTREAM_BRANCH:/);
  assert.match(y,/UPSTREAM_REPOSITORY:/);
  assert.match(y,/UPSTREAM_EVENT:/);
  assert.match(y,/test "\$UPSTREAM_REPOSITORY" = "\$GITHUB_REPOSITORY"/);
  assert.match(y,/test "\$UPSTREAM_BRANCH" = master/);
  assert.match(y,/push\|workflow_dispatch\) ;;/);
  assert.match(y,/test "\$UPSTREAM_CONCLUSION" = success/);
  assert.match(y,/refusing to certify NEBULA QA survival/);
});
