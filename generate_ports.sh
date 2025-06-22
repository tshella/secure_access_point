#!/bin/bash

PORTS=$(ss -tln | awk 'NR>1 {print $4}' | awk -F: '{print $NF}' | grep -E '^[0-9]+$' | sort -n | uniq)
JSON="{\"ports\":["
FIRST=true
for PORT in $PORTS; do
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        JSON+=","
    fi
    JSON+="$PORT"
done
JSON+="]}"
echo "$JSON" > ports.json
