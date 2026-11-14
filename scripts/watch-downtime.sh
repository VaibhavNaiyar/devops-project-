#!/usr/bin/env bash
# Hits the site continuously during a deploy and proves (or disproves) zero downtime.
#   scripts/watch-downtime.sh http://<alb-dns> [seconds]
URL=${1:?usage: watch-downtime.sh <url> [seconds]}
DURATION=${2:-300}
ok=0; fail=0; end=$((SECONDS + DURATION)); last=""
summary() {
  echo; echo "==== $((ok + fail)) requests: $ok OK, $fail FAILED ===="
  [ "$fail" -eq 0 ] && echo "ZERO DOWNTIME" ; exit 0
}
trap summary INT TERM
while [ $SECONDS -lt $end ]; do
  out=$(curl -s --max-time 3 -w ' %{http_code}' "$URL/health")
  code=${out##* }
  if [ "$code" = "200" ]; then
    ok=$((ok + 1))
    line="$(echo "${out% *}" | jq -r '"\(.version)  \(.host)"')"
    [ "$line" != "$last" ] && echo "$(date +%T)  OK    $line" && last=$line
  else
    fail=$((fail + 1)); echo "$(date +%T)  FAIL  HTTP $code"
  fi
  sleep 0.5
done
summary
