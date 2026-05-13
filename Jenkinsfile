pipeline {
  agent any
  environment {
    IMAGE_NAME = 'papermc-builder'
    IMAGE_TAG = 'latest' // override in Jenkins job or leave as 'latest'
    PUSH_IMAGE = 'false' // set to 'true' to push to registry
    REGISTRY = 'docker.lsgserver.dev' // e.g. "registry.example.com" (optional)
    REG_CRED = 'registry-auth' // Jenkins credentialsId for registry (optional)
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build Docker Image') {
      steps {
        echo "Building Docker image ${IMAGE_NAME}:${IMAGE_TAG}"
        sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
      }
    }

    stage('Extract Artifacts') {
      steps {
        echo 'Creating container and extracting build artifacts'
        sh '''
        mkdir -p artifacts
        CONTAINER=$(docker create ${IMAGE_NAME}:${IMAGE_TAG})
        # Copy the artifacts directory from the runtime image
        docker cp ${CONTAINER}:/opt/app ./artifacts || true
        docker rm ${CONTAINER} || true
        '''
      }
    }

    stage('Archive Artifacts') {
      steps {
        archiveArtifacts artifacts: 'artifacts/**', fingerprint: true
      }
    }

    stage('Push Image') {
      when {
        expression { return env.PUSH_IMAGE == 'true' }
      }
      steps {
        script {
          if (env.REGISTRY?.trim()) {
            sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
          }

          if (env.REG_CRED?.trim()) {
            withCredentials([usernamePassword(credentialsId: "${env.REG_CRED}", passwordVariable: 'REG_PASS', usernameVariable: 'REG_USER')]) {
              sh "echo $REG_PASS | docker login ${env.REGISTRY} -u $REG_USER --password-stdin"
            }
          }

          def target = env.REGISTRY?.trim() ? "${env.REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}" : "${IMAGE_NAME}:${IMAGE_TAG}"
          sh "docker push ${target}"
        }
      }
    }
  }

  post {
    always {
      echo 'Cleaning up local images and ensuring artifacts are archived'
      sh '''
      # Attempt to remove the built image to keep nodes tidy
      docker images --filter=reference="${IMAGE_NAME}*" -q | xargs -r docker rmi -f || true
      '''
      // ensure artifacts are available even on failure
      archiveArtifacts artifacts: 'artifacts/**', onlyIfSuccessful: false
    }
  }
}

