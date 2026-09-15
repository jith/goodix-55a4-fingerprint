#!/usr/bin/env bash
# Driver tuning without rebuilding (fprintd service environment).
#   scripts/tune.sh GOODIX55X4_VERIFY_VALLEY=0.06 GOODIX55X4_FDT_DELTA=11   set (replaces previous)
#   scripts/tune.sh --reset                                                 back to built-in defaults
#   scripts/tune.sh                                                         show current settings
# Keys: GOODIX55X4_{ENROLL,VERIFY}_GATE (ridge score), GOODIX55X4_{ENROLL,VERIFY}_VALLEY,
#       GOODIX55X4_{ENROLL,VERIFY}_COHERENCE, GOODIX55X4_MATCH_THRESHOLD, GOODIX55X4_FDT_DELTA
set -u
f=/etc/systemd/system/fprintd.service.d/tuning.conf
if [ $# -eq 0 ]; then
  cat "$f" 2>/dev/null || echo "no tuning (built-in defaults)"
  exit 0
fi
if [ "$1" = "--reset" ]; then
  sudo rm -f "$f"
else
  content="[Service]"
  for kv in "$@"; do
    [[ "$kv" =~ ^GOODIX55X4_[A-Z_]+=[0-9.]+$ ]] || { echo "invalid: $kv"; exit 1; }
    content+=$'\n'"Environment=$kv"
  done
  sudo mkdir -p "$(dirname "$f")" && printf '%s\n' "$content" | sudo tee "$f" >/dev/null
fi
sudo systemctl daemon-reload && sudo systemctl restart fprintd
cat "$f" 2>/dev/null || echo "tuning reset to defaults"
