# Status Line v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Réécrire `statusline-command.sh` avec un layout intelligent contextuel qui exploite toutes les données JSON de Claude Code et s'adapte à la largeur du terminal.

**Architecture:** Script POSIX sh unique. Le JSON est parsé une seule fois avec `jq` en bulk pour extraire toutes les valeurs. Les segments sont construits dans des variables, puis assemblés et filtrés par priorité selon la largeur terminal.

**Tech Stack:** POSIX sh, jq, tput, ANSI escape codes

---

### Task 1: Helpers et extraction de données

**Files:**
- Modify: `statusline-command.sh` (réécriture complète)
- Create: `test.sh` (script de test manuel)

- [ ] **Step 1: Créer le script de test**

Créer `test.sh` qui envoie du JSON simulé au script et affiche le résultat. Ce fichier servira de validation tout au long du développement.

```sh
#!/bin/sh
SCRIPT="./statusline-command.sh"

echo "=== Test 1: Session tranquille, toutes les données ==="
echo '{"workspace":{"current_dir":"/Users/adev/projects/orvi"},"model":{"display_name":"Opus 4.6"},"context_window":{"used_percentage":42.5},"rate_limits":{"five_hour":{"used_percentage":18.3},"seven_day":{"used_percentage":35.0}},"cost":{"total_cost_usd":0.42,"total_duration_ms":1920000,"total_lines_added":156,"total_lines_removed":23}}' | sh "$SCRIPT"
echo ""

echo "=== Test 2: Session chaude, rate limits tendus ==="
echo '{"workspace":{"current_dir":"/Users/adev/projects/serfac"},"model":{"display_name":"Opus 4.6"},"context_window":{"used_percentage":85.2},"rate_limits":{"five_hour":{"used_percentage":81.0},"seven_day":{"used_percentage":55.0}},"cost":{"total_cost_usd":3.21,"total_duration_ms":3600000,"total_lines_added":320,"total_lines_removed":89}}' | sh "$SCRIPT"
echo ""

echo "=== Test 3: Avec worktree et agent ==="
echo '{"workspace":{"current_dir":"/Users/adev/projects/orvi"},"model":{"display_name":"Opus 4.6"},"context_window":{"used_percentage":35.0},"rate_limits":{"five_hour":{"used_percentage":12.0}},"cost":{"total_cost_usd":0.08,"total_duration_ms":300000},"worktree":{"name":"my-feature"},"agent":{"name":"security"}}' | sh "$SCRIPT"
echo ""

echo "=== Test 4: Données minimales (pas de rate limit, pas de cost) ==="
echo '{"workspace":{"current_dir":"/Users/adev/projects/lfdbp"},"model":{"display_name":"Sonnet 4.6"},"context_window":{"used_percentage":15.0}}' | sh "$SCRIPT"
echo ""

echo "=== Test 5: JSON vide ==="
echo '{}' | sh "$SCRIPT"
echo ""
```

- [ ] **Step 2: Vérifier que le test fonctionne avec le script actuel**

