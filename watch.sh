#!/bin/bash
# Checks OVHcloud VPS 2027 (VPS-3 / VPS-2) Linux stock in European datacenters
# and sends an ntfy push when availability newly appears. State lives in state/.
set -u
PLANS="vps-2027-model3:VPS-3 vps-2027-model2:VPS-2"
EU_DCS="GRA SBG RBX DE UK WAW EU-SOUTH-MIL"
TOPIC="${NTFY_TOPIC:?NTFY_TOPIC not set}"

for entry in $PLANS; do
  plan="${entry%%:*}"; name="${entry#*:}"
  json=$(curl -s --max-time 20 "https://eu.api.ovh.com/v1/vps/order/rule/datacenter?ovhSubsidiary=IE&planCode=$plan")
  if ! echo "$json" | jq -e '.datacenters' >/dev/null 2>&1; then
    echo "$name: API error"; continue
  fi
  avail=$(echo "$json" | jq -r --arg dcs "$EU_DCS" \
    '.datacenters[] | select(.datacenter as $d | ($dcs|split(" ")) | index($d)) | select(.linuxStatus=="available") | .datacenter' | tr '\n' ' ' | sed 's/ $//')
  echo "$name: ${avail:-none}"
  prev=$(cat "state/$plan.last" 2>/dev/null || true)
  echo "$avail" > "state/$plan.last"
  if [ -n "$avail" ] && [ "$avail" != "$prev" ]; then
    curl -s --max-time 15 -H "Title: OVH $name 2027 in stock" -H "Priority: urgent" -H "Tags: rotating_light" \
      -H "Click: https://www.ovhcloud.com/en-ie/vps/configurator/?planCode=$plan" \
      -d "Linux available in: $avail" "https://ntfy.sh/$TOPIC" >/dev/null
  fi
done
