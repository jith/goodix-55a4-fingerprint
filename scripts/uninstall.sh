#!/usr/bin/env bash
# Remove the patched driver and go back to the distro's stock libfprint.
# Note: stock libfprint does not support this reader, so fingerprint stops working;
# sudo/login keep working with the password.
set -u
source "$(dirname "$0")/common.sh"
need_pacman
sudo -v || exit 1
bash "$REPO_DIR/scripts/enable-sudo.sh" --disable
sudo rm -f "/etc/pacman.d/hooks/$HOOK_NAME.hook" "/usr/local/libexec/$HOOK_NAME.sh"
sudo rm -rf /var/lib/fprint/debug /etc/systemd/system/fprintd.service.d/debug.conf
sudo systemctl daemon-reload
# Installing libfprint replaces the conflicting patched package.
sudo pacman -S --noconfirm --ask 4 libfprint || exit 1
sudo systemctl restart fprintd 2>/dev/null
echo "Stock libfprint restored. Enrolled prints remain in /var/lib/fprint (delete with: fprintd-delete $USER)."
