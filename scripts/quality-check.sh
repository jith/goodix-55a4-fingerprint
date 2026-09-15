#!/usr/bin/env bash
# Quick image-quality check: N touches, prints valley depth per touch
# (>= 0.10 clear, enrollment accepts it; < 0.08 unusable). Match results are ignored.
#   scripts/quality-check.sh [N]   default 5
set -u
here="$(cd "$(dirname "$0")" && pwd)"
n="${1:-5}"
bash "$here/tune.sh" GOODIX55X4_VERIFY_GATE=0 GOODIX55X4_VERIFY_VALLEY=0 >/dev/null || exit 1
sleep 2
for i in $(seq 1 "$n"); do
  read -r -p "[$i/$n] Press Enter, then touch lightly and lift... " _
  timeout 30 fprintd-verify >/dev/null 2>&1
  journalctl -u fprintd --since "-40s" --no-pager -o cat | grep "Touch image ridge score" | tail -1 |
    sed -E 's/.*ridge score ([0-9.]+).*valley depth ([0-9.]+).*/    valley depth \2 (ridge \1)/' |
    awk '{ v=$3+0; print $0 (v>=0.10 ? "  clear" : (v>=0.08 ? "  borderline" : "  unusable")) }'
done
bash "$here/tune.sh" --reset >/dev/null
