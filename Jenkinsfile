// CampusDesk CI/CD - triggered by a GitHub webhook on every push to main.
// Release settings (ECR repo, ALB, target group, live tag) come from SSM Parameter Store, written by Terraform.

def ssm(String name) {
    return sh(script: "aws ssm get-parameter --name /campusdesk/${name} --query Parameter.Value --output text", returnStdout: true).trim()
}

pipeline {
    agent any

    options {
        timestamps()
        ansiColor('xterm')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 30, unit: 'MINUTES')
    }

    parameters {
        booleanParam(name: 'SIMULATE_BAD_RELEASE', defaultValue: false,
            description: 'Demo: deploy a release whose /health fails, to show the automatic rollback')
    }

    environment {
        AWS_REGION               = 'us-east-1'
        AWS_DEFAULT_REGION       = 'us-east-1'
        ANSIBLE_CONFIG           = "${WORKSPACE}/ansible/ansible.cfg"
        ANSIBLE_PRIVATE_KEY_FILE = '/var/lib/jenkins/.ssh/campusdesk.pem'
        ANSIBLE_USE_PRIVATE_IP   = '1'
        ANSIBLE_FORCE_COLOR      = 'true'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.APP_VERSION  = sh(script: 'jq -r .version app/package.json', returnStdout: true).trim()
                    env.GIT_SHORT    = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.IMAGE_TAG    = "${env.APP_VERSION}-b${env.BUILD_NUMBER}-${env.GIT_SHORT}"
                    env.ECR_REPO     = ssm('ecr_repo_url')
                    env.ALB_DNS      = ssm('alb_dns')
                    env.PREVIOUS_TAG = ssm('live_tag')
                    currentBuild.displayName = "#${env.BUILD_NUMBER} ${env.IMAGE_TAG}"
                    echo "Releasing ${env.IMAGE_TAG} (currently live: ${env.PREVIOUS_TAG})"
                }
            }
        }

        stage('Unit tests') {
            steps {
                sh '''
                  docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -v "$WORKSPACE/app:/app" -w /app node:20-alpine \
                    sh -c "npm ci --no-audit --no-fund && npm test && npm audit --omit=dev --audit-level=high"
                '''
            }
        }

        stage('Validate IaC') {
            parallel {
                stage('Terraform') {
                    steps {
                        sh '''
                          docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -v "$WORKSPACE/terraform:/tf" -w /tf hashicorp/terraform:1.9 fmt -check -recursive
                          docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -v "$WORKSPACE/terraform:/tf" -w /tf --entrypoint sh hashicorp/terraform:1.9 \
                            -c "terraform init -backend=false -input=false >/dev/null && terraform validate"
                        '''
                    }
                }
                stage('Ansible') {
                    steps {
                        sh 'ansible-playbook -i localhost, --syntax-check ansible/site.yml ansible/deploy.yml'
                    }
                }
            }
        }

        stage('Build image') {
            steps {
                sh 'docker build --pull -t "$ECR_REPO:$IMAGE_TAG" app/'
            }
        }

        stage('Security scan (Trivy)') {
            steps {
                // fail the build on any HIGH/CRITICAL vulnerability that has a fix available
                sh '''
                  trivy image --no-progress --severity HIGH,CRITICAL --ignore-unfixed --format table -o trivy-report.txt "$ECR_REPO:$IMAGE_TAG"
                  cat trivy-report.txt
                  trivy image --no-progress --skip-db-update --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --quiet "$ECR_REPO:$IMAGE_TAG"
                '''
            }
        }

        stage('Push to ECR') {
            steps {
                sh 'docker push "$ECR_REPO:$IMAGE_TAG"'
            }
        }

        stage('Rolling deploy (Ansible)') {
            steps {
                script { env.DEPLOY_STARTED = 'true' }
                sh """
                  ansible-playbook ansible/deploy.yml \
                    -e image_tag=${env.IMAGE_TAG} -e previous_tag=${env.PREVIOUS_TAG} \
                    -e fail_health=${params.SIMULATE_BAD_RELEASE ? '1' : '0'}
                """
            }
        }

        stage('Smoke test (through ALB)') {
            steps {
                sh 'scripts/smoke-test.sh "http://$ALB_DNS" "$IMAGE_TAG"'
            }
        }

        stage('Mark release live') {
            steps {
                sh 'aws ssm put-parameter --name /campusdesk/live_tag --value "$IMAGE_TAG" --type String --overwrite >/dev/null'
                echo "LIVE: ${env.IMAGE_TAG} at http://${env.ALB_DNS}"
            }
        }
    }

    post {
        failure {
            script {
                if (env.DEPLOY_STARTED == 'true' && env.PREVIOUS_TAG && env.PREVIOUS_TAG != 'none') {
                    echo "ROLLBACK: restoring ${env.PREVIOUS_TAG} on every server"
                    sh "ansible-playbook ansible/deploy.yml -e image_tag=${env.PREVIOUS_TAG} -e previous_tag=${env.PREVIOUS_TAG}"
                    sh 'scripts/smoke-test.sh "http://$ALB_DNS" "$PREVIOUS_TAG"'
                    echo "ROLLBACK COMPLETE: ${env.PREVIOUS_TAG} is live again"
                }
            }
        }
        always {
            archiveArtifacts artifacts: 'trivy-report.txt', allowEmptyArchive: true
            sh 'docker image prune -f >/dev/null || true'
        }
    }
}
