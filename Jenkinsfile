pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-south-1'
        ECR_REGISTRY = '506456084381.dkr.ecr.ap-south-1.amazonaws.com'
        ECR_URI = '506456084381.dkr.ecr.ap-south-1.amazonaws.com/techcake-django-app-v3'
        APP_INSTANCE = 'i-0469d99aa3e2a6a7a'
        HEALTH_URL = 'https://djangov2.tc-2026-0053.nixlabs.in/health'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.IMAGE_TAG = sh(
                        script: 'git rev-parse HEAD',
                        returnStdout: true
                    ).trim()
                    echo "Commit SHA: ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Test') {
            steps {
                sh '''
                    docker run --rm \
                      -v "$WORKSPACE:/app" \
                      -w /app \
                      -e DB_ENGINE=sqlite \
                      -e APP_VERSION="$IMAGE_TAG" \
                      python:3.12-slim \
                      sh -c "pip install --no-cache-dir -r requirements.txt && python manage.py test"
                '''
            }
        }

        stage('Build') {
            steps {
                sh '''
                    docker build \
                      --build-arg APP_VERSION=${IMAGE_TAG} \
                      -t ${ECR_URI}:${IMAGE_TAG} .
                '''
            }
        }

        stage('Scan') {
            steps {
                sh '''
                    trivy image \
                      --scanners vuln \
                      --format json \
                      --output trivy-report.json \
                      --severity CRITICAL \
                      --exit-code 0 \
                      ${ECR_URI}:${IMAGE_TAG}

                    trivy image \
                      --scanners vuln \
                      --severity CRITICAL \
                      --exit-code 1 \
                      ${ECR_URI}:${IMAGE_TAG}
                '''
            }
        }

        stage('Push') {
            steps {
                sh '''
                    aws ecr get-login-password --region ${AWS_REGION} |
                    docker login --username AWS --password-stdin ${ECR_REGISTRY}

                    docker push ${ECR_URI}:${IMAGE_TAG}
                '''
            }
        }

        stage('Deploy') {
            steps {
                sh '''
                    set -euo pipefail

                    send_ssm() {
                        SCRIPT_TEXT="$1" python3 -c \
                          'import json,os; print(json.dumps({"commands":[os.environ["SCRIPT_TEXT"]]}))' \
                          > /tmp/jenkins-ssm-params.json

                        COMMAND_ID=$(aws ssm send-command \
                          --region ${AWS_REGION} \
                          --instance-ids ${APP_INSTANCE} \
                          --document-name AWS-RunShellScript \
                          --parameters file:///tmp/jenkins-ssm-params.json \
                          --query 'Command.CommandId' \
                          --output text)

                        echo "SSM Command ID: $COMMAND_ID"

                        for attempt in $(seq 1 60); do
                            STATUS=$(aws ssm get-command-invocation \
                              --region ${AWS_REGION} \
                              --command-id "$COMMAND_ID" \
                              --instance-id ${APP_INSTANCE} \
                              --query Status --output text 2>/dev/null || true)

                            if [ "$STATUS" = "Success" ]; then
                                return 0
                            fi

                            case "$STATUS" in
                                Failed|Cancelled|TimedOut|Undeliverable|Terminated)
                                    aws ssm get-command-invocation \
                                      --region ${AWS_REGION} \
                                      --command-id "$COMMAND_ID" \
                                      --instance-id ${APP_INSTANCE} \
                                      --output json || true
                                    return 1
                                    ;;
                            esac

                            sleep 5
                        done

                        echo "SSM command timed out"
                        return 1
                    }

                    DEPLOY_SCRIPT=$(printf '%s\n' \
                        'set -euo pipefail' \
                        'cd /opt/techcake-django-app-v2' \
                        'PREVIOUS_SHA=$(cat .last-good-sha)' \
                        'echo "$PREVIOUS_SHA" > .rollback-sha' \
                        "echo 'APP_VERSION=${IMAGE_TAG}' > .deploy.env" \
                        "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}" \
                        'docker compose --env-file .deploy.env pull django' \
                        'docker compose --env-file .deploy.env up -d django'
                    )

                    if ! send_ssm "$DEPLOY_SCRIPT"; then
                        echo "Deployment failed. Starting rollback."

                        ROLLBACK_SCRIPT=$(printf '%s\n'' \
                            'set -euo pipefail' \
                            'cd /opt/techcake-django-app-v2' \
                            'PREVIOUS_SHA=$(cat .rollback-sha)' \
                            'echo "APP_VERSION=$PREVIOUS_SHA" > .deploy.env' \
                            "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}" \
                            'docker compose --env-file .deploy.env pull django' \
                            'docker compose --env-file .deploy.env up -d django'
                        )

                        if send_ssm "$ROLLBACK_SCRIPT"; then
                            echo "Rollback completed. Pipeline will fail."
                        else
                            echo "CRITICAL: Automatic rollback command failed."
                        fi

                        exit 1
                    fi

                    echo "Deployment command completed. Proceeding to health verification."
                '''
            }
        }

        stage('Verify') {
            steps {
                sh '''
                    set -euo pipefail

                    send_ssm() {
                        SCRIPT_TEXT="$1" python3 -c \
                          'import json,os; print(json.dumps({"commands":[os.environ["SCRIPT_TEXT"]]}))' \
                          > /tmp/jenkins-ssm-params.json

                        COMMAND_ID=$(aws ssm send-command \
                          --region ${AWS_REGION} \
                          --instance-ids ${APP_INSTANCE} \
                          --document-name AWS-RunShellScript \
                          --parameters file:///tmp/jenkins-ssm-params.json \
                          --query 'Command.CommandId' \
                          --output text)

                        echo "SSM Command ID: $COMMAND_ID"

                        for attempt in $(seq 1 60); do
                            STATUS=$(aws ssm get-command-invocation \
                              --region ${AWS_REGION} \
                              --command-id "$COMMAND_ID" \
                              --instance-id ${APP_INSTANCE} \
                              --query Status --output text 2>/dev/null || true)

                            if [ "$STATUS" = "Success" ]; then
                                return 0
                            fi

                            case "$STATUS" in
                                Failed|Cancelled|TimedOut|Undeliverable|Terminated)
                                    aws ssm get-command-invocation \
                                      --region ${AWS_REGION} \
                                      --command-id "$COMMAND_ID" \
                                      --instance-id ${APP_INSTANCE} \
                                      --output json || true
                                    return 1
                                    ;;
                            esac

                            sleep 5
                        done

                        echo "SSM command timed out"
                        return 1
                    }

                    HEALTHY=false

                    for attempt in $(seq 1 18); do
                        RESPONSE=$(curl -fsS --max-time 10 ${HEALTH_URL} || true)

                        VERSION=$(echo "$RESPONSE" | python3 -c \
                          'import json,sys; print(json.load(sys.stdin).get("version",""))' 2>/dev/null || true)

                        STATUS=$(echo "$RESPONSE" | python3 -c \
                          'import json,sys; print(json.load(sys.stdin).get("status",""))' 2>/dev/null || true)

                        if [ "$STATUS" = "ok" ] && [ "$VERSION" = "${IMAGE_TAG}" ]; then
                            HEALTHY=true
                            break
                        fi

                        echo "Waiting for correct version: $attempt/18"
                        sleep 10
                    done

                    if [ "$HEALTHY" = false ]; then
                        echo "Verification failed. Starting rollback."

                        ROLLBACK_SCRIPT=$(printf '%s\n' \
                            'set -euo pipefail' \
                            'cd /opt/techcake-django-app-v2' \
                            'PREVIOUS_SHA=$(cat .rollback-sha)' \
                            'echo "APP_VERSION=$PREVIOUS_SHA" > .deploy.env' \
                            "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}" \
                            'docker compose --env-file .deploy.env pull django' \
                            'docker compose --env-file .deploy.env up -d django'
                        )

                        if send_ssm "$ROLLBACK_SCRIPT"; then
                            echo "Rollback completed."
                        else
                            echo "CRITICAL: Automatic rollback command failed."
                        fi

                        exit 1
                    fi

                    SAVE_SCRIPT=$(printf '%s\n' \
                        'set -euo pipefail' \
                        'cd /opt/techcake-django-app-v2' \
                        "echo '${IMAGE_TAG}' > .last-good-sha" \
                        'rm -f .rollback-sha'
                    )

                    send_ssm "$SAVE_SCRIPT"

                    echo "Deployment verified: ${IMAGE_TAG}"
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'trivy-report.json',
                             allowEmptyArchive: true
        }
    }
}
