#!/usr/bin/env bash
# Checks whether this machine can use the prebuilt package safely.
# Exit 0 = prebuilt binary OK, 2 = build from source instead, 1 = unsupported.
set -u
source "$(dirname "$0")/common.sh"

rc=0
echo "== ThinkPad E14 (20RA) Goodix $USB_ID fingerprint: compatibility check"

if [ "$(uname -m)" != "x86_64" ]; then red "CPU arch $(uname -m): only x86_64 supported"; exit 1; fi
green "arch x86_64"

if command -v pacman >/dev/null 2>&1; then
  green "pacman found ($(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown distro}"))"
else
  red "pacman not found: prebuilt package and scripts need an Arch-based distro"; exit 1
fi

if command -v lsusb >/dev/null 2>&1; then
  if lsusb -d "$USB_ID" >/dev/null 2>&1; then
    green "fingerprint reader $USB_ID present"
  else
    red "no USB device $USB_ID: this repo is only for the Goodix 55a4 reader"; exit 1
  fi
else
  yellow "lsusb missing (install usbutils); skipping device check"
fi

# The prebuilt library links against exact sonames (e.g. libopencv_core.so.500).
# If a distro update changed any of them, the binary would not load -> build from source.
missing=0
while read -r lib; do
  [ -z "$lib" ] && continue
  if /usr/bin/ldconfig -p | grep -qF "	$lib ("; then :; else red "missing system library: $lib"; missing=1; fi
done < "$NEEDED_LIBS"
if [ $missing -eq 0 ]; then
  green "all libraries needed by the prebuilt package are present"
else
  yellow "prebuilt package NOT compatible with this system's libraries -> use: scripts/install.sh --source"
  rc=2
fi

if pacman -Q fprintd >/dev/null 2>&1; then green "fprintd installed"; else yellow "fprintd not installed (install.sh will install it)"; fi

if [ -f /usr/lib/libfprint-2.so.2 ]; then
  if ldd /usr/lib/libfprint-2.so.2 | grep -q "not found"; then
    red "installed libfprint has unresolved libraries (fingerprint currently broken):"
    ldd /usr/lib/libfprint-2.so.2 | grep "not found"
  fi
fi
exit $rc
