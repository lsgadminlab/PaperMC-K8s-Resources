pipeline {
    agent any

    environment {
        REGISTRY      = 'docker.lsgserver.dev'
        IMAGE_NAME    = 'papermc'
        PAPER_VERSION = '1.21.4'
        IMAGE_BASE    = "${REGISTRY}/${IMAGE_NAME}"
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'ver/1.21.4',
                    url: 'https://github.com/lsgadminlab/PaperMC-K8s-Resources.git'
            }
        }

        stage('Build') {
            steps {
                script {
                    def dateStamp = new Date().format('yyyyMMdd')
                    env.TAG_FULL = "${PAPER_VERSION}-${dateStamp}-${BUILD_NUMBER}"
                }
                sh """
                    docker build \\
                        --build-arg PAPER_VERSION=${PAPER_VERSION} \\
                        -t ${IMAGE_BASE}:${TAG_FULL} \\
                        -t ${IMAGE_BASE}:${PAPER_VERSION} \\
                        -t ${IMAGE_BASE}:latest \\
                        .
                """
            }
        }

        stage('Push') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'registry-auth',
                    usernameVariable: 'REG_USER',
                    passwordVariable: 'REG_PASS'
                )]) {
                    sh """
                        echo "\${REG_PASS}" | docker login ${REGISTRY} -u "\${REG_USER}" --password-stdin
                        docker push ${IMAGE_BASE}:${TAG_FULL}
                        docker push ${IMAGE_BASE}:${PAPER_VERSION}
                        docker push ${IMAGE_BASE}:latest
                    """
                }
            }
        }
    }

    post {
        always {
            sh """
                docker rmi ${IMAGE_BASE}:${TAG_FULL}      || true
                docker rmi ${IMAGE_BASE}:${PAPER_VERSION} || true
                docker rmi ${IMAGE_BASE}:latest           || true
                docker logout ${REGISTRY}                 || true
            """
            cleanWs()
        }
    }
}