Run: `cd /tmp/claude-statusline && chmod +x test.sh && sh test.sh`
Expected: Output (possiblement cassé pour les nouveaux champs, c'est normal)

- [ ] **Step 3: Écrire les helpers et l'extraction bulk jq**

Réécrire le début de `statusline-command.sh` avec extraction bulk de toutes les données JSON en un seul appel `jq`, et les fonctions helpers `mini_bar` et `pct_color`.

```sh
#!/bin/sh
# Claude Code status line v2 - Intelligent contextual layout
input=$(cat)

# --- Bulk JSON extraction (single jq call) ---
eval "$(echo "$input" | jq -r '
  "user_dir="   + (.workspace.current_dir // .cwd // "~"),
  "model_name=" + (.model.display_name // .model.id // "Claude"),
  "ctx_pct="    + (.context_window.used_percentage // empty | tostring),
  "five_pct="   + (.rate_limits.five_hour.used_percentage // empty | tostring),
  "seven_pct="  + (.rate_limits.seven_day.used_percentage // empty | tostring),
  "cost_usd="   + (.cost.total_cost_usd // empty | tostring),
  "duration_ms=" + (.cost.total_duration_ms // empty | tostring),
  "lines_add="  + (.cost.total_lines_added // empty | tostring),
  "lines_del="  + (.cost.total_lines_removed // empty | tostring),
  "wt_name="    + (.worktree.name // empty | tostring),
  "ag_name="    + (.agent.name // empty | tostring)
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

# strip ANSI codes and count visible chars
visible_len() {
  printf '%b' "$1" | sed 's/\x1b\[[0-9;]*m//g' | wc -m | tr -d ' '
}
```

- [ ] **Step 4: Lancer les tests pour vérifier l'extraction**

Ajouter temporairement un `echo "ctx=$ctx_pct five=$five_pct cost=$cost_usd wt=$wt_name"` avant le output, puis :

Run: `cd /tmp/claude-statusline && sh test.sh`
Expected: Les variables sont correctement peuplées pour chaque scénario

- [ ] **Step 5: Commit**

```bash
cd /tmp/claude-statusline
git add statusline-command.sh test.sh
git commit -m "feat: v2 helpers and bulk JSON extraction"
```

---

### Task 2: Construction des segments

**Files:**
- Modify: `statusline-command.sh`

- [ ] **Step 1: Écrire les segments "Toujours" (user/dir, modèle, 5h, peak)**

Ajouter après les helpers :

```sh
# --- Segments: Toujours visibles ---

seg_header="\033[1;32m➜\033[0m \033[1m${user}\033[0m \033[36m${base}\033[0m"
seg_model="\033[35m${model_name}\033[0m"

# 5h rate limit
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
```

- [ ] **Step 2: Écrire les segments Tier 2 (ctx, coût, worktree, agent)**

```sh
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
  cost_cents=$(printf '%.0f' "$(echo "$cost_usd * 100" | bc 2>/dev/null || echo 0)")
  if [ "$cost_cents" -gt 10 ] 2>/dev/null; then
    seg_cost="\$$(printf '%.2f' "$cost_usd")"
  fi
fi

seg_wt=""
if [ -n "$wt_name" ]; then
  seg_wt="\033[36m${wt_name}\033[0m"
fi

seg_ag=""
if [ -n "$ag_name" ]; then
  seg_ag="\033[36m${ag_name}\033[0m"
fi
```

- [ ] **Step 3: Écrire les segments Tier 3 (7j, durée, lignes)**

```sh
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
      seg_dur="\033[90m${h}h$(printf '%02d' $m)m\033[0m"
    else
      seg_dur="\033[90m${total_min}m\033[0m"
    fi
  fi
fi

seg_lines=""
lines_total=0
[ -n "$lines_add" ] && lines_total=$((lines_total + lines_add))
[ -n "$lines_del" ] && lines_total=$((lines_total + lines_del))
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
```

- [ ] **Step 4: Lancer les tests**

Run: `cd /tmp/claude-statusline && sh test.sh`
Expected: Les segments sont construits (le output final n'est pas encore assemblé, mais pas d'erreur)

- [ ] **Step 5: Commit**

```bash
cd /tmp/claude-statusline
git add statusline-command.sh
git commit -m "feat: build all segment types (always, tier2, tier3)"
```

---

### Task 3: Assemblage adaptatif et output final

**Files:**
- Modify: `statusline-command.sh`

- [ ] **Step 1: Écrire la logique d'assemblage avec adaptation largeur**

Ajouter à la fin du script :

```sh
# --- Assembly with adaptive width ---
SEP=" \033[90m│\033[0m "

# Build segment lists by tier
always=""
always="${seg_header}${SEP}${seg_model}"
[ -n "$seg_5h" ] && always="${always}${SEP}${seg_5h}"
always="${always}${SEP}${seg_peak}"

# Tier 2 segments (order = drop order reversed: wt, ag, ctx, cost)
t2_cost="$seg_cost"
t2_ctx="$seg_ctx"
t2_ag="$seg_ag"
t2_wt="$seg_wt"

# Tier 3 segments (order = drop order reversed: 7d, dur, lines)
t3_7d="$seg_7d"
t3_dur="$seg_dur"
t3_lines="$seg_lines"

# Get terminal width
term_w=$(tput cols 2>/dev/null || echo 120)

# Start with all tiers
output="$always"
# Append tier 2 (in display order: ctx, cost, wt, ag)
[ -n "$t2_ctx" ] && output="${output}${SEP}${t2_ctx}"
[ -n "$t2_cost" ] && output="${output}${SEP}${t2_cost}"
[ -n "$t2_wt" ] && output="${output}${SEP}${t2_wt}"
[ -n "$t2_ag" ] && output="${output}${SEP}${t2_ag}"
# Append tier 3 (in display order: 7d, dur, lines)
[ -n "$t3_7d" ] && output="${output}${SEP}${t3_7d}"
[ -n "$t3_dur" ] && output="${output}${SEP}${t3_dur}"
[ -n "$t3_lines" ] && output="${output}${SEP}${t3_lines}"

# Check width, drop tier 3 first, then tier 2
cur_len=$(visible_len "$output")
if [ "$cur_len" -gt "$term_w" ]; then
  # Rebuild without tier 3 segments, drop in order: lines, dur, 7d
  output="$always"
  [ -n "$t2_ctx" ] && output="${output}${SEP}${t2_ctx}"
  [ -n "$t2_cost" ] && output="${output}${SEP}${t2_cost}"
  [ -n "$t2_wt" ] && output="${output}${SEP}${t2_wt}"
  [ -n "$t2_ag" ] && output="${output}${SEP}${t2_ag}"
  [ -n "$t3_7d" ] && { test_out="${output}${SEP}${t3_7d}"; tl=$(visible_len "$test_out"); [ "$tl" -le "$term_w" ] && output="$test_out"; }
  [ -n "$t3_dur" ] && { test_out="${output}${SEP}${t3_dur}"; tl=$(visible_len "$test_out"); [ "$tl" -le "$term_w" ] && output="$test_out"; }
  [ -n "$t3_lines" ] && { test_out="${output}${SEP}${t3_lines}"; tl=$(visible_len "$test_out"); [ "$tl" -le "$term_w" ] && output="$test_out"; }
fi

cur_len=$(visible_len "$output")
if [ "$cur_len" -gt "$term_w" ]; then
  # Rebuild without tier 2 and tier 3, try adding back in reverse drop order
  output="$always"
  [ -n "$t2_wt" ] && { test_out="${output}${SEP}${t2_wt}"; tl=$(visible_len "$test_out"); [ "$tl" -le "$term_w" ] && output="$test_out"; }
  [ -n "$t2_ag" ] && { test_out="${output}${SEP}${t2_ag}"; tl=$(visible_len "$test_out"); [ "$tl" -le "$term_w" ] && output="$test_out"; }
  [ -n "$t2_ctx" ] && { test_out="${output}${SEP}${t2_ctx}"; tl=$(visible_len "$test_out"); [ "$tl" -le "$term_w" ] && output="$test_out"; }
  [ -n "$t2_cost" ] && { test_out="${output}${SEP}${t2_cost}"; tl=$(visible_len "$test_out"); [ "$tl" -le "$term_w" ] && output="$test_out"; }
fi

printf '%b' "$output"
```

- [ ] **Step 2: Lancer les tests complets**

Run: `cd /tmp/claude-statusline && sh test.sh`
Expected: 5 scénarios de test produisent un output coloré correct. Vérifier visuellement que :
- Test 1 : tous les segments visibles (terminal large)
- Test 2 : rate limit 7j visible (> 50%), barres rouges/jaunes
- Test 3 : tags worktree `my-feature` et agent `security` en cyan
- Test 4 : seulement modèle + ctx + peak (pas de rate limit ni cost)
- Test 5 : juste `➜ user null │ Claude │ peak/off-peak`

- [ ] **Step 3: Commit**

```bash
cd /tmp/claude-statusline
git add statusline-command.sh
git commit -m "feat: adaptive width assembly with priority-based segment dropping"
```

---

### Task 4: Déploiement et push

**Files:**
- Modify: `statusline-command.sh` (copie vers ~/.claude/)

- [ ] **Step 1: Copier le script vers ~/.claude/**

```bash
cp /tmp/claude-statusline/statusline-command.sh /Users/adev/.claude/statusline-command.sh
```

- [ ] **Step 2: Vérification finale avec données réelles**

Relancer Claude Code et vérifier visuellement que la status line s'affiche correctement.

- [ ] **Step 3: Push le repo GitHub**

```bash
cd /tmp/claude-statusline
git push origin master
```

- [ ] **Step 4: Mettre à jour le README avec les nouvelles fonctionnalités**

Mettre à jour `README.md` pour documenter les nouveaux segments (coût, durée, lignes, worktree, agent, 7j) et l'adaptation largeur.

- [ ] **Step 5: Commit et push final**

```bash
cd /tmp/claude-statusline
git add README.md
git commit -m "docs: update README for v2 features"
git push origin master
```
