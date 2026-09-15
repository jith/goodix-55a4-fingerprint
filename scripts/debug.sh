#!/usr/bin/env bash
# Verbose fprintd logging + raw capture dumps for troubleshooting.
#   scripts/debug.sh on    enable   (logs: journalctl -u fprintd; dumps: /var/lib/fprint/debug)
#   scripts/debug.sh off   disable and delete dumps
set -u
case "${1:-}" in
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
  *) echo "usage: $0 on|off"; exit 1 ;;
esac
