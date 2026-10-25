#!/usr/bin/env bash
# Guard OSGARD frontend against overwriting the live site with an older,
# delayed Actions archive while other projects keep merging to master.
# Read-only GitHub API call; no SSH and no mutation.
set -euo pipefail

if [[ "${GITHUB_REF:-}" != 'refs/heads/master' ||
      ! "${GITHUB_REPOSITORY:-}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ||
      ! "${GITHUB_SHA:-}" =~ ^[0-9a-f]{40}$ ||
      -z "${GH_TOKEN:-}" ]]; then
  echo 'FRONTEND_RELEASE_GUARD_INVALID_CONTEXT: expected authenticated master release with 40-hex SHA' >&2
  exit 2
fi
# gh uses GitHub's authenticated REST master ref; this is authoritative for
# the selected repository. A network/API error is a hard failure, never PASS.
if ! current="$(gh api "repos/${GITHUB_REPOSITORY}/branches/master" --jq '.commit.sha')"; then
  echo 'FRONTEND_RELEASE_GUARD_GITHUB_UNAVAILABLE: cannot confirm active master, no server write allowed' >&2
  exit 3
fi
if [[ ! "$current" =~ ^[0-9a-f]{40}$ ]]; then
  echo 'FRONTEND_RELEASE_GUARD_INVALID_HEAD: master ref not a 40-hex commit' >&2
  exit 3
fi
if [[ "$current" != "$GITHUB_SHA" ]]; then
  echo "FRONTEND_RELEASE_SUPERSEDED: archive=$GITHUB_SHA master=$current; old build must not replace newer site" >&2
  exit 42
fi
echo "FRONTEND_RELEASE_FRESHNESS_OK: master=$current; release source pinned"
