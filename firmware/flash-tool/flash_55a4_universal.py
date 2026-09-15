#!/usr/bin/env python3
"""Flash Lenovo's universal Goodix firmware (GF32x8_RTSEC_APP_10062) onto the
27c6:55a4 sensor, then capture test images with the matching 5503 flow.

The firmware file must be byte-identical to the image embedded in Lenovo's
Windows driver r16gf09w (Wbdi.dll), which lists PID 55A4 as supported.
"""
import glob
import hashlib
import os
import random
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
os.chdir(HERE)  # driver_5503 opens firmware/5503/... relative to cwd
sys.path.insert(0, HERE)

import driver_5503  # noqa: E402

# The universal firmware reports whichever sensor variant it detects
# (GF3206/3208/3258/3268). Accept any of them as "flashed", otherwise the
# tool would treat e.g. GF3268_RTSEC_APP_10062 as outdated and re-flash in a loop.
driver_5503.WORKING_FIRMWARE = "GF32[0-9]{2}_RTSEC_APP_10062"

EXPECTED_SHA256 = "faeb481046e767e46503c864ba85189c3d2a1fcce6bc8df284586214f7427df3"
FW_PATH = f"firmware/5503/{driver_5503.TARGET_FIRMWARE}.bin"
OUT_DIR = os.path.join(HERE, "flash-test-images")


def main():
    sha = hashlib.sha256(open(FW_PATH, "rb").read()).hexdigest()
    if sha != EXPECTED_SHA256:
        raise SystemExit(f"Firmware hash mismatch ({sha}); refusing to flash.")
    print(f"Firmware file OK: {FW_PATH} (matches Lenovo r16gf09w)")

    print("\nThis will erase the current sensor firmware (GF3268_RTSEC_APP_10041)")
    print("and write Lenovo's universal GF32x8_RTSEC_APP_10062.")
    print("Do NOT suspend, close the lid, or unplug power while it runs.")
    code = str(random.randint(1000, 9999))
    if input(f"Type {code} to continue: ").strip() != code:
        raise SystemExit("Aborted, nothing was changed.")

    for f in glob.glob("*.pgm"):
        os.remove(f)

    print("\nWhen it says 'Please place your finger on the sensor', press firmly;")
    print("when it says 'Please remove your finger', lift.\n")
    driver_5503.main(0x55a4)

    os.makedirs(OUT_DIR, exist_ok=True)
    for f in glob.glob("*.pgm"):
        shutil.copy(f, OUT_DIR)
    uid = int(os.environ.get("SUDO_UID", os.getuid()))
    gid = int(os.environ.get("SUDO_GID", os.getgid()))
    os.system(f"chown -R {uid}:{gid} {OUT_DIR}")
    print(f"\nDone. Test images copied to {OUT_DIR}")


if __name__ == "__main__":
    main()
