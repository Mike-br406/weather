#!/usr/bin/env bash
# Fetches current weather for your IP-detected location using Open-Meteo + ip-api.com

set -euo pipefail

# ── dependencies ────────────────────────────────────────────────────────────
for cmd in curl jq; do
  command -v "$cmd" &>/dev/null || { echo "ERROR: '$cmd' not found. Install it and retry."; exit 1; }
done

# ── location from IP ─────────────────────────────────────────────────────────
GEO=$(curl -sf "http://ip-api.com/json?fields=lat,lon,city,regionName,country")
LAT=$(echo "$GEO" | jq -r '.lat')
LON=$(echo "$GEO" | jq -r '.lon')
CITY=$(echo "$GEO" | jq -r '.city')
REGION=$(echo "$GEO" | jq -r '.regionName')
COUNTRY=$(echo "$GEO" | jq -r '.country')

# ── weather from Open-Meteo (no API key required) ────────────────────────────
WEATHER=$(curl -sf \
  "https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}\
&current=temperature_2m,apparent_temperature,relative_humidity_2m,\
wind_speed_10m,wind_direction_10m,weather_code,precipitation,cloud_cover\
&temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch\
&timezone=auto&forecast_days=1")

# ── parse fields ─────────────────────────────────────────────────────────────
TEMP=$(echo "$WEATHER"       | jq -r '.current.temperature_2m')
FEELS=$(echo "$WEATHER"      | jq -r '.current.apparent_temperature')
HUMIDITY=$(echo "$WEATHER"   | jq -r '.current.relative_humidity_2m')
WIND=$(echo "$WEATHER"       | jq -r '.current.wind_speed_10m')
WIND_DIR=$(echo "$WEATHER"   | jq -r '.current.wind_direction_10m')
PRECIP=$(echo "$WEATHER"     | jq -r '.current.precipitation')
CLOUDS=$(echo "$WEATHER"     | jq -r '.current.cloud_cover')
CODE=$(echo "$WEATHER"       | jq -r '.current.weather_code')
TIME=$(echo "$WEATHER"       | jq -r '.current.time')
TZ=$(echo "$WEATHER"         | jq -r '.timezone')

# ── WMO weather code → human label ───────────────────────────────────────────
wmo_label() {
  case "$1" in
    0)  echo "Clear sky" ;;
    1)  echo "Mainly clear" ;;
    2)  echo "Partly cloudy" ;;
    3)  echo "Overcast" ;;
    45|48) echo "Foggy" ;;
    51|53|55) echo "Drizzle" ;;
    61|63|65) echo "Rain" ;;
    71|73|75) echo "Snow" ;;
    77) echo "Snow grains" ;;
    80|81|82) echo "Rain showers" ;;
    85|86) echo "Snow showers" ;;
    95) echo "Thunderstorm" ;;
    96|99) echo "Thunderstorm w/ hail" ;;
    *)  echo "Unknown (code $1)" ;;
  esac
}

# ── wind direction degrees → compass ─────────────────────────────────────────
compass() {
  local dirs=(N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW)
  local idx=$(( ( ($1 + 11) % 360 ) / 22 ))
  echo "${dirs[$idx]}"
}

CONDITION=$(wmo_label "$CODE")
WIND_COMPASS=$(compass "$WIND_DIR")

# ── output ────────────────────────────────────────────────────────────────────
echo "┌─────────────────────────────────────────────┐"
printf "│  📍  %-40s│\n" "${CITY}, ${REGION}, ${COUNTRY}"
printf "│  🕐  %-40s│\n" "${TIME}  (${TZ})"
echo "├─────────────────────────────────────────────┤"
printf "│  ☁️   %-40s│\n" "${CONDITION}"
printf "│  🌡️   Temp:      %-27s│\n" "${TEMP}°F  (feels like ${FEELS}°F)"
printf "│  💧  Humidity:   %-27s│\n" "${HUMIDITY}%"
printf "│  💨  Wind:       %-27s│\n" "${WIND} mph ${WIND_COMPASS}"
printf "│  🌧️   Precip:    %-27s│\n" "${PRECIP} in"
printf "│  ☁️   Cloud cvr: %-27s│\n" "${CLOUDS}%"
echo "└─────────────────────────────────────────────┘"
