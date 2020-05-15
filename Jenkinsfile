pipeline {
    agent none
    stages {
        stage('Build') {
            agent any
            steps {
                sh 'whoami'
                sh 'echo "============================================="'
                sh 'printenv'
                sh 'make'
            }
        }
        stage('EcrLogin') {
            agent any
            environment { 
                AWS_PROFILE = credentials('AWS_CREDENTIALS_PROFILE') 
            }
            steps {
                script {
                    readProperties(file: 'Makefile.env').each { key, value -> env[key] = (value.replace("AWS_ACCOUNT_NUMBER", env.AWS_ACCOUNT_NUMBER)).replace("REGION", env.REGION) }
                }

                sh 'echo "============================================="'
                sh 'printenv'
                sh '$(aws ecr get-login --no-include-email --registry-ids $AWS_ACCOUNT_NUMBER)'
            }
        }
    }
}