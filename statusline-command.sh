#!/bin/sh
# Claude Code status line v2 - Intelligent contextual layout
# https://github.com/Para-FR/claude-statusline
input=$(cat)

# --- Bulk JSON extraction (single jq call) ---
eval "$(echo "$input" | jq -r '
  "user_dir="    + (.workspace.current_dir // .cwd // "~" | @sh),
  "model_name="  + (.model.display_name // .model.id // "Claude" | @sh),
  "ctx_pct="     + (.context_window.used_percentage // empty | tostring | @sh),
  "five_pct="    + (.rate_limits.five_hour.used_percentage // empty | tostring | @sh),
  "seven_pct="   + (.rate_limits.seven_day.used_percentage // empty | tostring | @sh),
  "cost_usd="    + (.cost.total_cost_usd // empty | tostring | @sh),
  "duration_ms=" + (.cost.total_duration_ms // empty | tostring | @sh),
  "lines_add="   + (.cost.total_lines_added // empty | tostring | @sh),
  "lines_del="   + (.cost.total_lines_removed // empty | tostring | @sh),
  "wt_name="     + (.worktree.name // empty | tostring | @sh),
  "ag_name="     + (.agent.name // empty | tostring | @sh)
' 2>/dev/null)"

user=$(whoami)
base=$(basename "$user_dir")

# --- Helpers ---

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

pct_color() {
  if [ "$1" -ge 80 ]; then
    printf '31'
  elif [ "$1" -ge 50 ]; then
    printf '33'
  else
    printf '32'
  fi
}

visible_len() {
  printf '%b' "$1" | sed $'s/\033\[[0-9;]*m//g' | wc -m | tr -d ' '
}

# --- Segments: Toujours visibles ---

seg_header="\033[1;32m➜\033[0m \033[1m${user}\033[0m \033[36m${base}\033[0m"
seg_model="\033[35m${model_name}\033[0m"

seg_5h=""
if [ -n "$five_pct" ]; then
  five_int=$(printf '%.0f' "$five_pct")
  c=$(pct_color "$five_int")
  b=$(mini_bar "$five_int")
  seg_5h="\033[${c}m${b}\033[0m \033[90m5h\033[0m ${five_int}%"
fi

# Peak / Off-Peak
et_hour=$(TZ="America/New_York" date +%H)
et_hour=${et_hour#0}
[ -z "$et_hour" ] && et_hour=0
et_dow=$(TZ="America/New_York" date +%u)

if [ "$et_dow" -le 5 ] && [ "$et_hour" -ge 8 ] && [ "$et_hour" -lt 14 ]; then
  hours_left=$((14 - et_hour))
  seg_peak="\033[1;31m⚡ PEAK\033[0m \033[90m(~${hours_left}h left)\033[0m"
else
  if [ "$et_dow" -eq 6 ] || [ "$et_dow" -eq 7 ] || { [ "$et_dow" -eq 5 ] && [ "$et_hour" -ge 14 ]; }; then
    seg_peak="\033[1;32m✦ OFF-PEAK\033[0m \033[90m(weekend)\033[0m"
  elif [ "$et_hour" -ge 14 ]; then
    seg_peak="\033[1;32m✦ OFF-PEAK\033[0m \033[90m(until 8am ET)\033[0m"
  else
    hours_until=$((8 - et_hour))
    seg_peak="\033[1;32m✦ OFF-PEAK\033[0m \033[90m(peak in ~${hours_until}h)\033[0m"
  fi
fi

# --- Segments: Tier 2 ---

seg_ctx=""
if [ -n "$ctx_pct" ]; then
  ctx_int=$(printf '%.0f' "$ctx_pct")
  c=$(pct_color "$ctx_int")
  b=$(mini_bar "$ctx_int")
  seg_ctx="\033[${c}m${b}\033[0m \033[90mctx\033[0m ${ctx_int}%"
fi

seg_cost=""
if [ -n "$cost_usd" ]; then
  cost_check=$(echo "$cost_usd" | awk '{if ($1 > 0.10) print "yes"; else print "no"}')
  if [ "$cost_check" = "yes" ]; then
    seg_cost="\$$(printf '%.2f' "$cost_usd")"
  fi
fi

seg_wt=""
[ -n "$wt_name" ] && seg_wt="\033[36m${wt_name}\033[0m"

seg_ag=""
[ -n "$ag_name" ] && seg_ag="\033[36m${ag_name}\033[0m"

# --- Segments: Tier 3 ---

seg_7d=""
if [ -n "$seven_pct" ]; then
  seven_int=$(printf '%.0f' "$seven_pct")
  if [ "$seven_int" -gt 50 ] 2>/dev/null; then
    c=$(pct_color "$seven_int")
    b=$(mini_bar "$seven_int")
    seg_7d="\033[${c}m${b}\033[0m \033[90m7j\033[0m ${seven_int}%"
  fi
fi

seg_dur=""
if [ -n "$duration_ms" ]; then
  dur_int=$(printf '%.0f' "$duration_ms")
  if [ "$dur_int" -gt 600000 ] 2>/dev/null; then
    total_sec=$((dur_int / 1000))
    total_min=$((total_sec / 60))
    if [ "$total_min" -ge 60 ]; then
      h=$((total_min / 60))
      m=$((total_min % 60))
      seg_dur="\033[90m${h}h$(printf '%02d' "$m")m\033[0m"
    else
      seg_dur="\033[90m${total_min}m\033[0m"
    fi
  fi
fi

seg_lines=""
lines_total=0
[ -n "$lines_add" ] && lines_total=$((lines_total + lines_add)) 2>/dev/null
[ -n "$lines_del" ] && lines_total=$((lines_total + lines_del)) 2>/dev/null
if [ "$lines_total" -gt 0 ] 2>/dev/null; then
  add_part=""
  del_part=""
  [ -n "$lines_add" ] && [ "$lines_add" -gt 0 ] 2>/dev/null && add_part="\033[32m+${lines_add}\033[0m"
  [ -n "$lines_del" ] && [ "$lines_del" -gt 0 ] 2>/dev/null && del_part="\033[31m-${lines_del}\033[0m"
  if [ -n "$add_part" ] && [ -n "$del_part" ]; then
    seg_lines="${add_part} ${del_part}"
  elif [ -n "$add_part" ]; then
    seg_lines="$add_part"
  else
    seg_lines="$del_part"
  fi
fi

# --- Assembly with adaptive width ---
SEP=" \033[90m│\033[0m "

always="${seg_header}${SEP}${seg_model}"
[ -n "$seg_5h" ] && always="${always}${SEP}${seg_5h}"
always="${always}${SEP}${seg_peak}"

# tput cols may return 80 in subprocess context; use stty as fallback
term_w=${COLUMNS:-$(tput cols 2>/dev/null || echo 0)}
[ "$term_w" -le 80 ] 2>/dev/null && term_w=$(stty size 2>/dev/null | awk '{print $2}')
[ -z "$term_w" ] || [ "$term_w" -le 0 ] 2>/dev/null && term_w=200

# Full output: always + tier2 + tier3
output="$always"
[ -n "$seg_ctx" ] && output="${output}${SEP}${seg_ctx}"
[ -n "$seg_cost" ] && output="${output}${SEP}${seg_cost}"
[ -n "$seg_wt" ] && output="${output}${SEP}${seg_wt}"
[ -n "$seg_ag" ] && output="${output}${SEP}${seg_ag}"
[ -n "$seg_7d" ] && output="${output}${SEP}${seg_7d}"
[ -n "$seg_dur" ] && output="${output}${SEP}${seg_dur}"
[ -n "$seg_lines" ] && output="${output}${SEP}${seg_lines}"

cur_len=$(visible_len "$output")
if [ "$cur_len" -gt "$term_w" ]; then
  # Drop all tier 3, try adding back what fits
  output="$always"
  [ -n "$seg_ctx" ] && output="${output}${SEP}${seg_ctx}"
  [ -n "$seg_cost" ] && output="${output}${SEP}${seg_cost}"
  [ -n "$seg_wt" ] && output="${output}${SEP}${seg_wt}"
  [ -n "$seg_ag" ] && output="${output}${SEP}${seg_ag}"

  for seg in "$seg_7d" "$seg_dur" "$seg_lines"; do
    if [ -n "$seg" ]; then
      test_out="${output}${SEP}${seg}"
      tl=$(visible_len "$test_out")
      [ "$tl" -le "$term_w" ] && output="$test_out"
    fi
  done
fi

cur_len=$(visible_len "$output")
if [ "$cur_len" -gt "$term_w" ]; then
  # Drop tier 2+3, try adding back what fits (reverse drop order)
  output="$always"
  for seg in "$seg_wt" "$seg_ag" "$seg_ctx" "$seg_cost"; do
    if [ -n "$seg" ]; then
      test_out="${output}${SEP}${seg}"
      tl=$(visible_len "$test_out")
      [ "$tl" -le "$term_w" ] && output="$test_out"
    fi
  done
fi

printf '%b' "$output"
