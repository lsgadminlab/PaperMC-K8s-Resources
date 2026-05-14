pipeline {
  // Runs on Kubernetes: uses Kaniko to build images without a Docker daemon.
  // Kaniko works natively in containers/Kubernetes.
  agent any
  // timestamps() option: install 'Timestamper' plugin to enable, or uncomment below
  // options { timestamps() }
  environment {
    IMAGE_NAME = 'papermc'
    IMAGE_TAG = '1.21.4' // set to 1.21.4 for PaperMC 1.21.4
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

    stage('Build Docker Image with Kaniko') {
      steps {
        script {
          // Compute image tag: prefer static IMAGE_TAG from env
          def tag = env.IMAGE_TAG?.trim() ?: (env.BUILD_NUMBER ?: 'latest')
          env.IMAGE_TAG = tag

          // Determine build destination: push to registry (if configured) or save as tar
          def kaniko_args = ''
          if (env.PUSH_IMAGE == 'true' && env.REGISTRY?.trim()) {
            def registryImage = "${env.REGISTRY}/${env.IMAGE_NAME}:${env.IMAGE_TAG}"
            kaniko_args = "--destination=${registryImage} --push"
            echo "Kaniko will build and push to registry: ${registryImage}"
          } else {
            // Export image as tar file for local artifact extraction
            kaniko_args = "--tar-path=${env.ARTIFACTS_DIR}/image.tar"
            echo "Kaniko will build and export to tar: ${env.ARTIFACTS_DIR}/image.tar"
          }

          // Use Kaniko via Docker with registry credentials
          // For registry push: provide credentials via withCredentials and docker config
          if (env.PUSH_IMAGE == 'true' && env.REG_CRED?.trim()) {
            // Use Jenkins credentials for registry authentication
            withCredentials([usernamePassword(credentialsId: "${env.REG_CRED}", passwordVariable: 'REG_PASS', usernameVariable: 'REG_USER')]) {
              sh '''
                mkdir -p ${ARTIFACTS_DIR}
                mkdir -p ~/.docker

                # Create docker config for Kaniko to use
                cat > ~/.docker/config.json <<EOF
{
  "auths": {
    "${REGISTRY}": {
      "username": "${REG_USER}",
      "password": "${REG_PASS}",
      "auth": "$(echo -n ${REG_USER}:${REG_PASS} | base64)"
    }
  }
}
EOF

                # Try using kaniko executor directly (for Kubernetes agents with kaniko)
                if command -v /kaniko/executor >/dev/null 2>&1; then
                  /kaniko/executor --context=. --dockerfile=Dockerfile ''' + kaniko_args + ''' --docker-config=/root/.docker
                # Fallback: use Kaniko via Docker image
                elif command -v docker >/dev/null 2>&1; then
                  docker run --rm \
                    -v $(pwd):/workspace \
                    -v ~/.docker:/kaniko/.docker \
                    gcr.io/kaniko-project/executor:latest \
                    --context=/workspace \
                    --dockerfile=/workspace/Dockerfile ''' + kaniko_args + '''
                else
                  echo "ERROR: Neither Kaniko executor nor Docker found"
                  exit 1
                fi
              '''
            }
          } else {
            // No registry push, use Kaniko without credentials
            sh '''
              mkdir -p ${ARTIFACTS_DIR}

              # Try using kaniko executor directly
              if command -v /kaniko/executor >/dev/null 2>&1; then
                /kaniko/executor --context=. --dockerfile=Dockerfile ''' + kaniko_args + '''
              # Fallback: use Kaniko via Docker
              elif command -v docker >/dev/null 2>&1; then
                docker run --rm \
                  -v $(pwd):/workspace \
                  gcr.io/kaniko-project/executor:latest \
                  --context=/workspace \
                  --dockerfile=/workspace/Dockerfile ''' + kaniko_args + '''
              else
                echo "ERROR: Neither Kaniko executor nor Docker found"
                exit 1
              fi
            '''
          }
        }
      }
    }

    stage('Extract Artifacts') {
      steps {
        script {
          echo 'Extracting build artifacts...'
          sh '''
            mkdir -p ${ARTIFACTS_DIR}
            # If Kaniko exported as tar, extract JARs from the tar file
            if [ -f "${ARTIFACTS_DIR}/image.tar" ]; then
              echo "Extracting artifacts from tar file..."
              cd ${ARTIFACTS_DIR}
              tar -xf image.tar || true
              # Look for JARs in the extracted layers and blob directories
              find . -type f -name "*.jar" -exec cp {} . \\; 2>/dev/null || true
              # Clean up the tar and intermediate files
              rm -f image.tar
              ls -la
            else
              echo "No tar file found; assuming image was pushed to registry."
              echo "Note: To extract artifacts from a registry image, you would need:"
              echo "  - A running container from the image, or"
              echo "  - Tools like skopeo or dive to inspect the image layers"
              echo "See README.md for more details on artifact extraction from registry images."
            fi
          '''
        }
      }
    }

    stage('Archive Artifacts') {
      steps {
        archiveArtifacts artifacts: 'artifacts/**', fingerprint: true
      }
    }

    stage('Push Image (Optional)') {
      when {
        expression { return env.PUSH_IMAGE == 'true' && env.REGISTRY?.trim() }
      }
      steps {
        script {
          // If using Kaniko, the push happens during the build stage
          echo "Note: Kaniko already pushed the image during the build stage."
          echo "Image destination: ${env.REGISTRY}/${env.IMAGE_NAME}:${env.IMAGE_TAG}"
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

