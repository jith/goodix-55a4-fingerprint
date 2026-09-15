#!/usr/bin/env bash
# Compare sensor settings for image quality: 5 touches per setting, same touch
# style throughout (dry fingertip, light touch). Nothing is saved.
#   scripts/sensor-test.sh
set -u
here="$(cd "$(dirname "$0")" && pwd)"
settings=(
  "tcode 0xf0 (factory)|GOODIX55X4_TCODE=240"
  "tcode 0xc0|GOODIX55X4_TCODE=192"
  "tcode 0x90|GOODIX55X4_TCODE=144"
  "tcode 0x60|GOODIX55X4_TCODE=96"
)
echo "== Sensor setting test: ${#settings[@]} settings x 5 touches. Same touch each time:"
echo "   dry fingertip (wipe it), light touch, lift, wait for the result line."
sudo -v || exit 1
summary=()
for entry in "${settings[@]}"; do
  label="${entry%%|*}"; kv="${entry#*|}"
  bash "$here/tune.sh" GOODIX55X4_ENROLL_GATE=0 GOODIX55X4_ENROLL_VALLEY=0 $kv >/dev/null || exit 1
  sleep 2
  echo
  echo "=== $label"
  read -r -p "   wipe your fingertip, then press Enter... " _
  out="$(bash "$here/capture-touches.sh" 5 | tee /dev/tty)"
  vals="$(grep -o 'valley depth [0-9.]*' <<<"$out" | awk '{print $3}' | tr '\n' ' ')"
  summary+=("$label: $vals")
done
bash "$here/tune.sh" --reset >/dev/null
echo
echo "== Summary (valley depth, >= 0.10 clear)"
printf '   %s\n' "${summary[@]}"
