#!/usr/bin/env bash
# Use the fingerprint for sudo only (not for login / display manager).
# 'sufficient' means the password prompt still follows if the fingerprint fails
# or the reader/driver is unavailable, so this can never lock you out of sudo.
#   scripts/enable-sudo.sh           enable
#   scripts/enable-sudo.sh --disable remove the line again
set -u
f=/etc/pam.d/sudo
line="auth sufficient pam_fprintd.so"

if [ "${1:-}" = "--disable" ]; then
  sudo sed -i '/^auth[[:space:]]\+sufficient[[:space:]]\+pam_fprintd\.so/d' "$f" && echo "fingerprint removed from $f"
  exit 0
fi
if grep -q "pam_fprintd.so" "$f"; then
  echo "already enabled in $f"
else
  sudo cp -n "$f" "$f.before-fingerprint"
  # Must come before the password (system-auth) line; insert as the first auth rule.
  sudo sed -i "0,/^auth/s//$line\n&/" "$f" || exit 1
  echo "enabled; backup at $f.before-fingerprint"
fi
head -5 "$f"
