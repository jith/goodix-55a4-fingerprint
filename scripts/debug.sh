#!/usr/bin/env bash
# Troubleshooting switches.
#   scripts/debug.sh images  save every capture (raw sensor frames) to /var/lib/fprint/debug
#   scripts/debug.sh on      images + verbose fprintd logging (journalctl -u fprintd)
#   scripts/debug.sh off     both off; deletes the saved captures (export them first:
#                            scripts/export-data.sh)
set -u
case "${1:-}" in
  images)
    sudo mkdir -p /var/lib/fprint/debug && echo "saving captures to /var/lib/fprint/debug" ;;
  on)
    sudo sh -c '
      mkdir -p /etc/systemd/system/fprintd.service.d /var/lib/fprint/debug
      printf "[Service]\nEnvironment=G_MESSAGES_DEBUG=all\n" > /etc/systemd/system/fprintd.service.d/debug.conf
      systemctl daemon-reload; systemctl restart fprintd' && echo "debug on" ;;
  off)
    sudo sh -c '
      rm -f /etc/systemd/system/fprintd.service.d/debug.conf
      rmdir /etc/systemd/system/fprintd.service.d 2>/dev/null
      rm -rf /var/lib/fprint/debug
      systemctl daemon-reload; systemctl restart fprintd' && echo "debug off" ;;
  *) echo "usage: $0 images|on|off"; exit 1 ;;
esac
