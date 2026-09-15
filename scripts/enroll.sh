#!/usr/bin/env bash
# Guided enrollment for the ThinkPad E14 (20RA) Goodix 27c6:55a4 reader.
#   scripts/enroll.sh [finger]   default: right-index-finger
#
# The sensor sees only ~5x4 mm of the finger per press, and a later touch matches
# only if it overlaps an enrolled press. So the 40 presses are spread over the
# whole fingertip; the script tells you where to place the finger next.
set -u
finger="${1:-right-index-finger}"
stages=40
hints=(
  "CENTRE of the fingertip, flat"
  "slightly towards the TIP (~2 mm)"
  "slightly towards the first JOINT (~2 mm)"
  "slightly LEFT"
  "slightly RIGHT"
  "CENTRE, finger rotated slightly LEFT"
  "CENTRE, finger rotated slightly RIGHT"
  "the way you naturally touch it for sudo / unlock"
)

cat <<EOF
== Guided enrollment: $finger for $USER ($stages presses)
 - Press like a keyboard key: firm but NOT hard, about half a second, then lift fully.
   Very hard presses flatten the ridges; quick light taps are too faint.
 - Wait for the "ok" line before the next press.
 - Follow the placement shown before each press; each spot gets 5 presses.
   Keep most of the sensor covered (don't use only the very tip or edge).
 - "too faint" = press again at the same spot. "lift" = remove the finger first.
 - The very first press only checks for an existing print (any placement).
This replaces existing prints of $USER.
EOF
read -r -p "Press Enter to start... " _
fprintd-delete "$USER" >/dev/null 2>&1

n=0
echo ">> Press 0 (duplicate check): anywhere"
stdbuf -oL fprintd-enroll -f "$finger" 2>&1 | while IFS= read -r line; do
  case "$line" in
    *enroll-stage-passed*)
      n=$((n + 1))
      if [ $n -lt $stages ]; then
        echo "   ok $n/$stages   next: ${hints[$(( n / 5 % ${#hints[@]} ))]}"
      fi ;;
    *enroll-retry-scan*|*enroll-swipe-too-short*|*enroll-finger-not-centered*)
      echo "   image too faint: press again at the same spot (not too hard, not too light)" ;;
    *enroll-remove-and-retry*)
      echo "   lift your finger fully, then press again" ;;
    *enroll-completed*)
      echo "== Enrollment completed ($stages presses)" ;;
    *"Enrolling "*)
      echo ">> then press 1: ${hints[0]}" ;;
    *)
      echo "   $line" ;;
  esac
done
fprintd-list "$USER"
echo "Test it: fprintd-verify   (or: sudo -k; sudo true)"
