#!/usr/bin/env bash
# Install the patched libfprint for the ThinkPad E14 (20RA) Goodix 27c6:55a4 reader.
#   scripts/install.sh            prebuilt package if compatible, otherwise build from source
#   scripts/install.sh --binary   force the prebuilt package (refuses if libraries are missing)
#   scripts/install.sh --source   build from the pinned sources in driver/ (offline)
set -u
source "$(dirname "$0")/common.sh"
need_pacman

mode="auto"
case "${1:-}" in
  --binary) mode="binary" ;;
  --source) mode="source" ;;
  "") ;;
  *) echo "usage: $0 [--binary|--source]"; exit 1 ;;
esac

bash "$REPO_DIR/scripts/check-compat.sh"; compat=$?
[ $compat -eq 1 ] && exit 1
if [ "$mode" = "auto" ]; then
  [ $compat -eq 0 ] && mode="binary" || mode="source"
fi
if [ "$mode" = "binary" ] && [ $compat -ne 0 ]; then
  red "Refusing to install the prebuilt package: system libraries differ. Run: $0 --source"
  exit 1
fi

sudo -v || exit 1
sudo pacman -S --needed --noconfirm fprintd usbutils || exit 1

if [ "$mode" = "binary" ]; then
  pkg="$PKG_FILE"
  echo "== Installing prebuilt package"
else
  echo "== Building from pinned sources (offline)"
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  cp "$REPO_DIR/driver/PKGBUILD" "$REPO_DIR"/driver/patches/*.patch "$REPO_DIR"/driver/upstream/*.tar.xz "$work/"
  sudo pacman -S --needed --asdeps --noconfirm base-devel $BUILD_DEPS || exit 1
  (cd "$work" && makepkg -fsc --noconfirm) || { red "build failed"; exit 1; }
  pkg="$(ls "$work"/${PKG_NAME}-*.pkg.tar.zst | head -1)"
fi

# pacman replaces the stock libfprint (declared conflict) and keeps the old files
# restorable via scripts/uninstall.sh. --ask 4 auto-confirms that replacement.
sudo pacman -U --noconfirm --ask 4 "$pkg" || { red "pacman -U failed"; exit 1; }

# Pacman hook: after updates of linked libraries (opencv, glib2, openssl, libgusb)
# warn if libfprint no longer loads. Login/sudo always fall back to the password.
sudo install -Dm755 "$REPO_DIR/pacman-hook/$HOOK_NAME.sh" "/usr/local/libexec/$HOOK_NAME.sh"
sudo install -Dm644 "$REPO_DIR/pacman-hook/$HOOK_NAME.hook" "/etc/pacman.d/hooks/$HOOK_NAME.hook"

sudo systemctl restart fprintd 2>/dev/null
pacman -Q "$PKG_NAME"
if ldd /usr/lib/libfprint-2.so.2 | grep -q "not found"; then
  red "Installed library cannot resolve its dependencies!"; exit 1
fi
green "Installed. Next: scripts/enroll.sh, then scripts/enable-sudo.sh"
