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
