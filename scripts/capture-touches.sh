#!/usr/bin/env bash
# Capture N touches and print image quality per touch, without matching and
# without needing an enrolled print: runs a throwaway enrollment (gates off)
# and cancels it, so nothing is saved.
#   scripts/capture-touches.sh [N]     default 5
# Used by quality-check.sh and touch-test.sh. Expects tune.sh gates already set.
set -u
n="${1:-5}"
count=0
echo "    touch lightly, lift, wait for the result line; $n touches"
while [ "$count" -lt "$n" ]; do
  fprintd-enroll -f right-little-finger >/dev/null 2>&1 &
  enroll_pid=$!
  while IFS= read -r line; do
    case "$line" in
      *"Touch image ridge score"*)
        count=$((count + 1))
        v="$(sed -E 's/.*valley depth ([0-9.]+).*/\1/' <<<"$line")"
        r="$(sed -E 's/.*ridge score ([0-9.]+).*/\1/' <<<"$line")"
        verdict="$(awk -v v="$v" 'BEGIN { print (v >= 0.10 ? "clear" : (v >= 0.08 ? "borderline" : "unusable")) }')"
        echo "    [$count/$n] valley depth $v  (ridge $r)  $verdict"
        [ "$count" -ge "$n" ] && break ;;
    esac
    kill -0 "$enroll_pid" 2>/dev/null || break   # enrollment ended (e.g. duplicate): restart
  done < <(journalctl -u fprintd -f -n 0 -o cat)
  kill "$enroll_pid" 2>/dev/null; wait "$enroll_pid" 2>/dev/null
  sleep 1
done
pkill -u "$(id -u)" -f "journalctl -u fprintd -f -n 0" 2>/dev/null
exit 0
