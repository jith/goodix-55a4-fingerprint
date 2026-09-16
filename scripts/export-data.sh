#!/usr/bin/env bash
# Copy saved captures and the fprintd journal (match scores) to ~/fprint-data
# for offline analysis. Capture saving continues.
set -u
data=~/fprint-data
mkdir -p "$data/raw"
sudo find /var/lib/fprint/debug -type f -name 'raw-*.bin' -exec cp -n -t "$data/raw" {} +
sudo chown -R "$(id -u):$(id -g)" "$data"
journalctl -u fprintd --no-pager -o short-unix --since "$(date -d @"$(ls "$data/raw" | sed -E 's/raw-([0-9]+)-.*/\1/' | sort -n | head -1)" '+%Y-%m-%d %H:%M:%S')" > "$data/journal.txt"
echo "$(ls "$data/raw" | wc -l) captures, journal $(wc -l < "$data/journal.txt") lines in $data"
