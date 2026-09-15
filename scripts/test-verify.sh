#!/usr/bin/env bash
# Measure real-world matching: N deliberate verify attempts, then a summary of
# image quality and match scores from the fprintd journal.
#   scripts/test-verify.sh [N]   default 10
set -u
n="${1:-10}"
since="$(date '+%Y-%m-%d %H:%M:%S')"
ok=0
for i in $(seq 1 "$n"); do
  echo
  read -r -p "[$i/$n] Press Enter, then touch the sensor naturally (firm, ~0.5 s) and lift... " _
  res="$(timeout 40 fprintd-verify 2>&1 | grep -o 'verify-[a-z-]*' | tail -1)"
  echo "    result: ${res:-timeout}"
  [ "$res" = "verify-match" ] && ok=$((ok + 1))
  sleep 1
done
echo
echo "== $ok/$n matched"
echo "== per capture (journal):"
journalctl -u fprintd --since "$since" --no-pager -o cat | grep -E "Touch image ridge score|SIGFM" | sed 's/^/   /'
if [ -d /var/lib/fprint/debug ] || sudo test -d /var/lib/fprint/debug; then
  out=~/fprint-test-captures/"$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$out"
  sudo find /var/lib/fprint/debug -newermt "$since" -type f -exec cp -t "$out" {} +
  sudo chown -R "$(id -u):$(id -g)" "$out"
  echo "== raw captures copied to $out ($(ls "$out" | wc -l) files)"
fi
