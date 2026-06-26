#!/usr/bin/env bash
# Logs weather readings to a CSV — pipe-friendly, cron-ready.
# Usage:  ./weather_log.sh [logfile.csv]
#         ./weather_log.sh | tee -a weather.log

set -euo pipefail

LOG="${1:-${HOME}/weather_log.csv}"

for cmd in curl jq; do
  command -v "$cmd" &>/dev/null || { echo "ERROR: '$cmd' not found."; exit 1; }
done

GEO=$(curl -sf "http://ip-api.com/json?fields=lat,lon,city,regionName")
LAT=$(echo "$GEO" | jq -r '.lat')
LON=$(echo "$GEO" | jq -r '.lon')
CITY=$(echo "$GEO" | jq -r '.city')
REGION=$(echo "$GEO" | jq -r '.regionName')

WEATHER=$(curl -sf \
  "https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}\
&current=temperature_2m,apparent_temperature,relative_humidity_2m,\
wind_speed_10m,weather_code,precipitation\
&temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch\
&timezone=auto&forecast_days=1")

TEMP=$(echo "$WEATHER"    | jq -r '.current.temperature_2m')
FEELS=$(echo "$WEATHER"   | jq -r '.current.apparent_temperature')
HUMIDITY=$(echo "$WEATHER"| jq -r '.current.relative_humidity_2m')
WIND=$(echo "$WEATHER"    | jq -r '.current.wind_speed_10m')
PRECIP=$(echo "$WEATHER"  | jq -r '.current.precipitation')
CODE=$(echo "$WEATHER"    | jq -r '.current.weather_code')
TIME=$(echo "$WEATHER"    | jq -r '.current.time')

# Write CSV header if file is new
if [[ ! -f "$LOG" ]]; then
  echo "timestamp,city,region,temp_f,feels_like_f,humidity_pct,wind_mph,precip_in,weather_code" > "$LOG"
fi

ROW="${TIME},${CITY},${REGION},${TEMP},${FEELS},${HUMIDITY},${WIND},${PRECIP},${CODE}"
echo "$ROW" >> "$LOG"
echo "$ROW"   # also emit to stdout so pipes work: ./weather_log.sh | grep ...
