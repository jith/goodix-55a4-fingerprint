#!/usr/bin/env bash
# Use the fingerprint for sudo only (not for login / display manager).
# 'sufficient' means the password prompt still follows if the fingerprint fails
# or the reader/driver is unavailable, so this can never lock you out of sudo.
#
# sudo cannot read the password while the fingerprint module waits, so keep the
# wait short: give up after TIMEOUT seconds or MAX_TRIES failed matches
# (pam_fprintd defaults: 30 s, 3 tries; "place your finger again" prompts for
# unclear images don't count as tries).
#   scripts/enable-sudo.sh             enable / update (timeout 10 s, 2 tries)
#   scripts/enable-sudo.sh --disable   remove the line again
#   TIMEOUT=15 MAX_TRIES=3 scripts/enable-sudo.sh
set -u
f=/etc/pam.d/sudo
timeout="${TIMEOUT:-10}"
tries="${MAX_TRIES:-2}"
line="auth sufficient pam_fprintd.so max-tries=$tries timeout=$timeout"

if [ "${1:-}" = "--disable" ]; then
  sudo sed -i '/^auth[[:space:]]\+sufficient[[:space:]]\+pam_fprintd\.so/d' "$f" && echo "fingerprint removed from $f"
  exit 0
fi
sudo cp -n "$f" "$f.before-fingerprint"
if grep -q "^auth[[:space:]]\+sufficient[[:space:]]\+pam_fprintd\.so" "$f"; then
  sudo sed -i "s|^auth[[:space:]]\+sufficient[[:space:]]\+pam_fprintd\.so.*|$line|" "$f" || exit 1
  echo "updated $f"
else
  # Must come before the password (system-auth) line; insert as the first auth rule.
  sudo sed -i "0,/^auth/s//$line\n&/" "$f" || exit 1
  echo "enabled in $f; backup at $f.before-fingerprint"
fi
head -5 "$f"
