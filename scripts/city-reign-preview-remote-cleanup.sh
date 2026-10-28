#!/usr/bin/env bash
# Delete ONLY this run's SSH transport after public digest and browser checks pass.
set -euo pipefail
run_id="${1:-}"
[[ "$run_id" =~ ^[0-9]{1,20}$ ]] || exit 2
root="/tmp/osgard-city-reign-preview-${run_id}"
[ ! -L "$root" ] || exit 2
if [ ! -e "$root" ]; then echo 'Transport already absent'; exit 0; fi
[ -d "$root" ] && [ -f "$root/game.tgz" ] && [ -f "$root/deploy.sh" ] || exit 3
rm -rf -- "$root"
[ ! -e "$root" ]
echo "CITY REIGN: removed only run ${run_id} SSH transport"
