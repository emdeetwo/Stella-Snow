#!/bin/bash
# Get the newest Stella's Snow from GitHub, rebuild it, and restart it.
#
#     bash ~/StellaSnow/update.sh
#
set -euo pipefail
cd "$(dirname "$0")"
echo "Checking GitHub for updates..."
before="$(git rev-parse HEAD)"
git pull --ff-only --quiet
after="$(git rev-parse HEAD)"
if [ "$before" = "$after" ]; then
  echo "Already up to date. Reinstalling anyway."
else
  echo "Got updates:"
  git log --format='  - %s' "$before..$after"
fi
bash install.sh
