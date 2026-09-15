#!/bin/sh
# Warn (never fail the transaction) when a library update broke the patched libfprint.
lib=/usr/lib/libfprint-2.so.2
[ -e "$lib" ] || exit 0
if ldd "$lib" 2>/dev/null | grep -q "not found"; then
  echo "WARNING: libfprint (Goodix 55a4 patch) can no longer load:"
  ldd "$lib" | grep "not found"
  echo "Fingerprint is disabled until rebuilt; passwords still work."
  echo "Fix: <repo>/scripts/install.sh --source"
fi
if pacman -Q libfprint >/dev/null 2>&1 && ! pacman -Q libfprint-goodixtls-55x4-fixed >/dev/null 2>&1; then
  echo "WARNING: stock libfprint replaced the Goodix 55a4 patched build; reinstall with <repo>/scripts/install.sh"
fi
exit 0
