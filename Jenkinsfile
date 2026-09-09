// Top-level multi-env pipeline: build once, promote the SAME image digest
// dev -> staging -> prod (manual approval before prod). One pipeline only.
// Runs on ephemeral Docker agents labeled docker-build / docker-dev /
// docker-staging / docker-prod (see jenkins/controller/casc/clouds.yaml).
//
// Deploy = run the immutable image on the env-labeled agent and health-check it.
// Swap the run/health block for a real target (compose/k8s/ssh) per env when
// live deploy infra exists; keep the env-gated promotion shape unchanged.

pipeline {
  agent none

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  parameters {
    string(name: 'REGISTRY_HOST', defaultValue: 'registry:5000',
           description: 'Registry host:port images are pushed to / pulled from.')
    string(name: 'IMAGE_REPO', defaultValue: 'jenkins-multi-agent/sample-app',
           description: 'Image repository name under REGISTRY_HOST.')
    string(name: 'TARGET_ENV', defaultValue: 'prod',
           description: 'Highest environment to promote to: dev | staging | prod')
  }

  environment {
    REGISTRY_HOST = "${params.REGISTRY_HOST}"
    IMAGE_REPO = "${params.IMAGE_REPO}"
  }

  stages {

    stage('Build & test') {
      agent { label 'docker-build' }
      steps {
        checkout scm
        script {
          env.GIT_COMMIT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          env.IMAGE_TAG = "${env.REGISTRY_HOST}/${env.IMAGE_REPO}:${env.GIT_COMMIT}"
          echo "Promoting image ${env.IMAGE_TAG}"
        }
        dir('apps/sample-app') {
          sh 'python3 -m venv .venv'
          sh '.venv/bin/pip install --upgrade pip && .venv/bin/pip install -r requirements-dev.txt'
          sh '.venv/bin/pytest -q'
        }
      }
    }

    stage('Containerize & push') {
      agent { label 'docker-build' }
      steps {
        checkout scm
        script {
          env.GIT_COMMIT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          env.IMAGE_TAG = "${env.REGISTRY_HOST}/${env.IMAGE_REPO}:${env.GIT_COMMIT}"
        }
        dir('apps/sample-app') {
          withCredentials([usernamePassword(
              credentialsId: 'registry-dev',
              usernameVariable: 'REG_USER',
              passwordVariable: 'REG_PASS')]) {
            sh """
              set -eu
              if [ -n "\$REG_USER" ]; then
                echo "\$REG_PASS" | docker login "${env.REGISTRY_HOST}" -u "\$REG_USER" --password-stdin
              fi
              docker build -t "${env.IMAGE_TAG}" .
              docker push "${env.IMAGE_TAG}"
              docker logout "${env.REGISTRY_HOST}" 2>/dev/null || true
            """
          }
        }
      }
    }

    stage('Deploy dev') {
      when { expression { return params.TARGET_ENV in ['dev', 'staging', 'prod'] } }
      agent { label 'docker-dev' }
      steps { script { deploy('dev', 'registry-dev', 'deploy-dev') } }
    }

    stage('Deploy staging') {
      when { expression { return params.TARGET_ENV in ['staging', 'prod'] } }
      agent { label 'docker-staging' }
      steps { script { deploy('staging', 'registry-staging', 'deploy-staging') } }
    }

    stage('Deploy prod') {
      when { expression { return params.TARGET_ENV == 'prod' } }
      agent { label 'docker-prod' }
      steps {
        input message: 'Promote to production?', ok: 'Promote'
        script { deploy('prod', 'registry-prod', 'deploy-prod') }
      }
    }

  }

  post {
    always {
      cleanWs()
    }
  }
}

// Promote the immutable digest into one environment: pull with that env's
// registry credentials, run it with APP_ENV set, health-check, then stop it.
def deploy(String envName, String registryCred, String deployCred) {
  withCredentials([
      usernamePassword(credentialsId: registryCred,
                       usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS'),
      string(credentialsId: deployCred, variable: 'DEPLOY_TOKEN')]) {
    sh """
      set -eu
      if [ -n "\$REG_USER" ]; then
        echo "\$REG_PASS" | docker login "${env.REGISTRY_HOST}" -u "\$REG_USER" --password-stdin
      fi
      docker pull "${env.IMAGE_TAG}"
      CID=\$(docker run -d -e APP_ENV=${envName} -e DEPLOY_TOKEN="\$DEPLOY_TOKEN" "${env.IMAGE_TAG}")
      trap 'docker rm -f "\$CID" >/dev/null 2>&1 || true' EXIT
      CONTAINER_IP=\$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' "\$CID" | awk '{print \$1}')
      for i in \$(seq 1 30); do
        if curl -fsS "http://\${CONTAINER_IP}:8000/health" | grep -Fq '"environment":"${envName}"'; then
          echo "health ok in ${envName}"
          exit 0
        fi
        sleep 1
      done
      echo "health check failed in ${envName}" >&2
      exit 1
    """
  }
}
