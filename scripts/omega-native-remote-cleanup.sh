#!/usr/bin/env bash
# Delete ONLY this verified native transfer staging directory after public SHA QA.
# No Docker pruning and no deletion of site or game rollback backups.
set -euo pipefail
run_id="${1:-}"
case "$run_id" in
  ''|*[!0-9]*) echo "Unsafe Omega release run id" >&2; exit 2;;
esac
if [ "${#run_id}" -gt 20 ]; then
  echo "Run id is too long" >&2
  exit 2
fi
root="/tmp/osgard-omega-native-${run_id}"
if [ -L "$root" ]; then
  echo "Symlink staging directory rejected" >&2
  exit 2
fi
if [ ! -e "$root" ]; then
  echo "PASS: Omega transfer staging was already absent"
  exit 0
fi
if [ ! -d "$root" ] || [ ! -f "$root/game.tgz" ] || [ ! -f "$root/deploy.sh" ]; then
  echo "Unrecognized transport staging: not deleting" >&2
  exit 2
fi
rm -rf -- "$root"
test ! -e "$root"
echo "PASS: removed only validated Omega transport staging for completed run ${run_id}"
