#!/usr/bin/env bash
# Install the patched libfprint for the ThinkPad E14 (20RA) Goodix 27c6:55a4 reader.
#   scripts/install.sh            prebuilt package if compatible, otherwise build from source
#   scripts/install.sh --binary   force the prebuilt package (refuses if libraries are missing)
#   scripts/install.sh --source   build from the pinned sources in driver/ (offline), then install
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
# The prebuilt package must be the build of the current driver/PKGBUILD.
want="$(cd "$REPO_DIR/driver" && bash -c 'source PKGBUILD; echo "${epoch}_${pkgver}-${pkgrel}"')"
if [ -n "$PKG_FILE" ] && [[ "$(basename "$PKG_FILE")" != *"-${want}-x86_64.pkg.tar.zst" ]]; then
  yellow "prebuilt package $(basename "$PKG_FILE") is older than driver/PKGBUILD ($want)"
  [ "$mode" = "binary" ] && { red "Run: $0 --source"; exit 1; }
  PKG_FILE=""
fi
if [ "$mode" = "auto" ]; then
  [ $compat -eq 0 ] && [ -n "$PKG_FILE" ] && mode="binary" || mode="source"
fi
if [ "$mode" = "binary" ] && { [ $compat -ne 0 ] || [ -z "$PKG_FILE" ]; }; then
  red "Refusing to install the prebuilt package (missing, or system libraries differ). Run: $0 --source"
  exit 1
fi

sudo -v || exit 1
sudo pacman -S --needed --noconfirm fprintd usbutils || exit 1

if [ "$mode" = "source" ]; then
  echo "== Building from pinned sources (offline)"
  bash "$REPO_DIR/scripts/build-package.sh" || exit 1
  source "$REPO_DIR/scripts/common.sh"   # pick up the freshly built package
fi
echo "== Installing $(basename "$PKG_FILE")"

# pacman replaces the stock libfprint (declared conflict); --ask 4 confirms that.
sudo pacman -U --noconfirm --ask 4 "$PKG_FILE" || { red "pacman -U failed"; exit 1; }

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
