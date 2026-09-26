pipeline {
    agent any

    environment {
        TRIVY_CACHE_DIR = "${WORKSPACE}/.trivy-cache"
    }

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
                    // Download the Trivy HTML template locally
                    sh "curl -sO https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/html.tpl"

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

                            echo "=== Generating Reports for Image: ${imageName}:${BUILD_NUMBER} ==="

                            // Ensure output directory for reports exists
                            sh "mkdir -p ${WORKSPACE}/reports/${imageName}"

                            // 1. Generate JSON Report
                            sh """
                                trivy image \\
                                  --cache-dir ${TRIVY_CACHE_DIR} \\
                                  --timeout 30m \\
                                  --format json \\
                                  --output ${WORKSPACE}/reports/${imageName}/trivy-image.json \\
                                  ${imageName}:${BUILD_NUMBER}
                            """

                            // 2. Generate HTML Report using downloaded template
                            sh """
                                trivy image \\
                                  --cache-dir ${TRIVY_CACHE_DIR} \\
                                  --timeout 30m \\
                                  --format template \\
                                  --template "@html.tpl" \\
                                  --output ${WORKSPACE}/reports/${imageName}/trivy-image.html \\
                                  ${imageName}:${BUILD_NUMBER}
                            """

                            // 3. Generate CycloneDX SBOM Report
                            sh """
                                trivy image \\
                                  --cache-dir ${TRIVY_CACHE_DIR} \\
                                  --timeout 30m \\
                                  --format cyclonedx \\
                                  --output ${WORKSPACE}/reports/${imageName}/sbom.json \\
                                  ${imageName}:${BUILD_NUMBER}
                            """

                            echo "=== Scanning Image Quality Gate: ${imageName}:${BUILD_NUMBER} ==="
                            
                            // 4. Run Console Scan with exit-code 0
                            sh """
                                trivy image \\
                                  --cache-dir ${TRIVY_CACHE_DIR} \\
                                  --scanners vuln \\
                                  --timeout 30m \\
                                  --severity HIGH,CRITICAL \\
                                  --format table \\
                                  --output ${WORKSPACE}/reports/${imageName}/trivy-report-${imageName}.txt \\
                                  --exit-code 0 \\
                                  ${imageName}:${BUILD_NUMBER}
                            """
                        }
                    }
                }
            }
            post {
                always {
                    // Print text reports to Jenkins log console
                    sh 'cat reports/*/trivy-report-*.txt || true'

                    // Archive all generated scan reports (txt, json, html, sbom) as build artifacts
                    archiveArtifacts artifacts: 'reports/**/*', allowEmptyArchive: true
                }
            }
        }
    }
}
