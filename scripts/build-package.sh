#!/usr/bin/env bash
# Build the package offline from driver/ and store it in packages/
# (replacing the previous prebuilt package, updating needed-libs.txt and SHA256SUMS).
set -u
source "$(dirname "$0")/common.sh"
need_pacman

sudo pacman -S --needed --asdeps --noconfirm $BUILD_DEPS || exit 1
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp "$REPO_DIR/driver/PKGBUILD" "$REPO_DIR"/driver/patches/*.patch "$REPO_DIR"/driver/upstream/*.tar.xz "$work/"
(cd "$work" && makepkg -fc --noconfirm) || { red "build failed"; exit 1; }

built="$(ls -1 "$work"/${PKG_NAME}-*-x86_64.pkg.tar.zst | head -1)"
[ -f "$built" ] || { red "no package produced"; exit 1; }
# pacman file names contain ':' (epoch); store with '_' so the repo works everywhere.
dest="$PKG_DIR/$(basename "$built" | tr ':' '_')"
rm -f "$PKG_DIR"/${PKG_NAME}-*-x86_64.pkg.tar.zst
cp "$built" "$dest"

tmp="$(mktemp -d)"
tar -xf "$dest" -C "$tmp" usr/lib/libfprint-2.so.2.0.0
readelf -d "$tmp/usr/lib/libfprint-2.so.2.0.0" | awk '/NEEDED/{gsub(/[\[\]]/,"",$5); print $5}' > "$NEEDED_LIBS"
rm -rf "$tmp"
(cd "$PKG_DIR" && sha256sum ./*.pkg.tar.zst | sed 's| \./| |' > SHA256SUMS)
green "Built $dest"
