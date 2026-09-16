#!/usr/bin/env bash
# Labelled touches for matcher development: other fingers (must never match)
# and the enrolled finger. Touch time windows go to ~/fprint-data/manifest.tsv so
# the saved captures can be labelled later. Needs: scripts/debug.sh images.
# Nothing is enrolled (throwaway enrollment, cancelled).
#   scripts/collect-labelled.sh
set -u
here="$(cd "$(dirname "$0")" && pwd)"
data=~/fprint-data
mkdir -p "$data"
sudo test -d /var/lib/fprint/debug || { echo "run first: $here/debug.sh images"; exit 1; }
blocks=(
  "right-middle|10|your RIGHT MIDDLE finger"
  "left-index|10|your LEFT INDEX finger"
  "right-thumb|5|your RIGHT THUMB"
  "right-ring|5|your RIGHT RING finger"
  "right-index|10|your RIGHT INDEX finger (the enrolled one), natural touch"
)
echo "== Labelled touches: ${#blocks[@]} blocks. Dry fingertip, light natural touch."
echo "   The first touch of each block only checks duplicates; use the same finger anyway."
bash "$here/tune.sh" GOODIX55X4_ENROLL_GATE=0 GOODIX55X4_ENROLL_VALLEY=0 >/dev/null || exit 1
sleep 2
for b in "${blocks[@]}"; do
  IFS='|' read -r label n text <<<"$b"
  echo
  echo "=== $label: $n touches with $text"
  read -r -p "   Press Enter when ready... " _
  start="$(date +%s)"
  bash "$here/capture-touches.sh" "$n"
  printf '%s\t%s\t%s\n' "$label" "$start" "$(date +%s)" >> "$data/manifest.tsv"
done
bash "$here/tune.sh" --reset >/dev/null
echo
echo "== done; windows recorded in $data/manifest.tsv"
