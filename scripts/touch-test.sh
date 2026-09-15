#!/usr/bin/env bash
# Which way of touching gives clear images today? 4 blocks x 5 touches; prints
# image quality per block. Needs an enrolled print (match results are ignored).
set -u
here="$(cd "$(dirname "$0")" && pwd)"
echo "== Touch style test (about 3 minutes). Type your password if sudo asks."
echo "   (If sudo shows a fingerprint prompt first, touch the sensor 3 times to skip it.)"
sudo -v || exit 1
since="$(date '+%Y-%m-%d %H:%M:%S')"
block() {  # name, tuning..., instruction via $msg
  local name="$1"; shift
  bash "$here/tune.sh" GOODIX55X4_VERIFY_GATE=0 GOODIX55X4_VERIFY_VALLEY=0 "$@" >/dev/null || exit 1
  sleep 2
  echo
  echo "=== Block $name: $msg"
  for i in 1 2 3 4 5; do
    read -r -p "   [$name $i/5] Press Enter, then touch... " _
    timeout 30 fprintd-verify >/dev/null 2>&1
    journalctl -u fprintd --since "-40s" --no-pager -o cat | grep "Touch image ridge score" | tail -1 | sed -E 's/.*ridge score ([0-9.]+).*valley depth ([0-9.]+).*/      ridge \1  valley depth \2/'
  done
  echo "MARK block $name" | systemd-cat -t fprint-touch-test
}
msg="touch the way you normally do";                                                  block A
msg="wipe the fingertip DRY on your clothes first, then touch LIGHTLY (just cover the sensor)"; block B
msg="wipe DRY first, then press FIRMLY";                                               block C
msg="wipe DRY first, touch LIGHTLY (earlier capture trigger)";                          block D GOODIX55X4_FDT_DELTA=11
bash "$here/tune.sh" --reset >/dev/null
echo
echo "== Summary (valley depth: clear images >= 0.10)"
journalctl --since "$since" --no-pager -o cat -t fprintd -t fprint-touch-test 2>/dev/null | awk '
  /Touch image ridge score/ { match($0,/valley depth [0-9.]+/); v=substr($0,RSTART+13,RLENGTH-13); match($0,/ridge score [0-9.]+/); r=substr($0,RSTART+12,RLENGTH-12); vs=vs" "v; rs=rs" "r }
  /MARK block/ { print "   block " $3 ": valley" vs "  | ridge" rs; vs=""; rs="" }'
if sudo test -d /var/lib/fprint/debug; then
  out=~/fprint-test-captures/touch-"$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$out"
  sudo find /var/lib/fprint/debug -newermt "$since" -type f -exec cp -t "$out" {} +
  sudo chown -R "$(id -u):$(id -g)" "$out"
  echo "== raw captures copied to $out"
fi
