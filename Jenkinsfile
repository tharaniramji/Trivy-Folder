pipeline {
    agent any

    triggers {
        // Automatically triggers build when changes are pushed via GitHub Webhook
        pollSCM('')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Find & Build All Images') {
            steps {
                script {
                    // Find all directories that contain a Dockerfile
                    def dockerDirs = sh(
                        script: 'find . -mindepth 2 -maxdepth 2 -name Dockerfile -exec dirname {} \\; | sed "s|^\\./||"',
                        returnStdout: true
                    ).trim().split('\n').findAll { it }

                    if (dockerDirs.size() == 0) {
                        echo "No subdirectories with Dockerfiles found!"
                        return
                    }

                    for (dir in dockerDirs) {
                        // Generate a clean image name from directory name
                        def imageName = dir.toLowerCase().replaceAll("[^a-z0-9_-]", "")

                        stage("Process: ${dir}") {
                            echo "=== Building Image: ${imageName} from ./${dir} ==="
                            
                            // Build and Tag Docker Image
                            sh "docker build -t ${imageName}:${BUILD_NUMBER} ./${dir}"
                            sh "docker tag ${imageName}:${BUILD_NUMBER} ${imageName}:latest"

                            echo "=== Scanning Image: ${imageName}:${BUILD_NUMBER} ==="
                            
                            // Run Trivy Scan with Quality Gate (--exit-code 1)
                            sh """
                                trivy image \\
                                  --scanners vuln \\
                                  --timeout 15m \\
                                  --severity HIGH,CRITICAL \\
                                  --format table \\
                                  --output trivy-report-${imageName}.txt \\
                                  --exit-code 1 \\
                                  ${imageName}:${BUILD_NUMBER}
                            """
                        }
                    }
                }
            }
            post {
                always {
                    // Print all reports to Jenkins log console
                    sh 'cat trivy-report-*.txt || true'

                    // Archive all generated scan reports as build artifacts
                    archiveArtifacts artifacts: 'trivy-report-*.txt', allowEmptyArchive: true
                }
            }
        }
    }
}
