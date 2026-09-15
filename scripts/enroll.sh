#!/usr/bin/env bash
# Enroll a finger on the ThinkPad E14 (20RA) Goodix 27c6:55a4 reader.
#   scripts/enroll.sh [finger]   default: right-index-finger
set -u
finger="${1:-right-index-finger}"

cat <<EOF
== Enrolling $finger for user $USER
 - Each time: press FIRMLY for about half a second, then lift fully.
 - Shift the finger slightly between presses (centre, tip, left, right).
 - 'enroll-retry-scan'        = press was too light: press again.
 - 'enroll-remove-and-retry'  = lift your finger, then press again.
 - The first press only checks for an existing print; then 20 stages follow.
EOF
read -r -p "Press Enter to start (this replaces existing prints of $USER)... " _
fprintd-delete "$USER" >/dev/null 2>&1
fprintd-enroll -f "$finger" || exit 1
fprintd-list "$USER"
echo "Test it: fprintd-verify"
