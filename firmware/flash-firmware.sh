#!/usr/bin/env bash
# One-time: flash Lenovo's universal Goodix firmware GF32x8_RTSEC_APP_10062
# onto the ThinkPad E14 (20RA) 27c6:55a4 reader. Needed only if the reader
# still runs the factory GF3268_RTSEC_APP_10041 firmware (see README).
# RISK: interrupting the flash can leave the reader unusable. Plug in AC power.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE" || exit 1

sha256sum -c SHA256SUMS || { echo "firmware checksum mismatch, aborting"; exit 1; }
lsusb -d 27c6:55a4 >/dev/null || { echo "reader 27c6:55a4 not found"; exit 1; }
command -v openssl >/dev/null || { echo "openssl is required"; exit 1; }

venv="$HERE/flash-tool/.venv"
if [ ! -x "$venv/bin/python" ]; then
  python3 -m venv "$venv" || exit 1
  "$venv/bin/pip" install -r "$HERE/flash-tool/requirements.txt" || exit 1
fi

# fprintd holds the USB device; stop it while flashing.
sudo systemctl stop fprintd
sudo "$venv/bin/python" "$HERE/flash-tool/flash_55a4_universal.py"
rc=$?
sudo systemctl start fprintd
exit $rc
