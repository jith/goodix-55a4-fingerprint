#!/usr/bin/env bash
# Quick image-quality check: N touches, prints valley depth per touch
# (>= 0.10 clear, enrollment accepts it; < 0.08 unusable). Nothing is saved.
#   scripts/quality-check.sh [N]   default 5
set -u
here="$(cd "$(dirname "$0")" && pwd)"
bash "$here/tune.sh" GOODIX55X4_ENROLL_GATE=0 GOODIX55X4_ENROLL_VALLEY=0 >/dev/null || exit 1
sleep 2
bash "$here/capture-touches.sh" "${1:-5}"
bash "$here/tune.sh" --reset >/dev/null
