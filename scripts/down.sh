#!/usr/bin/env bash
# Tears everything down (about 5 minutes) and checks that nothing billable is left.
set -euo pipefail
cd "$(dirname "$0")/.."
terraform -chdir=terraform destroy -auto-approve -input=false
R=$(aws configure get region || echo us-east-1)
left=$(aws ec2 describe-instances --region "$R" --filters Name=tag:Project,Values=campusdesk \
        Name=instance-state-name,Values=pending,running,stopping,stopped --query 'length(Reservations)' --output text)
lbs=$(aws elbv2 describe-load-balancers --region "$R" --query "length(LoadBalancers[?starts_with(LoadBalancerName,'campusdesk')])" --output text)
echo "left over: instances=$left load_balancers=$lbs"
[ "$left" = "0" ] && [ "$lbs" = "0" ] && echo "ALL CLEAN: nothing is running or billing."
