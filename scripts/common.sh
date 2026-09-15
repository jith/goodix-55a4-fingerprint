# Shared settings for the ThinkPad E14 (20RA) Goodix 27c6:55a4 fingerprint scripts.
# shellcheck shell=bash

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_NAME="libfprint-goodixtls-55x4-fixed"
PKG_DIR="$REPO_DIR/packages"
# The newest prebuilt package in packages/ (built by scripts/build-package.sh)
PKG_FILE="$(ls -1 "$PKG_DIR"/${PKG_NAME}-*-x86_64.pkg.tar.zst 2>/dev/null | sort -V | tail -1)"
NEEDED_LIBS="$PKG_DIR/needed-libs.txt"
USB_ID="27c6:55a4"
BUILD_DEPS="base-devel meson pkgconf gobject-introspection gtk-doc doctest glib2-devel"
HOOK_NAME="thinkpad-e14-goodix-55a4-libfprint-check"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$*"; }

need_pacman() {
  command -v pacman >/dev/null 2>&1 || {
    red "pacman not found: these scripts support Arch-based distros only (see README, 'Other distros')."
    exit 1
  }
}
