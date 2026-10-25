#!/bin/sh
# First-time local workflow; movies/keys/rights never leave this machine.
set -eu
cd "$(dirname "$0")"
command -v node >/dev/null 2>&1 || { echo 'Node.js 22+ is required'; exit 1; }
node scripts/osa-cinema-v32-package-integrity.mjs "$PWD"
exec node scripts/osa-cinema-v32-first-run.mjs
