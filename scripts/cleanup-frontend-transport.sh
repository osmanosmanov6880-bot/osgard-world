#!/usr/bin/env bash
# Remove ONLY the remote /tmp transport folder belonging to this Actions run.
# Safe after a completed stage or failed freshness check; never touch /usr,
# running containers, previous production, core DB or Godot QA backups.
set -euo pipefail
if [[ ! "${GITHUB_RUN_ID:-}" =~ ^[1-9][0-9]{3,15}$ ]]; then
  echo 'FRONTEND_TRANSPORT_CLEANUP_INVALID_RUN: numeric Actions run ID required' >&2
  exit 2
fi
if [[ -z "${HOST:-}" || -z "${USER:-}" || "${HOST}" == -* || "${USER}" == -* ||
      "${HOST}" == *$'\n'* || "${USER}" == *$'\n'* ||
      "${HOST}" == *$'\r'* || "${USER}" == *$'\r'* ]]; then
  echo 'FRONTEND_TRANSPORT_CLEANUP_INVALID_HOST: nonempty SSH target required' >&2
  exit 2
fi
remote_dir="/tmp/osgard-gh-release-${GITHUB_RUN_ID}"
# Fixed command and a digits-only suffix: no interpolated filesystem paths.
ssh -i ~/.ssh/osgard_deploy -o BatchMode=yes "${USER}@${HOST}" "rm -rf -- '${remote_dir}'"
echo "FRONTEND_TRANSPORT_CLEANED: source_run=${GITHUB_RUN_ID} scope=temporary_upload_only"
