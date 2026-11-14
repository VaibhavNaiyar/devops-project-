#!/usr/bin/env bash
# One command to bring the whole project up (about 10-12 minutes):
#   scripts/up.sh            infrastructure + server setup
#   scripts/up.sh --deploy   ...and run the first pipeline build
set -euo pipefail
cd "$(dirname "$0")/.."
export ANSIBLE_CONFIG=$PWD/ansible/ansible.cfg

echo "== 1/4 Terraform: creating AWS resources"
terraform -chdir=terraform init -input=false -upgrade=false >/dev/null
terraform -chdir=terraform apply -auto-approve -input=false

echo "== 2/4 Waiting for the servers to accept SSH"
ansible all -m ansible.builtin.wait_for_connection -a "timeout=300" -o >/dev/null

echo "== 3/4 Ansible: configuring Jenkins and the app servers"
ansible-playbook ansible/site.yml

JENKINS=$(terraform -chdir=terraform output -raw jenkins_url)
APP=$(terraform -chdir=terraform output -raw app_url)
until curl -s -o /dev/null -w '%{http_code}' "$JENKINS/login" | grep -q 200; do sleep 5; done

if [ "${1:-}" = "--deploy" ]; then
  echo "== 4/4 First pipeline build"
  scripts/jenkins-build.sh "$JENKINS"
else
  echo "== 4/4 skipped first build (run: scripts/jenkins-build.sh $JENKINS)"
fi

cat <<MSG

READY
  App:      $APP
  Jenkins:  $JENKINS   (admin / $(cat ~/.campusdesk/jenkins-admin-password))
  Webhook:  $(terraform -chdir=terraform output -raw github_webhook_url)
            Jenkins gets a new IP each time: update the URL in GitHub -> Settings -> Webhooks.
  Alerts:   confirm the "AWS Notification - Subscription Confirmation" e-mail.
MSG
