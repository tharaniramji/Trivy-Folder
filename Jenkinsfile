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
                    echo "=========================================="
                    echo "Scanning full repository filesystem & configs..."
                    echo "=========================================="
                    // Scans all folders (e.g., config, scripts, dockerfiles) for secrets & misconfigurations
                    sh '''
                        trivy fs \
                          --severity HIGH,CRITICAL \
                          --exit-code 1 \
                          --format table \
                          .
                    '''
                }
            }
        }

        stage('Trivy Vulnerability Scan') {
            steps {
                script {
                    // Find all Dockerfiles in any tool subfolder
                    def dockerfilePaths = findFiles(glob: '**/Dockerfile')

                    if (dockerfilePaths.length == 0) {
                        echo "No Dockerfiles found in repository subfolders."
                    }

                    dockerfilePaths.each { file ->
                        // Extract parent folder path (e.g., mplabx-picsimlab-image or ros2-gazebo)
                        def folderPath = file.path.replace('/Dockerfile', '').replace('Dockerfile', '.')
                        def imageName = folderPath == '.' ? 'root-image' : folderPath.toLowerCase().replaceAll(/[^a-z0-9_-]/, '-')

                        echo "=========================================="
                        echo "Processing tool folder: ${folderPath}"
                        echo "Building & scanning image: ${imageName}:test"
                        echo "=========================================="

                        // 1. Build the Docker Image
                        sh "docker build -t ${imageName}:test ${folderPath}"

                        // 2. Run Trivy Image Scan (Fails pipeline on HIGH/CRITICAL)
                        sh """
                            trivy image \
                              --severity HIGH,CRITICAL \
                              --exit-code 1 \
                              --format table \
                              ${imageName}:test
                        """
                    }
                }
            }
        }
    }
}
