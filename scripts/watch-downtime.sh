#!/usr/bin/env bash
# Hits the site twice a second during a deploy and proves (or disproves) zero downtime.
#   scripts/watch-downtime.sh http://<alb-dns> [max-seconds]
# Stops after max-seconds, on Ctrl+C, or when the file /tmp/watch-downtime.stop appears.
URL=${1:?usage: watch-downtime.sh <url> [max-seconds]}
DURATION=${2:-600}
STOP=/tmp/watch-downtime.stop
rm -f "$STOP"
declare -A seen
ok=0; fail=0; end=$((SECONDS + DURATION)); next_report=$((SECONDS + 10)); stop=0
trap 'stop=1' INT TERM

report() {
  local v=""; for k in "${!seen[@]}"; do v="$v $k x${seen[$k]}"; done
  echo "$(date +%T)  requests: $((ok + fail))  ok: $ok  FAILED: $fail  | versions served:$v"
}

echo "Watching $URL"
while [ $stop -eq 0 ] && [ $SECONDS -lt $end ] && [ ! -f "$STOP" ]; do
  out=$(curl -s --max-time 3 -w ' %{http_code}' "$URL/health")
  code=${out##* }
  if [ "$code" = "200" ]; then
    ok=$((ok + 1))
    v=$(echo "${out% *}" | jq -r .version)
    seen[$v]=$(( ${seen[$v]:-0} + 1 ))
  else
    fail=$((fail + 1)); echo "$(date +%T)  FAIL  HTTP $code"
  fi
  if [ $SECONDS -ge $next_report ]; then report; next_report=$((SECONDS + 10)); fi
  sleep 0.5
done
echo "==== FINAL ===="
report
[ "$fail" -eq 0 ] && echo "RESULT: ZERO DOWNTIME (0 failed requests)" || echo "RESULT: $fail FAILED REQUESTS"
