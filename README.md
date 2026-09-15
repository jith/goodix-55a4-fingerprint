# Fingerprint reader for Lenovo ThinkPad E14 Gen 1 (20RA) — Goodix 27c6:55a4

Everything needed to get the built-in Goodix fingerprint reader working on Linux
for **sudo** and a **lock screen** (e.g. noctalia), reproducibly and offline:

- patched `libfprint` (source patches + pinned upstream snapshot + tested prebuilt package)
- Lenovo universal reader firmware and a flash tool
- install / enroll / enable / uninstall scripts
- a pacman hook that warns if a system update breaks the binary

Tested: ThinkPad E14 Gen 1, machine type **20RA**, CachyOS (Arch based), fprintd 1.94.5,
package `libfprint-goodixtls-55x4-fixed 1:r1805.c1937b9-23`, September 2026.

## Is this for my machine?

| Check | Expected |
|---|---|
| `lsusb -d 27c6:55a4` | `Shenzhen Goodix Technology Co.,Ltd. Goodix FingerPrint Device` |
| `cat /sys/class/dmi/id/product_name` | `20RA...` (ThinkPad E14 Gen 1) |
| Architecture | x86_64 |

Other laptops with the same **27c6:55a4** reader (some ThinkPad E14/E15 Gen 1/2 models)
will probably work, but only the 20RA was tested. Readers with other IDs (55b4, 5503, 5395 …)
are **not** supported by this repo.

## Compatible distros

| Distro | Prebuilt package | Build from source (`--source`) | Scripts |
|---|---|---|---|
| CachyOS | ✅ tested | ✅ | ✅ |
| Arch Linux | ✅ if `scripts/check-compat.sh` passes | ✅ | ✅ |
| EndeavourOS | ✅ if check passes | ✅ | ✅ |
| Garuda Linux | ✅ if check passes | ✅ | ✅ |
| Manjaro | ⚠️ usually lags library versions → use `--source` | ✅ | ✅ |
| Fedora, Debian/Ubuntu, openSUSE, others | ❌ | ⚠️ manual meson build of `driver/` (untested, see below) | ❌ |

Requirements: `pacman`, `fprintd`, x86_64, `opencv` (5.x or 4.x), `openssl` 3, `libgusb`.

## Repository layout

```
driver/
  PKGBUILD                     offline, checksum-pinned package recipe
  patches/0001..0010-*.patch   changes on top of upstream (0010 = the 55a4 capture flow)
  upstream/*.tar.xz            snapshot of TheWeirdDev/libfprint, branch 55b4-experimental, commit c1937b9
packages/
  libfprint-goodixtls-55x4-fixed-…-23-x86_64.pkg.tar.zst   tested prebuilt package
  needed-libs.txt              exact shared libraries the binary links against
  SHA256SUMS
firmware/
  GF3208_RTSEC_APP_10062.bin   Lenovo universal firmware (from Lenovo driver r16gf09w)
  GF3268_RTSEC_APP_10041.bin   factory firmware of this reader (rollback reference)
  flash-firmware.sh            one-time flash (wraps flash-tool/, from goodix-fp-dump, MIT)
  SHA256SUMS
scripts/
  check-compat.sh              can the prebuilt binary run on this system?
  install.sh                   install (prebuilt if compatible, else build from source)
  enroll.sh                    enroll a finger with the right technique
  enable-sudo.sh               fingerprint for sudo only (--disable to undo)
  debug.sh on|off              verbose logs + raw capture dumps
  uninstall.sh                 back to stock libfprint
pacman-hook/                   post-update check that the library still loads
```

## Installation

```bash
cd ~/thinkpad-e14-20ra-goodix-55a4-fingerprint
```

### 1. Check the firmware (one time)

The driver requires firmware **GF32x8_RTSEC_APP_10062**. The factory firmware
(`GF3268_RTSEC_APP_10041`) does not work with it.

Easiest check: install the driver (step 2), run `fprintd-verify` once, then:

```bash
journalctl -u fprintd -b | grep -m1 "Device firmware"
# Device firmware: "GF3268_RTSEC_APP_10062"   <- OK (the prefix GF3208/3258/3268 may vary)
```

If it shows `..._10041` or the error `Invalid device firmware`, flash once:

```bash
# AC power connected, do not suspend or close the lid during the flash
./firmware/flash-firmware.sh
```

It verifies the SHA-256 of the firmware, stops fprintd, asks for a confirmation code,
flashes, and captures test images. Needs `python3` and `openssl`.

### 2. Install the driver

```bash
./scripts/check-compat.sh     # optional: shows what install.sh will do
./scripts/install.sh          # prebuilt package if compatible, otherwise builds from source
```

- `--binary` forces the tested prebuilt package (refused if system libraries differ).
- `--source` builds offline from `driver/` (installs `base-devel meson …` as build deps).

The package replaces the distro `libfprint` (declared conflict), installs fprintd if
missing, and installs the pacman hook.

