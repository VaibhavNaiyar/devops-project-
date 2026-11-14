#!/usr/bin/env bash
# Admin helper: trigger the campusdesk job through the Jenkins API, wait for it, print the stage results.
#   scripts/jenkins-build.sh <jenkins-url> [SIMULATE_BAD_RELEASE=true]
set -euo pipefail
J=${1:?usage: jenkins-build.sh <jenkins-url> [PARAM=value]}
PARAM=${2:-}
AUTH="admin:$(cat ~/.campusdesk/jenkins-admin-password)"
JAR=$(mktemp)
crumb=$(curl -s -c "$JAR" -u "$AUTH" "$J/crumbIssuer/api/json" | jq -r '.crumbRequestField + ":" + .crumb')
next=$(curl -s -u "$AUTH" "$J/job/campusdesk/api/json" | jq -r .nextBuildNumber)
# parameterised jobs need buildWithParameters; a brand-new job (Jenkinsfile never run yet) only accepts build
code=$(curl -s -o /dev/null -w '%{http_code}' -b "$JAR" -u "$AUTH" -H "$crumb" -X POST "$J/job/campusdesk/buildWithParameters?${PARAM}")
[ "$code" = "400" ] && code=$(curl -s -o /dev/null -w '%{http_code}' -b "$JAR" -u "$AUTH" -H "$crumb" -X POST "$J/job/campusdesk/build")
[ "$code" = "201" ] || { echo "trigger failed: HTTP $code"; exit 1; }
echo "triggered build #$next (HTTP $code)"
until curl -s -u "$AUTH" "$J/job/campusdesk/$next/api/json" 2>/dev/null | jq -e '.building == false' >/dev/null 2>&1; do sleep 10; done
curl -s -u "$AUTH" "$J/job/campusdesk/$next/api/json" | jq -r '"result: \(.result)  \(.displayName)"'
curl -s -u "$AUTH" "$J/job/campusdesk/$next/wfapi/describe" | jq -r '.stages[] | "  \(.status | .[0:8])\t\(.durationMillis/1000 | floor)s\t\(.name)"'
curl -s -u "$AUTH" "$J/job/campusdesk/$next/consoleText" > "/tmp/campusdesk-build-$next.log"
echo "console: /tmp/campusdesk-build-$next.log"
rm -f "$JAR"
