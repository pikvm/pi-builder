#!/bin/sh
set -euo pipefail

if [ -t 1 ]; then
	color_comment=$(echo -e '\e[1;30m')
	color_value=$(echo -e '\e[1;35m')
	color_ok=$(echo -e '\e[1;32m')
	color_fail=$(echo -e '\e[1;31m')
	color_reset=$(echo -e '\e[0m')
else
	color_comment=""
	color_value=""
	color_ok=""
	color_fail=""
	color_reset=""
fi
no="${color_ok}no${color_reset}"
yes="${color_fail}yes${color_reset}"

echo "${color_comment}# $(tr -d '\0' < /proc/device-tree/model)${color_reset}"

echo
echo "CPU temp: ${color_value}$(echo "scale=2; $(</sys/class/thermal/thermal_zone0/temp) / 1000" | bc -l)'C${color_reset}"
gpu_temp=$(/usr/bin/vcgencmd measure_temp)
echo "GPU temp: ${color_value}${gpu_temp#*=}${color_reset}"

flags=$(/usr/bin/vcgencmd get_throttled)
flags="${flags#*=}"
echo
echo "Throttled flags: ${color_value}${flags}${color_reset}"

echo
echo -n "Throttled now:  "
((($flags&0x4)!=0)) && echo "${yes}" || echo "${no}"

echo -n "Throttled past: "
((($flags&0x40000)!=0)) && echo "${yes}" || echo "${no}"

echo
echo -n "Undervoltage now:  "
((($flags&0x1)!=0)) && echo "${yes}" || echo "${no}"

echo -n "Undervoltage past: "
((($flags&0x10000)!=0)) && echo "${yes}" || echo "${no}"

echo
echo -n "Frequency capped now:  "
((($flags&0x2)!=0)) && echo "${yes}" || echo "${no}"

echo -n "Frequency capped past: "
((($flags&0x20000)!=0)) && echo "${yes}" || echo "${no}"
