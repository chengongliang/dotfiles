#!/bin/bash

CPU=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^[[:space:]]*//' | sed 's/ [0-9]*-Core Processor//')

TEMP=$(sensors coretemp-isa-0000 | grep 'Core' | awk '{sum+=$3; count++} END {if (count > 0) printf "%.0f\n", sum/count}')

if   [ "$TEMP" -ge 85 ]; then icon=" "; color="\e[31m"
elif [ "$TEMP" -ge 70 ]; then icon=" "; color="\e[33m"
elif [ "$TEMP" -ge 50 ]; then icon=" "; color="\e[93m"
elif [ "$TEMP" -ge 35 ]; then icon=" "; color="\e[32m"
else                          icon=" "; color="\e[36m"
fi

echo -e "$CPU ${color}$icon${TEMP}°C"