### 3. Enroll

```bash
./scripts/enroll.sh                  # default right-index-finger
./scripts/enroll.sh left-index-finger
```

Technique matters on this small sensor:

- **Press firmly for about half a second, then lift fully.** Quick light taps give poor images.
- Shift the finger slightly between presses (centre, tip, left, right).
- `enroll-retry-scan` → press was too light, press again.
- `enroll-remove-and-retry` → lift first, then press again.

Check: `fprintd-verify`

### 4. Use it

**sudo** (not login):

```bash
./scripts/enable-sudo.sh          # adds 'auth sufficient pam_fprintd.so' to /etc/pam.d/sudo
./scripts/enable-sudo.sh --disable
```

`sufficient` means the password prompt still appears if the fingerprint fails or the
reader is unavailable — you cannot lock yourself out.

**noctalia lock screen**: in `~/.config/noctalia/config.toml`

```toml
[lockscreen]
fingerprint = true
```

**Login / greetd**: intentionally not configured. To add it anyway, put the same PAM line
in the display manager's PAM file — at your own risk.

## Safety of the prebuilt binary

- The package only ships `libfprint-2.so` + headers/typelib; it never touches the kernel,
  bootloader or other packages.
- It links against exact library versions (`packages/needed-libs.txt`, e.g.
  `libopencv_core.so.500`). `install.sh` refuses to install it when any is missing
  and builds from source instead.
- After updates of `opencv`, `glib2`, `openssl`, `libgusb` or `fprintd`, the pacman hook
  checks that the library still loads and prints a warning if not. A broken library only
  disables the fingerprint; sudo and login fall back to the password.
- Fix after such an update: `./scripts/install.sh --source`.
- A full system update could offer the stock `libfprint`; it is not installed automatically
  (the patched package already provides `libfprint`). If it ever replaces the patched
  package, the hook warns — run `./scripts/install.sh` again. Optionally add
  `IgnorePkg = libfprint` to `/etc/pacman.conf`.

## Troubleshooting

| Symptom | Action |
|---|---|
| `No devices available` | `lsusb -d 27c6:55a4`; after suspend the reader re-enumerates, `sudo systemctl restart fprintd` |
| `Invalid device firmware` in `journalctl -u fprintd` | flash firmware (step 1) |
| Many `retry-scan` | press firmer and longer; wait ~1 s between presses |
| `remove-and-retry` loops | finger rests on the sensor; lift fully |
| Matches rarely | re-enroll with firm presses and varied placement |
| Need logs | `./scripts/debug.sh on`, reproduce, `journalctl -u fprintd -b`, then `./scripts/debug.sh off` |

## Uninstall

```bash
./scripts/uninstall.sh
```

Removes the sudo PAM line, the hook and debug files, and reinstalls stock `libfprint`
(which does not support this reader).

## Other distros (manual, untested)

Install build deps for libfprint (meson, glib2, libgusb, openssl, pixman, nss, gudev,
opencv), then:

```bash
tar -xf driver/upstream/*.tar.xz && cd libfprint-goodixtls-55x4
for p in ../driver/patches/*.patch; do patch -Np1 -i "$p"; done
meson setup build --prefix=/usr --buildtype=release -D doc=false
meson compile -C build && sudo meson install -C build
```

This overwrites the distro libfprint files outside the package manager.

## What was changed (technical)

Patch `0010-goodix55x4-windows-fdt-flow-10062.patch`, reverse-engineered from Lenovo's
Windows driver (`Wbdi.dll`):

- accepts universal firmware `GF32xx_RTSEC_APP_10062`; does not send TLS 0xd4 (drops the session on 10062)
- uploads the sensor config patched with the reader's OTP calibration (tcode, FDT delta/offset)
- finger detection (FDT) thresholds from live per-area readings; image captured
  immediately on the finger-down event (ridges fade within ~100 ms of contact)
- raw 12-bit processing: background subtraction, row destriping, local contrast
  normalisation, contact mask; SIGFM matcher, score threshold 200, 20 enroll stages
- quality gate (ridge score: enroll ≥ 34, verify ≥ 30) reported as libfprint retry
  messages; finger still on sensor → "remove finger"; no persisted state files
- libfprint's overheat model disabled for this device

Patches 0001, 0002, 0008: earlier host-side finger detection, OpenCV pkg-config
fallback, SIGFM matcher tuning.

## Licenses and credits

- libfprint and patches: LGPL-2.1-or-later. Upstream fork: TheWeirdDev/libfprint (goodixtls work by
  Alexander Meiler, Matthieu Charette, Alireza S.N. and contributors).
- `firmware/flash-tool/`: from goodix-fp-linux-dev/goodix-fp-dump, MIT (see its LICENSE).
- Firmware binaries are Goodix/Lenovo property, included only for personal backup/restore.
  **Keep this repository private; do not publish the firmware.**
