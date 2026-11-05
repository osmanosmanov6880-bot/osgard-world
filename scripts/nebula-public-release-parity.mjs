#!/usr/bin/env node
// Public HTTPS verification: reuse EXACTLY the same strict policy/byte checker
// used by the isolated release gate. Never duplicate variant allowlists here.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { inspectProductionArtifact, POLICY_FILE } from './nebula-production-artifact-guard.mjs';

export async function verifyPublicRelease(policy, downloadedDirectory) {
  if (typeof downloadedDirectory !== 'string' ||
      !fs.existsSync(downloadedDirectory) ||
      !fs.statSync(downloadedDirectory).isDirectory()) {
    throw new Error('NEBULA_PUBLIC_RELEASE_HELD: no downloaded HTTPS artifact directory');
  }
  // inspectProductionArtifact checks the approval schema, explicit owner
  // authorization, distinct trusted source/Web export provenance, physical
  // device disclaimer, exact set of files, and Git blob SHA-1 of each binary.
  const result = await inspectProductionArtifact(policy, downloadedDirectory);
  for (const name of ['index.html', 'index.js', 'index.wasm', 'index.pck']) {
    const stat = fs.statSync(path.join(downloadedDirectory, name));
    if (!stat.isFile() || stat.size <= 0) {
      throw new Error('NEBULA_PUBLIC_RELEASE_HELD: missing file ' + name);
    }
    console.log('PUBLIC_RELEASE_BYTE_MATCH', result.variant, name, stat.size,
      result.files[name]);
  }
  console.log('NEBULA_PUBLIC_RELEASE_PARITY_PASS variant=' + result.variant +
    ' actual_hardware_qa=' +
    String(policy?.approval?.physical_device_qa || 'SEE_APPROVAL') +
    ' release_status=' + policy.release_status);
  return result;
}

async function main() {
  const directory = process.argv[2];
  if (!directory) {
    throw new Error('Usage: node scripts/nebula-public-release-parity.mjs <downloaded-directory>');
  }
  // PR review compares the live website with the already-approved master
  // policy, never with a future release candidate that is not yet deployed.
  // Production workflow_run always uses the current checked-out master pin.
  const policyPath = process.argv[3] || POLICY_FILE;
  const policy = JSON.parse(fs.readFileSync(policyPath, 'utf8'));
  await verifyPublicRelease(policy, directory);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch(error => {
    console.error('NEBULA_PUBLIC_RELEASE_HELD: ' + String(error.message));
    process.exitCode = 1;
  });
}
