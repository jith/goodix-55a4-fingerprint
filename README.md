# Fingerprint reader for Lenovo ThinkPad E14 Gen 1 (20RA) — Goodix 27c6:55a4

Everything needed to get the built-in Goodix fingerprint reader working on Linux
for **sudo** and a **lock screen** (e.g. noctalia), reproducibly and offline:

- patched `libfprint` (source patches + pinned upstream snapshot + tested prebuilt package)
- Lenovo universal reader firmware and a flash tool
- install / enroll / enable / uninstall scripts
- a pacman hook that warns if a system update breaks the binary

Tested: ThinkPad E14 Gen 1, machine type **20RA**, CachyOS (Arch based), fprintd 1.94.5,
package `libfprint-goodixtls-55x4-fixed 1:r1805.c1937b9-23`, September 2026.

> ⚠️ **Unofficial, reverse-engineered, tested on a single laptop.** Flashing the reader
> firmware can brick it and breaks Windows fingerprint login. Read [Risks](#risks) before
> doing anything.

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
  GF3268_RTSEC_APP_10041.bin   community Linux firmware this reader ran before 10062 (reference only, not factory)
  flash-firmware.sh            one-time flash (wraps flash-tool/, from goodix-fp-dump, MIT)
  SHA256SUMS
scripts/
  check-compat.sh              can the prebuilt binary run on this system?
  install.sh                   install (prebuilt if compatible, else build from source)
  build-package.sh             build driver/ offline into packages/ (updates needed-libs, checksums)
  enroll.sh                    guided 40-press enrollment (tells you where to place the finger)
  enable-sudo.sh               fingerprint for sudo only (--disable to undo)
  debug.sh on|off              verbose logs + raw capture dumps
  uninstall.sh                 back to stock libfprint
pacman-hook/                   post-update check that the library still loads
```

## Risks

Read this before flashing or installing. You use everything here at your own risk;
none of it is supported by Lenovo, Goodix or the libfprint project.

### Firmware flashing (highest risk)

- **Can permanently brick the reader.** Power loss, suspend, lid close or a USB reset during
  the flash, or a failed write, can leave the reader unusable. There is no official recovery.
  The tool checks the firmware SHA-256, requires the `MILAN_RTSEC_IAP_10027` bootloader and
  asks for a confirmation code, but cannot rule this out.
- **No tested way back to factory firmware.** The factory image (`GF3208_RTSEC_APP_10039`)
  is not in this repo, and the included `10041` file is *not* factory firmware.
- **Windows fingerprint login stops working.** Flashing writes a Linux pairing key; Windows
  enrollments become invalid. If Windows or Lenovo Vantage later re-flashes or re-pairs the
  reader, Linux stops working until you flash again.
- **Only one path was actually run:** 10041 → 10062 on one 20RA. Flashing from the factory
  10039 firmware, or on another laptop model, is untested.

### Driver

- **Loose firmware check.** The driver accepts any `GF32xx_RTSEC_APP_100xx` firmware name.
  A Windows-paired reader stops with `Invalid device PSK`, but on `10041` (or another version
  paired with the Linux key) the driver runs its capture flow **without any error** even though
  it was only tested on `10062`: expect failed or unreliable matching. Always confirm `_10062`
  in `journalctl -u fprintd` (step 1).
- **Tuned on one unit.** Thresholds (finger-detect base levels, image quality gates) come from
  this 20RA's sensor. Another unit of the same model may need different values.
- **Old libfprint fork.** It replaces the distro `libfprint` with an old fork
  (TheWeirdDev `55b4-experimental`, based on libfprint 1.94.6 from August 2023, with build
  fixes up to August 2026); bug and security fixes from newer upstream libfprint
  are not included, for this reader or any other.
- **Prebuilt binary can stop loading** after distro library updates (e.g. OpenCV soname
  change). The fingerprint then stops working until rebuilt; see
  [Safety of the prebuilt binary](#safety-of-the-prebuilt-binary).
- **Overheat protection disabled.** libfprint's activity-time overheat model is turned off for
  this device (it aborted normal enrolls). The reader waits in low-power finger-detect mode and
  only captures on touch; no heating was observed, but long-term behaviour is untested.

### Security

- **Fingerprint unlocks sudo without the password.** Anyone who can put an enrolled finger on
  the reader (including while you sleep) gets root via sudo, and the lock screen opens the same way.
  There is no liveness or anti-spoofing detection.
- **Modest matcher.** Small 108×88 px sensor with the SIGFM matcher (threshold 200). In testing,
  other fingers of the same person scored up to ~150 and genuine touches usually 250–2400;
  the false-accept rate against other people was never measured.
- **Publicly known pairing key.** Linux talks to the reader over TLS with the all-zero PSK from
  goodix-fp-dump (Windows uses a per-device secret). Someone with physical USB access could
  impersonate the reader or replay images.
- **Biometric data on disk.** Enrolled prints are stored unencrypted (root-only) in
  `/var/lib/fprint`, as with any fprintd setup. `scripts/debug.sh on` additionally saves raw
  fingerprint images to `/var/lib/fprint/debug`; `scripts/debug.sh off` deletes them.

### Legal

- The firmware binaries are Goodix/Lenovo property and not redistributable. Keep this
  repository private.

## Installation

```bash
cd ~/thinkpad-e14-20ra-goodix-55a4-fingerprint
```

### 1. Check the firmware (one time)

The driver requires firmware **GF32xx_RTSEC_APP_10062** (Lenovo universal firmware).

| Firmware | Where it comes from | Works with this driver? |
|---|---|---|
| `GF3208_RTSEC_APP_10039` | **factory (stock)**, paired with Windows | ❌ no: the reader's pairing key (PSK) is set by Windows and unknown to Linux, so the TLS session cannot be opened (`Invalid device PSK`) |
| `GF3268_RTSEC_APP_10041` | community goodix-fp-dump firmware (what the upstream Linux 55x4 driver targets) | ❌ not supported: a GF3268 build on this GF3208 chip; washed-out images, taps did not match (tested 12–14 Sep 2026); the new capture flow was never tested on it |
| `GF32xx_RTSEC_APP_10062` | Lenovo Windows driver r16gf09w (universal) | ✅ tested, working |

History of the tested 20RA: factory 10039 → flashed 10041 (goodix-fp-dump) → flashed 10062.
The flash tool accepts any `GF32xx_RTSEC_APP_100xx` start point (it erases the app,
writes 10062 through the MILAN IAP bootloader and writes the Linux pairing key); only the
10041 → 10062 path was run on this machine.

**Dual boot:** after flashing, Windows fingerprint login stops working, and if Windows or
Lenovo Vantage re-flashes/re-pairs the reader, Linux stops working until you flash again.

Easiest check: install the driver (step 2), run `fprintd-verify` once, then:

```bash
journalctl -u fprintd -b | grep -m1 "Device firmware"
# Device firmware: "GF3268_RTSEC_APP_10062"   <- OK (the prefix GF3208/3258/3268 may vary)
```

If it shows anything other than `_10062` (e.g. `_10039`, `_10041`), or errors
`Invalid device PSK` / `Invalid device firmware`, flash once:

```bash
# AC power connected, do not suspend or close the lid during the flash.
# Can brick the reader and breaks Windows fingerprint login: see Risks.
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

The sensor sees only ~5×4 mm of the finger per press, and a later touch matches only if
it overlaps one of the enrolled presses. The script therefore takes **40 presses** and
tells you where to put the finger before each one (centre, tip, lower part, left/right
edge, slightly rotated, natural touch). In offline tests on labelled touches, 21 enrolled
frames matched 58% of genuine touches, 36 frames with varied placement 90%, with other
fingers still rejected.

- **Press firmly for about half a second, then lift fully.** Quick light taps are rejected.
- "too light" → press again at the same spot. "lift" → remove the finger first.
- Re-enroll after updating from a package older than pkgrel 24 (it used 20 presses).

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
| `Invalid device firmware` / `Invalid device PSK` in `journalctl -u fprintd` | reader not on 10062 or re-paired by Windows → flash firmware (step 1) |
| Many `retry-scan` | press firmer and longer; wait ~1 s between presses |
| `remove-and-retry` loops | finger rests on the sensor; lift fully |
| Matches rarely | `journalctl -u fprintd -b \| grep SIGFM` shows scores; re-enroll with `scripts/enroll.sh` following the placement hints |
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
  messages; no persisted state files
- finger resting on the sensor: never arms (waits for the lift, silently during verify,
  "remove finger" after ~15 s); the finger-free reference never follows the base down to a
  finger or lifting level (pkgrel 23 bug that caused retry loops after quick re-touches)
- 40 enroll stages; match scores printed to the journal (`journalctl -u fprintd | grep SIGFM`)
- libfprint's overheat model disabled for this device

Patches 0001, 0002, 0008: earlier host-side finger detection, OpenCV pkg-config
fallback, SIGFM matcher tuning.

## Licenses and credits

- libfprint and patches: LGPL-2.1-or-later. Upstream fork: TheWeirdDev/libfprint (goodixtls work by
  Alexander Meiler, Matthieu Charette, Alireza S.N. and contributors).
- `firmware/flash-tool/`: from goodix-fp-linux-dev/goodix-fp-dump, MIT (see its LICENSE).
- Firmware binaries are Goodix/Lenovo property, included only for personal backup/restore.
  **Keep this repository private; do not publish the firmware.**
