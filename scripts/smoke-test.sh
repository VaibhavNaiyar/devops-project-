#!/usr/bin/env bash
# Smoke test through the load balancer: every server must run the expected version, and the API must work end-to-end.
#   scripts/smoke-test.sh http://<alb-dns> <expected-version>
set -euo pipefail
URL=${1:?usage: smoke-test.sh <url> <expected-version>}
EXPECTED=${2:?usage: smoke-test.sh <url> <expected-version>}

echo "Smoke test $URL (expecting version $EXPECTED)"
hosts=""
for i in $(seq 1 10); do
  body=$(curl -fsS --max-time 5 "$URL/health")
  version=$(echo "$body" | jq -r .version)
  host=$(echo "$body" | jq -r .host)
  [ "$version" = "$EXPECTED" ] || { echo "FAIL: $host answered version $version"; exit 1; }
  hosts="$hosts $host"
done
echo "  /health: 10/10 OK, servers seen:$(echo "$hosts" | tr ' ' '\n' | sort -u | tr '\n' ' ')"

id=$(curl -fsS --max-time 5 -H 'Content-Type: application/json' \
  -d "{\"title\":\"Smoke test $EXPECTED\",\"category\":\"IT\",\"location\":\"pipeline\"}" "$URL/api/requests" | jq -r .id)
curl -fsS --max-time 5 "$URL/api/requests" | jq -e --arg id "$id" 'map(.id) | index($id) != null' >/dev/null \
  || { echo "FAIL: created request $id not found"; exit 1; }
curl -fsS --max-time 5 -X PATCH -H 'Content-Type: application/json' -d '{"status":"Resolved"}' "$URL/api/requests/$id" >/dev/null
echo "  API: create -> list -> update OK (request $id stored in DynamoDB)"
echo "SMOKE TEST PASSED"
