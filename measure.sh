#!/bin/sh
# Usage: ./measure.sh <label> [minutes] [interval-seconds]
# Logs whole-system power every interval to logs/<label>.csv, then prints a summary.
# No admin needed: reads battery telemetry from ioreg. Works with the lid closed
# as long as the Mac stays awake (Pilot Light helper installed).
set -e
cd "$(dirname "$0")"
LABEL=${1:?label required, e.g. baseline-open}
MINUTES=${2:-10}
INTERVAL=${3:-15}
mkdir -p logs
CSV="logs/$LABEL.csv"
echo "time,lid_closed,on_ac,battery_pct,system_w,battery_w,battery_temp_c,raw_mah" > "$CSV"

top_energy() { top -l 2 -s 3 -o power -stats command,cpu,power -n 8 | tail -8; }
top_energy > "logs/$LABEL.top-start.txt"

end=$(( $(date +%s) + MINUTES * 60 ))
while [ "$(date +%s)" -lt "$end" ]; do
  ioreg -rn AppleSmartBattery | awk -v t="$(date +%H:%M:%S)" \
    -v lid="$(ioreg -r -k AppleClamshellState -d 1 | grep -q '"AppleClamshellState" = Yes' && echo 1 || echo 0)" '
    /"CurrentCapacity" =/   { pct = $3 }
    /"ExternalConnected" =/ { ac = ($3 == "Yes") }
    /"Voltage" =/           { v = $3 }
    /"InstantAmperage" =/   { a = (length($3) == 20) ? substr($3, 15) - 551616 : $3 }  # negative = 2^64 - |a|
    /"Temperature" =/       { temp = $3 / 100 }
    /"AppleRawCurrentCapacity" =/ { mah = $3 }
    /PowerTelemetryData/    { if (match($0, /"SystemLoad"=[0-9]+/)) sys = substr($0, RSTART + 13, RLENGTH - 13) / 1000 }
    END { printf "%s,%d,%d,%d,%.1f,%.1f,%.1f,%d\n", t, lid, ac, pct, sys, v * a / 1e6, temp, mah }' >> "$CSV"
  sleep "$INTERVAL"
done

top_energy > "logs/$LABEL.top-end.txt"

awk -F, -v label="$LABEL" 'NR > 1 { n++; w = $3 ? $5 : -$6; if (n == 1) m0 = $8; m1 = $8; s += w; if (w > mx) mx = w; if (n == 1) p0 = $4; p1 = $4; lid += $2; ac += $3 }
  END { printf "%s: %d samples, avg %.1f W, peak %.1f W, battery %d%% -> %d%% (%d mAh used), lid closed %d/%d, on AC %d/%d\n",
        label, n, s / n, mx, p0, p1, m0 - m1, lid, n, ac, n }' "$CSV" | tee -a logs/summary.txt
echo "Top energy apps at end:"; cat "logs/$LABEL.top-end.txt"
