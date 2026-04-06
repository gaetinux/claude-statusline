#!/bin/sh
# Claude Code status line - Peak/Off-Peak hours + visual bars
input=$(cat)

user=$(whoami)
dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
base=$(basename "$dir")
model=$(echo "$input" | jq -r '.model.display_name // .model.id // "Claude"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# --- Helpers ---

# Mini progress bar (5 segments): ███░░
mini_bar() {
  pct=$1
  filled=$(( (pct + 10) * 5 / 100 ))
  [ "$filled" -gt 5 ] && filled=5
  [ "$filled" -lt 0 ] && filled=0
  bar=""
  i=0
  while [ $i -lt 5 ]; do
    if [ $i -lt $filled ]; then
      bar="${bar}█"
    else
      bar="${bar}░"
    fi
    i=$((i + 1))
  done
  printf '%s' "$bar"
}

# ANSI color code by percentage threshold
pct_color() {
  if [ "$1" -ge 80 ]; then
    printf '31'  # red
  elif [ "$1" -ge 50 ]; then
    printf '33'  # yellow
  else
    printf '32'  # green
  fi
}

# --- Context Window ---
ctx_part=""
if [ -n "$used" ]; then
  used_int=$(printf '%.0f' "$used")
  color=$(pct_color "$used_int")
  bar=$(mini_bar "$used_int")
  ctx_part=" \033[90m│\033[0m \033[${color}m${bar}\033[0m \033[90mctx\033[0m ${used_int}%"
fi

# --- Rate Limit (5h window) ---
rate_part=""
five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
if [ -n "$five" ]; then
  five_int=$(printf '%.0f' "$five")
  color=$(pct_color "$five_int")
  bar=$(mini_bar "$five_int")
  rate_part=" \033[90m│\033[0m \033[${color}m${bar}\033[0m \033[90m5h\033[0m ${five_int}%"
fi

# --- Peak / Off-Peak Detection ---
# Peak hours: 8am–2pm ET (Eastern Time), weekdays (Mon–Fri)
# = 14h–20h heure de Paris
et_hour=$(TZ="America/New_York" date +%H)
et_hour=${et_hour#0}  # strip leading zero to avoid octal issues
[ -z "$et_hour" ] && et_hour=0
et_dow=$(TZ="America/New_York" date +%u)  # 1=Mon, 7=Sun

if [ "$et_dow" -le 5 ] && [ "$et_hour" -ge 8 ] && [ "$et_hour" -lt 14 ]; then
  # During peak: show time remaining
  hours_left=$((14 - et_hour))
  if [ "$hours_left" -eq 1 ]; then
    time_hint="~1h left"
  else
    time_hint="~${hours_left}h left"
  fi
  peak_part=" \033[90m│\033[0m \033[1;31m⚡ PEAK\033[0m \033[90m(${time_hint})\033[0m"
else
  # During off-peak: show when next peak starts
  if [ "$et_dow" -ge 5 ]; then
    # Friday evening, Saturday, or Sunday
    if [ "$et_dow" -eq 5 ] && [ "$et_hour" -lt 14 ]; then
      # Friday before 2pm = still could be peak (handled above) or before peak
      peak_part=" \033[90m│\033[0m \033[1;32m✦ OFF-PEAK\033[0m"
    else
      peak_part=" \033[90m│\033[0m \033[1;32m✦ OFF-PEAK\033[0m \033[90m(weekend)\033[0m"
    fi
  elif [ "$et_hour" -ge 14 ]; then
    # Weekday evening (after 2pm ET)
    peak_part=" \033[90m│\033[0m \033[1;32m✦ OFF-PEAK\033[0m \033[90m(until 8am ET)\033[0m"
  else
    # Weekday morning (before 8am ET)
    hours_until=$((8 - et_hour))
    if [ "$hours_until" -eq 1 ]; then
      time_hint="peak in ~1h"
    else
      time_hint="peak in ~${hours_until}h"
    fi
    peak_part=" \033[90m│\033[0m \033[1;32m✦ OFF-PEAK\033[0m \033[90m(${time_hint})\033[0m"
  fi
fi

# --- Output ---
printf "\033[1;32m➜\033[0m \033[1m%s\033[0m \033[36m%s\033[0m \033[90m│\033[0m \033[35m%s\033[0m%b%b%b" \
  "$user" "$base" "$model" "$ctx_part" "$rate_part" "$peak_part"
