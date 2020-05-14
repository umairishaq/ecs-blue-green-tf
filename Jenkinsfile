pipeline {
    agent none
    stages {
        stage('Build') {
            agent any
            steps {
                sh 'echo $GIT_COMMIT'
                sh 'echo "============================================="'
                sh 'make'
            }
        }
    }
}