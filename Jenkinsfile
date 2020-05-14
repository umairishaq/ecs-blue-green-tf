pipeline {
    agent none
    stages {
        stage('Build') {
            agent none
            steps {
                sh 'echo $GIT_COMMIT'
                sh 'echo "============================================="'
                sh 'make'
            }
        }
    }
}