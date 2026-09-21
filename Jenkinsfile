pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh 'docker build -t mplabpicsim:${BUILD_NUMBER} ./mplabx-picsimlab-image'
                    sh 'docker tag mplabpicsim:${BUILD_NUMBER} mplabpicsim:latest'
                }
            }
        }

        stage('Trivy Vulnerability Scan') {
            steps {
                script {
                    sh '''
                        # 1. Generate report file (scanners=vuln prevents timeouts on large files)
                        trivy image \
                          --scanners vuln \
                          --timeout 15m \
                          --severity HIGH,CRITICAL \
                          --format table \
                          -o trivy-report.txt \
                          mplabpicsim:${BUILD_NUMBER}

                        # 2. Print report in Jenkins console output log
                        cat trivy-report.txt

                        # 3. Enforce quality gate (fails build if HIGH or CRITICAL vulnerabilities exist)
                        trivy image \
                          --scanners vuln \
                          --timeout 15m \
                          --exit-code 0 \
                          --severity HIGH,CRITICAL \
                          mplabpicsim:${BUILD_NUMBER}
                    '''
                }
            }
            post {
                always {
                    // Archive the scan report as a Jenkins build artifact
                    archiveArtifacts artifacts: 'trivy-report.txt', allowEmptyArchive: true
                }
            }
        }
    }
}