pipeline {
  // Runs on Kubernetes: uses Kaniko to build images without a Docker daemon.
  // Kaniko works natively in containers/Kubernetes.
  agent any
  // timestamps() option: install 'Timestamper' plugin to enable, or uncomment below
  // options { timestamps() }
  environment {
    IMAGE_NAME = 'papermc'
    IMAGE_TAG = '1.21.4' // set to 1.21.4 for PaperMC 1.21.4
    GRADLE_JAVA_IMAGE = 'eclipse-temurin:21-jdk' // Gradle/Kotlin DSL runs under Java 21 for compatibility
    PUSH_IMAGE = 'true' // push to docker.lsgserver.dev registry
    REGISTRY = 'docker.lsgserver.dev' // registry host
    REG_CRED = 'registry-auth' // Jenkins credentialsId for registry authentication
    ARTIFACTS_DIR = 'artifacts' // local directory to collect JARs
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Verify Java 25') {
      steps {
        script {
          echo 'Checking for Java 25...'
          sh '''
            java -version 2>&1
            JAVA_VERSION=$(java -version 2>&1 | grep -oP '(?<=version ")(\\d+)' | head -1)
            echo "Detected Java version: $JAVA_VERSION"
            if [ "$JAVA_VERSION" != "21" ]; then
              echo "⚠️  WARNING: Java version is $JAVA_VERSION, but Paper 1.21.4 requires Java 21"
              echo "To fix this in Kubernetes Jenkins, ensure the pod has Java 25 installed"
              echo "export JAVA_HOME to point to Java 21 installation"
              exit 1
            else
              echo "✅ Java 21 detected"
            fi
          '''
        }
      }
    }

    stage('Build with Gradle') {
      steps {
        script {
          echo 'Building PaperMC with Gradle inside a Java 21 container...'
          sh '''
            command -v docker >/dev/null 2>&1 || { echo "ERROR: docker CLI not found; DinD sidecar is required for the Java 21 Gradle container."; exit 1; }

            # Ensure gradlew is executable
            chmod +x ./gradlew

            # Run the gradle build using Java 21 so Kotlin DSL can initialize correctly
            docker run --rm \
              -u "$(id -u):$(id -g)" \
              -e HOME=/tmp \
              -e GRADLE_USER_HOME=/workspace/.gradle \
              -v "$(pwd):/workspace" \
              -w /workspace \
              "${GRADLE_JAVA_IMAGE}" \
              ./gradlew --no-daemon --stacktrace clean build
          '''
        }
      }
    }

    stage('Build Docker Image with DinD') {
      steps {
        script {
          // Compute image tag: prefer static IMAGE_TAG from env
          def tag = env.IMAGE_TAG?.trim() ?: (env.BUILD_NUMBER ?: 'latest')
          env.IMAGE_TAG = tag

          // Check if we should push to registry
          if (env.PUSH_IMAGE == 'true' && env.REGISTRY?.trim()) {
            def registryImage = "${env.REGISTRY}/${env.IMAGE_NAME}:${env.IMAGE_TAG}"
            echo "Building and pushing Docker image to: ${registryImage}"

            if (env.REG_CRED?.trim()) {
              // Use Jenkins credentials for registry authentication
              withCredentials([usernamePassword(credentialsId: "${env.REG_CRED}", passwordVariable: 'REG_PASS', usernameVariable: 'REG_USER')]) {
                sh '''
                  echo "Logging in to Docker registry ${REGISTRY}..."
                  echo "${REG_PASS}" | docker login -u "${REG_USER}" --password-stdin "${REGISTRY}"

                  echo "Building Docker image: ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
                  docker build -f Dockerfile.runtime -t "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}" .

                  echo "Pushing image to registry..."
                  docker push "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

                  echo "Logging out..."
                  docker logout "${REGISTRY}"

                  echo "✅ Docker image successfully pushed: ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
                '''
              }
            } else {
              echo "❌ ERROR: REG_CRED not set. Cannot push without credentials."
              sh 'exit 1'
            }
          } else {
            echo "⚠️ PUSH_IMAGE is false or REGISTRY not set. Skipping Docker push."
            echo "Building local Docker image for inspection..."
            sh 'docker build -f Dockerfile.runtime -t "${IMAGE_NAME}:${IMAGE_TAG}" .'
          }
        }
      }
    }

    stage('Extract Artifacts') {
      steps {
        script {
          echo 'Collecting build artifacts from Gradle build...'
          sh '''
            mkdir -p ${ARTIFACTS_DIR}
            # Find all JARs from the gradle build directories and copy to artifacts
            find . -type f -path "*/build/libs/*.jar" -exec cp {} ${ARTIFACTS_DIR}/ \\;

            echo "Artifacts collected:"
            ls -lah ${ARTIFACTS_DIR}/ || echo "No artifacts found"
          '''
        }
      }
    }

    stage('Archive Artifacts') {
      steps {
        archiveArtifacts artifacts: 'artifacts/**', fingerprint: true
      }
    }

    stage('Verify Image') {
      when {
        expression { return env.PUSH_IMAGE == 'true' && env.REGISTRY?.trim() }
      }
      steps {
        script {
          echo "✅ Docker image successfully built and pushed!"
          echo "Image: ${env.REGISTRY}/${env.IMAGE_NAME}:${env.IMAGE_TAG}"
          sh 'docker images | grep -E "REPOSITORY|${IMAGE_NAME}"'
        }
      }
    }
  }

  post {
    always {
      echo 'Cleaning up temporary files and archiving artifacts'
      sh '''
        # Clean up tar files if they exist
        rm -f ${ARTIFACTS_DIR}/image.tar
        # List what we're archiving
        echo "Contents of ${ARTIFACTS_DIR}:"
        ls -la ${ARTIFACTS_DIR} || echo "No artifacts directory found"
      '''
      // Archive the artifacts directory
      archiveArtifacts artifacts: "${ARTIFACTS_DIR}/**", allowEmptyArchive: true, fingerprint: true
    }
  }
}

